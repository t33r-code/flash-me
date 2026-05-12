import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flash_me/models/card_field.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/import_diff.dart';
import 'package:flash_me/repositories/card_repository.dart';
import 'package:flash_me/repositories/card_set_repository.dart';
import 'package:flash_me/utils/exceptions.dart';

// ---------------------------------------------------------------------------
// ImportService — parses a ZIP archive, diffs it against Firestore, and
// executes the user-approved import.
// ---------------------------------------------------------------------------
class ImportService {
  // ── Public API ─────────────────────────────────────────────────────────────

  // Parse [zipBytes], validate, and diff each set against the user's existing
  // Firestore data. Returns an ImportAnalysis ready to show in the preview
  // dialog. Throws [AppException] on unrecoverable parse/validation errors.
  Future<ImportAnalysis> analyze({
    required Uint8List zipBytes,
    required String userId,
    required CardSetRepository cardSetRepo,
    required CardRepository cardRepo,
  }) async {
    // 1. Decode ZIP.
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw AppException('Not a valid ZIP file.');
    }
    if (archive.length > 50 * 1024 * 1024) {
      throw AppException('Archive exceeds the 50 MB limit.');
    }

    // 2. Locate and parse cards.json.
    final jsonFile = archive.findFile('cards.json');
    if (jsonFile == null) throw AppException('cards.json not found in archive.');
    final jsonStr = utf8.decode(jsonFile.content as List<int>);
    final Map<String, dynamic> root;
    try {
      root = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      throw AppException('cards.json is not valid JSON.');
    }

    // 3. Normalise to a list of raw set maps (supports both formats).
    final List<Map<String, dynamic>> rawSets;
    if (root.containsKey('sets')) {
      rawSets = (root['sets'] as List)
          .cast<Map<String, dynamic>>();
    } else if (root.containsKey('set')) {
      rawSets = [root['set'] as Map<String, dynamic>];
    } else {
      throw AppException(
          'Invalid format: expected a "set" or "sets" key in cards.json.');
    }

    // 4. Parse, validate, and diff each set.
    final diffs = <ImportSetDiff>[];
    for (final rawSet in rawSets) {
      final diff = await _diffSet(
        rawSet: rawSet,
        userId: userId,
        cardSetRepo: cardSetRepo,
      );
      diffs.add(diff);
    }

