import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/repositories/workbook_card_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

// Firestore implementation of WorkbookCardRepository.
class FirebaseWorkbookCardRepository implements WorkbookCardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  @override
  Future<WorkbookCard> createCard(WorkbookCard card) async {
    try {
      final docRef =
          _firestore.collection(AppConstants.workbookCardsCollection).doc();
      final now = DateTime.now();
      final newCard = card.copyWith(
        id: docRef.id,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(newCard.toFirestore());
      _logger.i('Created workbook card ${docRef.id}');
      return newCard;
    } catch (e) {
      _logger.e('Failed to create workbook card: $e');
      throw AppException('Failed to create card', code: 'create-card-failed');
    }
  }

  @override
  Future<WorkbookCard?> getCard(String cardId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.workbookCardsCollection)
          .doc(cardId)
          .get();
      return doc.exists ? WorkbookCard.fromFirestore(doc) : null;
    } catch (e) {
      _logger.e('Failed to get workbook card $cardId: $e');
      throw AppException('Failed to load card', code: 'get-card-failed');
    }
  }

  @override
  Stream<List<WorkbookCard>> watchUserCards(String userId) {
    return _firestore
        .collection(AppConstants.workbookCardsCollection)
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(WorkbookCard.fromFirestore).toList());
  }

  // Fetch cards by ID; uses individual doc reads rather than whereIn to avoid
  // Firestore's inability to evaluate list-query rules when __name__ whereIn
  // is combined with a field filter.
  @override
  Future<List<WorkbookCard>> getCardsByIds(
      List<String> cardIds, String userId) async {
    if (cardIds.isEmpty) return [];
    try {
      final col = _firestore.collection(AppConstants.workbookCardsCollection);
      final snaps = await Future.wait(cardIds.map((id) => col.doc(id).get()));
      return snaps
          .where((s) => s.exists && s.data()?['createdBy'] == userId)
          .map(WorkbookCard.fromFirestore)
          .toList();
    } catch (e) {
      _logger.e('Failed to fetch workbook cards by IDs: $e');
      throw AppException('Failed to load cards', code: 'get-cards-failed');
    }
  }

  @override
  Future<void> updateCard(WorkbookCard card) async {
    try {
      final updated = card.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(AppConstants.workbookCardsCollection)
          .doc(card.id)
          .update(updated.toFirestore());
    } catch (e) {
      _logger.e('Failed to update workbook card ${card.id}: $e');
      throw AppException('Failed to update card', code: 'update-card-failed');
    }
  }

  // Deletes the card document and all setCards links that reference it.
  @override
  Future<void> deleteCard(String cardId) async {
    try {
      // Find all set-membership links for this card.
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('cardId', isEqualTo: cardId)
          .where('cardType', isEqualTo: AppConstants.cardTypeWorkbook)
          .get();

      final batch = _firestore.batch();
      for (final link in links.docs) {
        // Decrement the set's cardCount for each removed link.
        batch.update(
          _firestore
              .collection(AppConstants.setsCollection)
              .doc(link.data()['setId'] as String),
          {'cardCount': FieldValue.increment(-1)},
        );
        batch.delete(link.reference);
      }
      batch.delete(_firestore
          .collection(AppConstants.workbookCardsCollection)
          .doc(cardId));
      await batch.commit();
      _logger.i(
          'Deleted workbook card $cardId (${links.docs.length} set links removed)');
    } catch (e) {
      _logger.e('Failed to delete workbook card $cardId: $e');
      throw AppException('Failed to delete card', code: 'delete-card-failed');
    }
  }
}
