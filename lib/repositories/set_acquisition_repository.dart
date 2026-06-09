import 'package:flash_me/models/card_set.dart';

// Provider-agnostic contract for set acquisition (clone, future: subscription).
abstract class SetAcquisitionRepository {
  // Clone a public set into the cloner's library.
  //
  // Steps performed atomically where possible:
  //   1. Read source set and its setCards join documents.
  //   2. For each flash card — link existing cloner card matched by
  //      [primaryWord, translation]; copy if no match.
  //   3. For each workbook card — always copy (no dedup key yet; see Mk-5).
  //   4. Create a new CardSet owned by [clonerId].
  //   5. Create setCards join documents for every card.
  //   6. Write a setAcquisitions record.
  //   7. Increment acquisitionCount on the original set.
  //
  // Returns the newly created CardSet.
  Future<CardSet> cloneSet({
    required String originalSetId,
    required String clonerId,
  });
}
