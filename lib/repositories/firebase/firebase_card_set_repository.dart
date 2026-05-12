import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/set_card.dart';
import 'package:flash_me/repositories/card_set_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

// Firestore implementation of CardSetRepository.
class FirebaseCardSetRepository implements CardSetRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // --- Set CRUD --------------------------------------------------------------

  @override
  Future<CardSet> createSet(CardSet cardSet) async {
    try {
      final docRef = _firestore.collection(AppConstants.setsCollection).doc();
      final now = DateTime.now();
      final newSet = cardSet.copyWith(
        id: docRef.id,
        cardCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(newSet.toFirestore());
      _logger.i('Created set ${docRef.id}');
      return newSet;
    } catch (e) {
      _logger.e('Failed to create set: $e');
      throw AppException('Failed to create set', code: 'create-set-failed');
    }
  }

  @override
  Future<CardSet?> getSet(String setId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.setsCollection)
          .doc(setId)
          .get();
      return doc.exists ? CardSet.fromFirestore(doc) : null;
    } catch (e) {
      _logger.e('Failed to get set $setId: $e');
      throw AppException('Failed to load set', code: 'get-set-failed');
    }
  }

  @override
  Stream<List<CardSet>> watchUserSets(String userId) {
    return _firestore
        .collection(AppConstants.setsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(CardSet.fromFirestore).toList());
  }

  @override
  Future<void> updateSet(CardSet cardSet) async {
    try {
      final updated = cardSet.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(AppConstants.setsCollection)
          .doc(cardSet.id)
          .update(updated.toFirestore());
    } catch (e) {
      _logger.e('Failed to update set ${cardSet.id}: $e');
      throw AppException('Failed to update set', code: 'update-set-failed');
    }
  }

  // Hard-delete: removes all setCards links then the set document.
  // userId constraint is required by the Firestore list rule on setCards.
  @override
  Future<void> deleteSet(String setId, String userId) async {
    try {
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('setId', isEqualTo: setId)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final link in links.docs) {
        batch.delete(link.reference);
      }
      batch.delete(
          _firestore.collection(AppConstants.setsCollection).doc(setId));
      await batch.commit();
      _logger.i('Deleted set $setId (${links.docs.length} card links removed)');
    } catch (e) {
      _logger.e('Failed to delete set $setId: $e');
      throw AppException('Failed to delete set', code: 'delete-set-failed');
    }
  }

  // --- Card membership -------------------------------------------------------

  // Add one card; creates the setCards link and increments cardCount atomically.
  @override
  Future<void> addCardToSet({
    required String setId,
    required String cardId,
    required String userId,
  }) async {
    try {
      final linkRef =
          _firestore.collection(AppConstants.setCardsCollection).doc();
      final link = SetCard(
        id: linkRef.id,
        setId: setId,
        cardId: cardId,
        userId: userId,
        addedAt: DateTime.now(),
      );
      final batch = _firestore.batch();
      batch.set(linkRef, link.toFirestore());
      batch.update(
        _firestore.collection(AppConstants.setsCollection).doc(setId),
        {'cardCount': FieldValue.increment(1), 'updatedAt': Timestamp.now()},
      );
      await batch.commit();
      _logger.i('Added card $cardId to set $setId');
    } catch (e) {
      _logger.e('Failed to add card to set: $e');
      throw AppException('Failed to add card to set',
          code: 'add-card-to-set-failed');
    }
  }

  @override
  Future<void> removeCardFromSet({
    required String setId,
    required String cardId,
    required String userId,
  }) async {
    try {
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('setId', isEqualTo: setId)
          .where('cardId', isEqualTo: cardId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (links.docs.isEmpty) return;

      final batch = _firestore.batch();
      batch.delete(links.docs.first.reference);
      batch.update(
        _firestore.collection(AppConstants.setsCollection).doc(setId),
        {'cardCount': FieldValue.increment(-1), 'updatedAt': Timestamp.now()},
      );
      await batch.commit();
      _logger.i('Removed card $cardId from set $setId');
    } catch (e) {
      _logger.e('Failed to remove card from set: $e');
      throw AppException('Failed to remove card from set',
          code: 'remove-card-failed');
    }
  }

  // Bulk-add; batched in groups of 249 to stay under Firestore's 500-op limit.
  @override
  Future<void> addCardsToSet({
    required String setId,
    required List<String> cardIds,
    required String userId,
  }) async {
    if (cardIds.isEmpty) return;
    try {
      const batchSize = 249;
      for (var i = 0; i < cardIds.length; i += batchSize) {
        final chunk = cardIds.sublist(i, min(i + batchSize, cardIds.length));
        final batch = _firestore.batch();
        for (final cardId in chunk) {
          final linkRef =
              _firestore.collection(AppConstants.setCardsCollection).doc();
          batch.set(linkRef, {
            'setId': setId,
            'cardId': cardId,
            'userId': userId,
            'addedAt': Timestamp.now(),
          });
        }
        batch.update(
          _firestore.collection(AppConstants.setsCollection).doc(setId),
          {
            'cardCount': FieldValue.increment(chunk.length),
            'updatedAt': Timestamp.now(),
          },
        );
        await batch.commit();
      }
      _logger.i('Bulk-added ${cardIds.length} cards to set $setId');
    } catch (e) {
      _logger.e('Failed to bulk-add cards to set: $e');
      throw AppException('Failed to add cards to set',
          code: 'bulk-add-cards-failed');
    }
  }

  @override
  Stream<List<String>> watchCardIdsInSet(String setId, String userId) {
    return _firestore
        .collection(AppConstants.setCardsCollection)
        .where('setId', isEqualTo: setId)
        .where('userId', isEqualTo: userId)
        .orderBy('addedAt')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => d.data()['cardId'] as String).toList());
  }

  // Stream full card objects; re-fetches cards whenever the setCards list changes.
  @override
  Stream<List<FlashCard>> watchCardsInSet(String setId, String userId) {
    return _firestore
        .collection(AppConstants.setCardsCollection)
        .where('setId', isEqualTo: setId)
        .where('userId', isEqualTo: userId)
        .orderBy('addedAt')
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return <FlashCard>[];
      final cardIds =
          snapshot.docs.map((d) => d.data()['cardId'] as String).toList();
      return _fetchCardsByIds(cardIds);
    });
  }

  Future<List<FlashCard>> _fetchCardsByIds(List<String> cardIds) async {
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
  }

  @override
  Future<CardSet?> findSetByName(String name, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.setsCollection)
          .where('userId', isEqualTo: userId)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return CardSet.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw AppException('Failed to look up set by name: $e');
    }
  }
}
