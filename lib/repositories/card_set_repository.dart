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
  Future<void> deleteSet(String setId);

  // --- Card membership -------------------------------------------------------

  // Add one card to a set; increments the set's cardCount.
  Future<void> addCardToSet({
    required String setId,
    required String cardId,
    required String userId,
  });

  // Remove one card from a set; decrements the set's cardCount.
  Future<void> removeCardFromSet({
    required String setId,
    required String cardId,
  });

  // Bulk-add multiple cards; batched internally to stay within write limits.
  Future<void> addCardsToSet({
    required String setId,
    required List<String> cardIds,
    required String userId,
  });

  // Stream the ordered card IDs in a set (lightweight — no card data).
  Stream<List<String>> watchCardIdsInSet(String setId);

  // Stream the full FlashCard objects for all cards in a set.
  Stream<List<FlashCard>> watchCardsInSet(String setId);
}
