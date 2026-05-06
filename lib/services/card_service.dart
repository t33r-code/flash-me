import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

class CardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // --- Write operations -------------------------------------------------------

  // Create a new card and return it with its Firestore-assigned ID.
  Future<FlashCard> createCard(FlashCard card) async {
    try {
      final docRef = _firestore.collection(AppConstants.cardsCollection).doc();
      final now = DateTime.now();
      final newCard = card.copyWith(
        id: docRef.id,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(newCard.toFirestore());
      _logger.i('Created card ${docRef.id}');
      return newCard;
    } catch (e) {
      _logger.e('Failed to create card: $e');
      throw AppException('Failed to create card', code: 'create-card-failed');
    }
  }

  // Overwrite all mutable fields on an existing card document.
  Future<void> updateCard(FlashCard card) async {
    try {
      final updated = card.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(AppConstants.cardsCollection)
          .doc(card.id)
          .update(updated.toFirestore());
      _logger.i('Updated card ${card.id}');
    } catch (e) {
      _logger.e('Failed to update card ${card.id}: $e');
      throw AppException('Failed to update card', code: 'update-card-failed');
    }
  }

  // Hard-delete a card and clean up all setCards links.
  //
  // Steps: (1) find all setCards links for this card, (2) batch-delete the
  // links and decrement cardCount on each parent set, (3) delete the card.
  // Note: Firestore batches allow up to 500 operations. A card in more than
  // ~249 sets would exceed this limit — an acceptable constraint for MVP.
  Future<void> deleteCard(String cardId) async {
    try {
      // Find every set this card belongs to.
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('cardId', isEqualTo: cardId)
          .get();

      final batch = _firestore.batch();

      for (final link in links.docs) {
        final setId = link.data()['setId'] as String;
        // Remove the join document.
        batch.delete(link.reference);
        // Decrement the denormalized cardCount on the parent set.
        batch.update(
          _firestore.collection(AppConstants.setsCollection).doc(setId),
          {'cardCount': FieldValue.increment(-1)},
        );
      }

      // Delete the card document itself.
      batch.delete(
          _firestore.collection(AppConstants.cardsCollection).doc(cardId));

      await batch.commit();
      _logger.i('Deleted card $cardId (removed ${links.docs.length} set links)');
    } catch (e) {
      _logger.e('Failed to delete card $cardId: $e');
      throw AppException('Failed to delete card', code: 'delete-card-failed');
    }
  }

  // --- Read operations --------------------------------------------------------

  // Fetch a single card by ID; returns null if not found.
  Future<FlashCard?> getCard(String cardId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.cardsCollection)
          .doc(cardId)
          .get();
      return doc.exists ? FlashCard.fromFirestore(doc) : null;
    } catch (e) {
      _logger.e('Failed to get card $cardId: $e');
      throw AppException('Failed to load card', code: 'get-card-failed');
    }
  }

  // Stream all cards owned by [userId], ordered newest first.
  Stream<List<FlashCard>> watchUserCards(String userId) {
    return _firestore
        .collection(AppConstants.cardsCollection)
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(FlashCard.fromFirestore).toList());
  }

  // Fetch a batch of cards by their IDs.
  // Firestore's whereIn clause is limited to 30 items, so this batches requests.
  Future<List<FlashCard>> getCardsByIds(List<String> cardIds) async {
    if (cardIds.isEmpty) return [];
    try {
      final cards = <FlashCard>[];
      for (var i = 0; i < cardIds.length; i += 30) {
        final chunk = cardIds.sublist(i, min(i + 30, cardIds.length));
        final snapshot = await _firestore
            .collection(AppConstants.cardsCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        cards.addAll(snapshot.docs.map(FlashCard.fromFirestore));
      }
      return cards;
    } catch (e) {
      _logger.e('Failed to fetch cards by IDs: $e');
      throw AppException('Failed to load cards', code: 'get-cards-failed');
    }
  }
}
