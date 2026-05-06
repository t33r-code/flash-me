import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/set_card.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

class CardSetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // --- Set CRUD ---------------------------------------------------------------

  // Create a new set and return it with its Firestore-assigned ID.
  Future<CardSet> createSet(CardSet cardSet) async {
    try {
      final docRef = _firestore.collection(AppConstants.setsCollection).doc();
      final now = DateTime.now();
      final newSet = cardSet.copyWith(
        id: docRef.id,
        cardCount: 0, // starts empty
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

  // Fetch a single set by ID; returns null if not found.
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

  // Update set metadata (name, description, tags, color).
  // cardCount is managed by addCardToSet / removeCardFromSet, not here.
  Future<void> updateSet(CardSet cardSet) async {
    try {
      final updated = cardSet.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(AppConstants.setsCollection)
          .doc(cardSet.id)
          .update(updated.toFirestore());
      _logger.i('Updated set ${cardSet.id}');
    } catch (e) {
      _logger.e('Failed to update set ${cardSet.id}: $e');
      throw AppException('Failed to update set', code: 'update-set-failed');
    }
  }

  // Hard-delete a set and all its setCards links.
  // The cards themselves are not deleted — they may belong to other sets.
  Future<void> deleteSet(String setId) async {
    try {
      // Fetch all join documents that reference this set.
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('setId', isEqualTo: setId)
          .get();

      final batch = _firestore.batch();
      for (final link in links.docs) {
        batch.delete(link.reference);
      }
      // Delete the set document itself.
      batch.delete(
          _firestore.collection(AppConstants.setsCollection).doc(setId));

      await batch.commit();
      _logger.i('Deleted set $setId (removed ${links.docs.length} card links)');
    } catch (e) {
      _logger.e('Failed to delete set $setId: $e');
      throw AppException('Failed to delete set', code: 'delete-set-failed');
    }
  }

  // Stream all sets owned by [userId], ordered by most recently updated.
  Stream<List<CardSet>> watchUserSets(String userId) {
    return _firestore
        .collection(AppConstants.setsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CardSet.fromFirestore).toList());
  }

  // --- Card membership --------------------------------------------------------

  // Add a single card to a set. Creates a setCards link and increments cardCount.
  // Uses a batch so both writes succeed or both fail.
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
        {
          'cardCount': FieldValue.increment(1),
          'updatedAt': Timestamp.now(),
        },
      );
      await batch.commit();
      _logger.i('Added card $cardId to set $setId');
    } catch (e) {
      _logger.e('Failed to add card $cardId to set $setId: $e');
      throw AppException('Failed to add card to set',
          code: 'add-card-to-set-failed');
    }
  }

  // Remove a single card from a set. Deletes the setCards link and decrements cardCount.
  Future<void> removeCardFromSet({
    required String setId,
    required String cardId,
  }) async {
    try {
      // Find the specific join document for this set+card pair.
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('setId', isEqualTo: setId)
          .where('cardId', isEqualTo: cardId)
          .limit(1)
          .get();

      if (links.docs.isEmpty) return; // already removed

      final batch = _firestore.batch();
      batch.delete(links.docs.first.reference);
      batch.update(
        _firestore.collection(AppConstants.setsCollection).doc(setId),
        {
          'cardCount': FieldValue.increment(-1),
          'updatedAt': Timestamp.now(),
        },
      );
      await batch.commit();
      _logger.i('Removed card $cardId from set $setId');
    } catch (e) {
      _logger.e('Failed to remove card $cardId from set $setId: $e');
      throw AppException('Failed to remove card from set',
          code: 'remove-card-failed');
    }
  }

  // Add multiple cards to a set in one operation (for bulk imports, etc.).
  // Batches writes in groups of 249 to stay under Firestore's 500-op limit
  // (each card = 1 link write + counted against the final cardCount update).
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
        // Increment cardCount by the chunk size.
        batch.update(
          _firestore.collection(AppConstants.setsCollection).doc(setId),
          {
            'cardCount': FieldValue.increment(chunk.length),
            'updatedAt': Timestamp.now(),
          },
        );
        await batch.commit();
      }
      _logger.i('Added ${cardIds.length} cards to set $setId');
    } catch (e) {
      _logger.e('Failed to bulk-add cards to set $setId: $e');
      throw AppException('Failed to add cards to set',
          code: 'bulk-add-cards-failed');
    }
  }

  // --- Card queries -----------------------------------------------------------

  // Stream the ordered list of card IDs in a set (from the setCards join).
  // Useful when you only need IDs (e.g. building a study session sequence).
  Stream<List<String>> watchCardIdsInSet(String setId) {
    return _firestore
        .collection(AppConstants.setCardsCollection)
        .where('setId', isEqualTo: setId)
        .orderBy('addedAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((d) => d.data()['cardId'] as String)
            .toList());
  }

  // Stream the full FlashCard objects for all cards in a set.
  //
  // Implementation: each time the setCards snapshot changes, fetch the
  // corresponding card documents in batches (Firestore whereIn limit = 30).
  // asyncMap converts the sync snapshot into an async card-fetch Future.
  Stream<List<FlashCard>> watchCardsInSet(String setId) {
    return _firestore
        .collection(AppConstants.setCardsCollection)
        .where('setId', isEqualTo: setId)
        .orderBy('addedAt')
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return <FlashCard>[];
          final cardIds = snapshot.docs
              .map((d) => d.data()['cardId'] as String)
              .toList();
          return _fetchCardsByIds(cardIds);
        });
  }

  // Fetch card documents for a list of IDs, batched to respect the 30-item
  // Firestore whereIn limit.
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
}