    return ImportAnalysis(setDiffs: diffs, archive: archive);
  }

  // Execute the import based on the user's choices.
  // [analysis] must be the value returned by the most recent analyze() call.
  Future<void> execute({
    required ImportAnalysis analysis,
    required bool deleteNotInImport,
    required bool skipUpdates,
    required String userId,
    required CardSetRepository cardSetRepo,
    required CardRepository cardRepo,
  }) async {
    for (final diff in analysis.setDiffs) {
      // Resolve (or create) the set.
      final targetSet = diff.existingSet ??
          await cardSetRepo.createSet(CardSet(
            id: '',
            userId: userId,
            name: diff.setName,
            cardCount: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));

      // Create new cards.
      for (final entry in diff.newCards) {
        final imageUrl = await _uploadMedia(
            analysis.archive, entry.data.mediaImagePath, userId);
        final audioUrl = await _uploadMedia(
            analysis.archive, entry.data.mediaAudioPath, userId);
        final card = await cardRepo.createCard(FlashCard(
          id: '',
          primaryWord: entry.data.primaryWord,
          translation: entry.data.translation,
          primaryWordHidden: entry.data.primaryWordHidden,
          primaryImageUrl: imageUrl,
          primaryAudioUrl: audioUrl,
          fields: _buildFields(entry.data.rawFields),
          templateId: entry.data.templateId,
          tags: entry.data.tags,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        ));
        await cardSetRepo.addCardToSet(
          setId: targetSet.id,
          cardId: card.id,
          userId: userId,
        );
      }

      // Update existing cards (unless the user opted to skip updates).
      if (!skipUpdates) {
        for (final entry in diff.updatedCards) {
          final imageUrl = entry.incoming.mediaImagePath != null
              ? await _uploadMedia(
                  analysis.archive, entry.incoming.mediaImagePath, userId)
              : entry.existing.primaryImageUrl;
          final audioUrl = entry.incoming.mediaAudioPath != null
              ? await _uploadMedia(
                  analysis.archive, entry.incoming.mediaAudioPath, userId)
              : entry.existing.primaryAudioUrl;
          await cardRepo.updateCard(entry.existing.copyWith(
            translation: entry.incoming.translation,
            primaryWordHidden: entry.incoming.primaryWordHidden,
            primaryImageUrl: imageUrl,
            primaryAudioUrl: audioUrl,
            fields: _buildFields(entry.incoming.rawFields),
            templateId: entry.incoming.templateId,
            tags: entry.incoming.tags,
            updatedAt: DateTime.now(),
          ));
        }
      }

      // Remove set-membership links for cards not in the import file.
      // The cards themselves are NOT deleted — they remain in the user's
      // card library and any other sets they belong to.
      if (deleteNotInImport) {
        for (final card in diff.deletableCards) {
          await cardSetRepo.removeCardFromSet(
            setId: targetSet.id,
            cardId: card.id,
            userId: userId,
          );
        }
      }
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<ImportSetDiff> _diffSet({
    required Map<String, dynamic> rawSet,
    required String userId,
    required CardSetRepository cardSetRepo,
  }) async {
    final setName = rawSet['name'] as String? ?? '';
    if (setName.isEmpty) throw AppException('A set in the import has no name.');

    final rawCards = (rawSet['cards'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final importCards = rawCards.map(_parseCard).toList();

    // Look up existing set and its current cards.
    final existingSet = await cardSetRepo.findSetByName(setName, userId);
    final existingCards = existingSet != null
        ? await cardSetRepo
            .watchCardsInSet(existingSet.id, userId)
            .first
        : <FlashCard>[];

    final existingByWord = {for (final c in existingCards) c.primaryWord: c};
    final importWords = importCards.map((c) => c.primaryWord).toSet();

    final newCards = <NewCardEntry>[];
    final updatedCards = <UpdatedCardEntry>[];

    for (final imported in importCards) {
      final existing = existingByWord[imported.primaryWord];
      if (existing == null) {
        newCards.add(NewCardEntry(imported));
      } else {
        final changed = _changedFields(existing, imported);
        if (changed.isNotEmpty) {
          updatedCards.add(UpdatedCardEntry(
            existing: existing,
            incoming: imported,
            changedFields: changed,
          ));
        }
        // If no fields changed, the card is identical — silently skip.
      }
    }

    final deletableCards = existingCards
        .where((c) => !importWords.contains(c.primaryWord))
        .toList();

    return ImportSetDiff(
      setName: setName,
      existingSet: existingSet,
      newCards: newCards,
      updatedCards: updatedCards,
      deletableCards: deletableCards,
    );
  }

  ImportCardData _parseCard(Map<String, dynamic> raw) {
    final word = raw['primaryWord'] as String? ?? '';
    final translation = raw['translation'] as String? ?? '';
    if (word.isEmpty) throw AppException('A card is missing primaryWord.');
    if (translation.isEmpty) throw AppException('Card "$word" is missing translation.');

    final rawFields = (raw['fields'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    // Basic field validation.
    for (final f in rawFields) {
      if (f['name'] == null || f['type'] == null || f['content'] == null) {
        throw AppException('Card "$word" has a malformed field entry.');
      }
    }

    return ImportCardData(
      primaryWord: word,
      translation: translation,
      primaryWordHidden: raw['primaryWordHidden'] as bool? ?? false,
      mediaImagePath: raw['primaryImageUrl'] as String?,
      mediaAudioPath: raw['primaryAudioUrl'] as String?,
      rawFields: rawFields,
      templateId: raw['templateId'] as String?,
      tags: List<String>.from(raw['tags'] as List? ?? []),
    );
  }

  // Conservative diff: any difference in any field counts as an update.
  List<String> _changedFields(FlashCard existing, ImportCardData incoming) {
    final changed = <String>[];
    if (existing.translation != incoming.translation) changed.add('translation');
    if (existing.primaryWordHidden != incoming.primaryWordHidden) {
      changed.add('word visibility');
    }
    if (!_listsEqual(existing.tags, incoming.tags)) changed.add('tags');
    if (_fieldsChanged(existing.fields, incoming.rawFields)) changed.add('fields');
    // Media: compare presence only (URLs differ between accounts).
    if ((existing.primaryImageUrl != null) != (incoming.mediaImagePath != null)) {
      changed.add('image');
    }
    if ((existing.primaryAudioUrl != null) != (incoming.mediaAudioPath != null)) {
      changed.add('audio');
    }
    return changed;
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Compare fields by serialising to JSON (without fieldId — already stripped
  // by the exporter). Two fields are considered equal if their name, type, and
  // content are identical.
  bool _fieldsChanged(
    List<CardField> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    if (existing.length != incoming.length) return true;
    for (var i = 0; i < existing.length; i++) {
      final e = existing[i];
      final imp = incoming[i];
      if (e.name != imp['name'] ||
          e.type != imp['type'] ||
          jsonEncode(e.content.toJson()) != jsonEncode(imp['content'])) {
        return true;
      }
    }
    return false;
  }

  // Build CardField list from raw JSON maps, generating fresh fieldIds.
  List<CardField> _buildFields(List<Map<String, dynamic>> rawFields) =>
      rawFields.map((f) {
        final type = f['type'] as String;
        return CardField(
          fieldId: CardField.generateId(),
          name: f['name'] as String,
          type: type,
          content: CardFieldContent.fromJson(
              type, f['content'] as Map<String, dynamic>),
        );
      }).toList();

  // Upload a media file from the archive to Firebase Storage.
  // Returns the storage URL, or null if [path] is null or the file is missing.
  Future<String?> _uploadMedia(
    Archive archive,
    String? path,
    String userId,
  ) async {
    if (path == null) return null;
    final file = archive.findFile(path);
    if (file == null) return null;

    final bytes = Uint8List.fromList(file.content as List<int>);
    final ext = path.contains('.') ? path.split('.').last : '';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance
        .ref()
        .child('users/$userId/cards/$fileName');

    final contentType = _contentType(ext);
    final metadata =
        contentType != null ? SettableMetadata(contentType: contentType) : null;
    final task = metadata != null
        ? ref.putData(bytes, metadata)
        : ref.putData(bytes);
    await task;
    return await ref.getDownloadURL();
  }

  String? _contentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp3':
        return 'audio/mpeg';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      default:
        return null;
    }
  }
}
