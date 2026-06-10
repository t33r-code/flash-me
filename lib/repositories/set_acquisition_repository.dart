import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/set_update_diff.dart';

// Provider-agnostic contract for set acquisition (clone, update, future: subscribe).
abstract class SetAcquisitionRepository {
  // Clone a public set into the cloner's library.
  // Creates a new CardSet owned by [clonerId] and copies all cards.
  // Each copied card gets a cardAcquisitions provenance record for future dedup.
  // Returns the newly created CardSet.
  Future<CardSet> cloneSet({
    required String originalSetId,
    required String clonerId,
  });

  // Compare the current contents of [originalSetId] against what [clonerId]
  // previously cloned, and return a description of what has changed.
  //   • newCards    — source cards not yet in the cloner's library
  //   • updatedCards — source cards whose updatedAt is newer than the cloner's copy
  // Cards removed from the source are intentionally ignored (clone is independent).
  Future<SetUpdateDiff> checkForUpdates({
    required String originalSetId,
    required String clonerId,
  });

  // Apply a previously computed [diff] to the cloner's existing set.
  //   • New cards are copied and added to [acquiredSetId].
  //   • Updated cards have their cloner copies overwritten with the source data.
  // No new set is created; cardCount on [acquiredSetId] is updated.
  Future<void> applySetUpdate({
    required String originalSetId,
    required String acquiredSetId,
    required String clonerId,
    required SetUpdateDiff diff,
  });
}
