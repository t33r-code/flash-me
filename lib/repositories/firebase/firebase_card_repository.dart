import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/repositories/card_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

// Firestore implementation of CardRepository.
class FirebaseCardRepository implements CardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  @override
  Future<FlashCard> createCard(FlashCard card) async {
    try {
      final docRef = _firestore.collection(AppConstants.cardsCollection).doc();
      final now = DateTime.now();
      final newCard = card.copyWith(id: docRef.id, createdAt: now, updatedAt: now);
      await docRef.set(newCard.toFirestore());
      _logger.i('Created card ${docRef.id}');
      return newCard;
    } catch (e) {
      _logger.e('Failed to create card: $e');
      throw AppException('Failed to create card', code: 'create-card-failed');
    }
  }

  @override
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

  @override
  Stream<List<FlashCard>> watchUserCards(String userId) {
    return _firestore
        .collection(AppConstants.cardsCollection)
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FlashCard.fromFirestore).toList());
  }

  // Fetch cards by ID list; batches into groups of 30 (Firestore whereIn limit).
  @override
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

  @override
  Future<void> updateCard(FlashCard card) async {
    try {
      final updated = card.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(AppConstants.cardsCollection)
          .doc(card.id)
          .update(updated.toFirestore());
    } catch (e) {
      _logger.e('Failed to update card ${card.id}: $e');
      throw AppException('Failed to update card', code: 'update-card-failed');
    }
  }

  // Hard-delete: removes the card + all setCards links + decrements cardCounts.
  @override
  Future<void> deleteCard(String cardId) async {
    try {
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('cardId', isEqualTo: cardId)
          .get();

      final batch = _firestore.batch();
      for (final link in links.docs) {
        final setId = link.data()['setId'] as String;
        batch.delete(link.reference);
        batch.update(
          _firestore.collection(AppConstants.setsCollection).doc(setId),
          {'cardCount': FieldValue.increment(-1)},
        );
      }
      batch.delete(
          _firestore.collection(AppConstants.cardsCollection).doc(cardId));
      await batch.commit();
      _logger.i('Deleted card $cardId (${links.docs.length} set links removed)');
    } catch (e) {
      _logger.e('Failed to delete card $cardId: $e');
      throw AppException('Failed to delete card', code: 'delete-card-failed');
    }
  }
}
