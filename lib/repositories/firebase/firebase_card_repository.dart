import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/repositories/card_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

// Firestore implementation of CardRepository.
class FirebaseCardRepository implements CardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
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

  // Hard-delete: cleans up Storage media, removes all setCards links,
  // decrements cardCounts, then deletes the Firestore card document.
  @override
  Future<void> deleteCard(String cardId) async {
    try {
      // Fetch the card first so we can find any media files to clean up.
      final doc = await _firestore
          .collection(AppConstants.cardsCollection)
          .doc(cardId)
          .get();

      // If the card is already gone there is nothing to clean up.
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final createdBy = data['createdBy'] as String? ?? '';
      await _deleteStorageFileIfPresent(data['primaryImageUrl'] as String?);
      await _deleteStorageFileIfPresent(data['primaryAudioUrl'] as String?);

      // Firestore's list rule on setCards requires a userId constraint —
      // queries without it are rejected even when they would return 0 results.
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('cardId', isEqualTo: cardId)
          .where('userId', isEqualTo: createdBy)
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

  @override
  Future<FlashCard?> findCardByWordAndTranslation(
    String primaryWord,
    String translation,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.cardsCollection)
          .where('createdBy', isEqualTo: userId)
          .where('primaryWord', isEqualTo: primaryWord)
          .where('translation', isEqualTo: translation)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return FlashCard.fromFirestore(snapshot.docs.first);
    } catch (e) {
      _logger.e('Failed to find card by word/translation: $e');
      throw AppException('Failed to search card library',
          code: 'find-card-failed');
    }
  }

  // Delete a Firebase Storage file by its download URL.
  // Uses refFromURL so we don't need to store the path separately.
  // Errors are swallowed — a missing file should not block card deletion.
  Future<void> _deleteStorageFileIfPresent(String? url) async {
    if (url == null) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      _logger.w('Could not delete storage file $url: $e');
    }
  }
}
