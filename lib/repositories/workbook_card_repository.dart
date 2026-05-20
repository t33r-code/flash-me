import 'package:flash_me/models/workbook_card.dart';

// Provider-agnostic contract for workbook card persistence.
// Mirrors CardRepository but omits findCardByWordAndTranslation,
// which is specific to the flash card import flow.
abstract class WorkbookCardRepository {
  // Create a new card; returns the saved card with its generated ID.
  Future<WorkbookCard> createCard(WorkbookCard card);

  // Fetch a single card; returns null if not found.
  Future<WorkbookCard?> getCard(String cardId);

  // Stream all workbook cards owned by [userId], ordered newest first.
  Stream<List<WorkbookCard>> watchUserCards(String userId);

  // Fetch multiple cards by ID in one batched operation.
  // userId is required so the query includes a createdBy constraint that
  // Firestore can evaluate at query time (plain __name__-whereIn is denied).
  Future<List<WorkbookCard>> getCardsByIds(List<String> cardIds, String userId);

  // Overwrite all mutable fields on an existing card.
  Future<void> updateCard(WorkbookCard card);

  // Hard-delete a card and remove all set-membership links for it.
  Future<void> deleteCard(String cardId);
}
