import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';

// ---------------------------------------------------------------------------
// ExportService — builds a ZIP archive for a card set and delivers it:
//
//   Mobile (Android/iOS) → system share sheet (share_plus)
//   Desktop (Win/Mac/Linux) → saved to the Downloads folder; returns save path
//   Web → not yet supported (throws UnsupportedError)
//
// Returns the file path where the ZIP was saved (desktop), or null (mobile
// after the share sheet is opened).  The caller can display this to the user.
// ---------------------------------------------------------------------------
class ExportService {
  Future<String?> exportSet(CardSet cardSet, List<FlashCard> cards) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Export is not supported in the browser. '
          'Use the mobile or desktop app.');
    }

    final archive = Archive();
    final mediaBytes = <String, Uint8List>{}; // relative filename → bytes

    // ── 1. Download media and remap URLs to relative paths ─────────────
    final exportCards = <Map<String, dynamic>>[];
    for (final card in cards) {
      String? imagePath;
      String? audioPath;

      if (card.primaryImageUrl != null) {
        final filename =
            _mediaFilename(card.id, 'image', card.primaryImageUrl!);
        if (!mediaBytes.containsKey(filename)) {
          final bytes = await _downloadBytes(card.primaryImageUrl!);
          if (bytes != null) mediaBytes[filename] = bytes;
        }
        if (mediaBytes.containsKey(filename)) imagePath = 'media/$filename';
      }

      if (card.primaryAudioUrl != null) {
        final filename =
            _mediaFilename(card.id, 'audio', card.primaryAudioUrl!);
        if (!mediaBytes.containsKey(filename)) {
          final bytes = await _downloadBytes(card.primaryAudioUrl!);
          if (bytes != null) mediaBytes[filename] = bytes;
        }
        if (mediaBytes.containsKey(filename)) audioPath = 'media/$filename';
      }

      exportCards.add(_cardToExportMap(card, imagePath, audioPath));
    }

    // ── 2. Build cards.json ─────────────────────────────────────────────
    final jsonMap = {
      'version': '1.0',
      'exportDate': DateTime.now().toUtc().toIso8601String(),
      'set': {
        'name': cardSet.name,
        if (cardSet.description != null) 'description': cardSet.description,
        'tags': cardSet.tags,
        if (cardSet.color != null) 'color': cardSet.color,
        'cards': exportCards,
      },
    };
    final jsonBytes = utf8.encode(jsonEncode(jsonMap));
    archive.addFile(ArchiveFile('cards.json', jsonBytes.length, jsonBytes));

    // ── 3. Add media files ──────────────────────────────────────────────
    for (final entry in mediaBytes.entries) {
      archive.addFile(ArchiveFile(
          'media/${entry.key}', entry.value.length, entry.value));
    }

    // ── 4. Encode ZIP ───────────────────────────────────────────────────
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw Exception('Failed to encode ZIP archive.');

    final safeName = _safeName(cardSet.name);
    final fileName = '$safeName-export.zip';

    // ── 5. Deliver to the user ──────────────────────────────────────────
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: write to temp dir, then open the system share sheet.
      final dir = await getTemporaryDirectory();
      final zipFile = File('${dir.path}/$fileName');
      await zipFile.writeAsBytes(zipBytes);
      await Share.shareXFiles(
        [XFile(zipFile.path)],
        subject: 'Flash Me: ${cardSet.name}',
      );
      return null; // delivery handled by the share sheet
    } else {
      // Desktop: save directly to the Downloads folder.
      final downloadsDir =
          await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final zipFile = File('${downloadsDir.path}/$fileName');
      await zipFile.writeAsBytes(zipBytes);
      return zipFile.path; // caller shows a confirmation with the path
    }
  }

  // Build a clean export map — strips internal IDs and user-scoped fields.
  // The importer will assign fresh IDs and set createdBy to the importer's uid.
  Map<String, dynamic> _cardToExportMap(
    FlashCard card,
    String? imagePath,
    String? audioPath,
  ) =>
      {
        'primaryWord': card.primaryWord,
        'translation': card.translation,
        'primaryImageUrl': imagePath,
        'primaryAudioUrl': audioPath,
        'primaryWordHidden': card.primaryWordHidden,
        'fields': card.fields.map((f) => f.toJson()).toList(),
        'templateId': card.templateId,
        'tags': card.tags,
      };

  // Builds a unique filename for a media asset: {cardId}_{role}{.ext}
  // The extension is parsed from the Firebase Storage URL path.
  String _mediaFilename(String cardId, String role, String url) {
    String ext = '';
    try {
      final uri = Uri.parse(url);
      // Firebase Storage URLs encode the object path as the last path segment
      // with internal slashes as %2F.
      final decoded = Uri.decodeComponent(uri.pathSegments.last);
      final slash = decoded.lastIndexOf('/');
      final basename = slash >= 0 ? decoded.substring(slash + 1) : decoded;
      final dot = basename.lastIndexOf('.');
      if (dot >= 0) ext = basename.substring(dot); // e.g. ".jpg"
    } catch (_) {}
    return '${cardId}_$role$ext';
  }

  // Downloads bytes from a Firebase Storage HTTPS URL using the Storage SDK
  // (respects the signed-in user's auth context).
  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      return await FirebaseStorage.instance.refFromURL(url).getData();
    } catch (_) {
      return null;
    }
  }

  // Strips characters that are invalid in filenames and collapses whitespace.
  String _safeName(String name) => name
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
}
