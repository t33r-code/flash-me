import 'package:flash_me/models/card_mark.dart';

// Provider-agnostic contract for persisting per-user, per-card Skip/Review marks.
abstract class CardMarkRepository {
  // Upserts a mark for a card.  Preserves the original markedAt timestamp if
  // the card was already marked (so first-mark date is always meaningful).
  Future<void> setMark(String userId, String cardId, String mark);

  // Deletes the mark for a card — called when the user taps the active button
  // a second time to clear it.
  Future<void> removeMark(String userId, String cardId);

  // Streams all marks for a user; used by future filtered study modes.
  Stream<List<CardMark>> watchMarks(String userId);
}
