import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';

// Provider-agnostic contract for card-set persistence and card membership.
abstract class CardSetRepository {
  // --- Set CRUD --------------------------------------------------------------

  Future<CardSet> createSet(CardSet cardSet);
  Future<CardSet?> getSet(String setId);
  Stream<List<CardSet>> watchUserSets(String userId);
  Future<void> updateSet(CardSet cardSet);

  // Hard-delete a set and all its membership links.
  // userId is required so the setCards query satisfies Firestore list rules.
  Future<void> deleteSet(String setId, String userId);

  // --- Card membership -------------------------------------------------------

  // Add one card to a set; increments the set's cardCount.
  Future<void> addCardToSet({
    required String setId,
    required String cardId,
    required String userId,
  });

  // Remove one card from a set; decrements the set's cardCount.
  // userId is required so the setCards query satisfies Firestore list rules.
  Future<void> removeCardFromSet({
    required String setId,
    required String cardId,
    required String userId,
  });

  // Bulk-add multiple cards; batched internally to stay within write limits.
  Future<void> addCardsToSet({
    required String setId,
    required List<String> cardIds,
    required String userId,
  });

  // Stream the ordered card IDs in a set (lightweight — no card data).
  // userId is required so the setCards query satisfies Firestore list rules.
  Stream<List<String>> watchCardIdsInSet(String setId, String userId);

  // Stream the full FlashCard objects for all cards in a set.
  // userId is required so the setCards query satisfies Firestore list rules.
  Stream<List<FlashCard>> watchCardsInSet(String setId, String userId);

  // Find a set owned by [userId] whose name exactly matches [name].
  // Returns null if no such set exists.
  Future<CardSet?> findSetByName(String name, String userId);
}
