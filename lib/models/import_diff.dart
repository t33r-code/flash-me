import 'package:archive/archive.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';

// ---------------------------------------------------------------------------
// Raw card data parsed from the import ZIP — no Firestore IDs assigned yet.
// ---------------------------------------------------------------------------
class ImportCardData {
  final String primaryWord;
  final String translation;
  final bool primaryWordHidden;
  // Relative paths inside the ZIP archive (e.g. 'media/abc_image.jpg'), or
  // null if the card has no media.
  final String? mediaImagePath;
  final String? mediaAudioPath;
  // Raw field maps without fieldId — importer generates fresh IDs on write.
  final List<Map<String, dynamic>> rawFields;
  final String? templateId;
  final List<String> tags;

  const ImportCardData({
    required this.primaryWord,
    required this.translation,
    this.primaryWordHidden = false,
    this.mediaImagePath,
    this.mediaAudioPath,
    required this.rawFields,
    this.templateId,
    this.tags = const [],
  });
}

// A card in the import file that has no matching card (by primaryWord) in
// the current set — it will be created.
class NewCardEntry {
  final ImportCardData data;
  const NewCardEntry(this.data);
}

// A card in the import file whose primaryWord matches an existing card, and
// whose content differs in at least one field.
class UpdatedCardEntry {
  final FlashCard existing;
  final ImportCardData incoming;
  // Human-readable names of the fields that differ.
  final List<String> changedFields;

  const UpdatedCardEntry({
    required this.existing,
    required this.incoming,
    required this.changedFields,
  });
}

// Per-set summary of what the import will do.
class ImportSetDiff {
  final String setName;
  final CardSet? existingSet; // null → a new set will be created
  final List<NewCardEntry> newCards;
  final List<UpdatedCardEntry> updatedCards;
  // Cards currently in the set that are NOT in the import file.
  // Only acted upon when the user enables "delete cards not in import".
  final List<FlashCard> deletableCards;

  const ImportSetDiff({
    required this.setName,
    this.existingSet,
    required this.newCards,
    required this.updatedCards,
    required this.deletableCards,
  });

  bool get isNewSet => existingSet == null;
  bool get hasChanges =>
      newCards.isNotEmpty ||
      updatedCards.isNotEmpty ||
      deletableCards.isNotEmpty;
}

// Top-level result returned by ImportService.analyze(). The archive is
// retained so executeImport() can read media bytes without re-parsing the ZIP.
class ImportAnalysis {
  final List<ImportSetDiff> setDiffs;
  final Archive archive;

  const ImportAnalysis({required this.setDiffs, required this.archive});

  int get totalNewCards =>
      setDiffs.fold(0, (s, d) => s + d.newCards.length);
  int get totalUpdatedCards =>
      setDiffs.fold(0, (s, d) => s + d.updatedCards.length);
  int get totalDeletableCards =>
      setDiffs.fold(0, (s, d) => s + d.deletableCards.length);
}
