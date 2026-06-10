// Describes what has changed in a market set since the user last cloned it.
// Produced by SetAcquisitionRepository.checkForUpdates() and consumed by
// both the UI (to show counts) and applySetUpdate() (to act on each entry).
class SetUpdateDiff {
  // Source cards not yet present in the cloner's library.
  final List<({String sourceCardId, String cardType})> newCards;

  // Source cards that have been updated since the cloner's copy was last synced.
  // acquiredCardId is the document to overwrite in the cloner's library.
  final List<({String sourceCardId, String acquiredCardId, String cardType})>
      updatedCards;

  const SetUpdateDiff({required this.newCards, required this.updatedCards});

  bool get hasChanges => newCards.isNotEmpty || updatedCards.isNotEmpty;
}
