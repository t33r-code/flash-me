import 'package:flash_me/models/flash_card.dart';

// Provider-agnostic contract for flash card persistence.
abstract class CardRepository {
  // Create a new card; returns the saved card with its generated ID.
  Future<FlashCard> createCard(FlashCard card);

  // Fetch a single card; returns null if not found.
  Future<FlashCard?> getCard(String cardId);

  // Stream all cards owned by [userId], ordered newest first.
  Stream<List<FlashCard>> watchUserCards(String userId);

  // Fetch multiple cards by ID in a single (possibly batched) operation.
  Future<List<FlashCard>> getCardsByIds(List<String> cardIds);

  // Overwrite all mutable fields on an existing card.
  Future<void> updateCard(FlashCard card);

  // Hard-delete a card and clean up all set-membership links.
  Future<void> deleteCard(String cardId);
}
