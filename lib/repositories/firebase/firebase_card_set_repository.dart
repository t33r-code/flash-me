import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/set_card.dart';
import 'package:flash_me/repositories/card_set_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';
import 'package:flash_me/utils/set_ordering.dart';

// Firestore implementation of CardSetRepository.
class FirebaseCardSetRepository implements CardSetRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // --- Set CRUD --------------------------------------------------------------

  @override
  Future<CardSet> createSet(CardSet cardSet) async {
    final errors = cardSet.validate();
    if (errors.isNotEmpty) {
      throw AppException(errors.join('; '), code: 'validation-failed');
    }
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
    final errors = cardSet.validate();
    if (errors.isNotEmpty) {
      throw AppException(errors.join('; '), code: 'validation-failed');
    }
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
  // New links are appended: position = the set's current cardCount.
  @override
  Future<void> addCardToSet({
    required String setId,
    required String cardId,
    required String userId,
    String cardType = AppConstants.cardTypeFlashcard,
    int? position,
  }) async {
    try {
      final linkRef =
          _firestore.collection(AppConstants.setCardsCollection).doc();
      // Restore at the given position when provided (undo), else append.
      final pos = position ?? await _nextPosition(setId);
      final link = SetCard(
        id: linkRef.id,
        setId: setId,
        cardId: cardId,
        userId: userId,
        addedAt: DateTime.now(),
        cardType: cardType,
        position: pos,
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

  // The next append position for a set = its current cardCount (0-based end).
  // Falls back to 0 if the set doc is missing.
  Future<int> _nextPosition(String setId) async {
    final setDoc = await _firestore
        .collection(AppConstants.setsCollection)
        .doc(setId)
        .get();
    return (setDoc.data()?['cardCount'] as int?) ?? 0;
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
    String cardType = AppConstants.cardTypeFlashcard,
  }) async {
    if (cardIds.isEmpty) return;
    try {
      // Append: positions run from the set's current cardCount upward, so the
      // bulk-added cards preserve their given order at the end of the set.
      var nextPosition = await _nextPosition(setId);
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
            'cardType': cardType,
            'position': nextPosition++,
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

  // Stamp each link's `position` with its index in [orderedCardIds]. This also
  // backfills any legacy links in the set (they gain a concrete position here).
  // Cards not present in the set are skipped. Batched under Firestore's op limit.
  @override
  Future<void> reorderCards({
    required String setId,
    required String userId,
    required List<String> orderedCardIds,
  }) async {
    if (orderedCardIds.isEmpty) return;
    try {
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('setId', isEqualTo: setId)
          .where('userId', isEqualTo: userId)
          .get();
      // A card appears at most once per set, so cardId -> link ref is unique.
      final refByCardId = {
        for (final d in links.docs) d.data()['cardId'] as String: d.reference,
      };

      const batchSize = 249;
      for (var i = 0; i < orderedCardIds.length; i += batchSize) {
        final chunk = orderedCardIds.sublist(
            i, min(i + batchSize, orderedCardIds.length));
        final batch = _firestore.batch();
        for (var j = 0; j < chunk.length; j++) {
          final ref = refByCardId[chunk[j]];
          if (ref == null) continue; // not a member of this set — skip
          batch.update(ref, {'position': i + j});
        }
        batch.update(
          _firestore.collection(AppConstants.setsCollection).doc(setId),
          {'updatedAt': Timestamp.now()},
        );
        await batch.commit();
      }
      _logger.i('Reordered ${orderedCardIds.length} cards in set $setId');
    } catch (e) {
      _logger.e('Failed to reorder cards in set $setId: $e');
      throw AppException('Failed to reorder cards',
          code: 'reorder-cards-failed');
    }
  }

  // Query by addedAt (indexed, returns every link incl. legacy ones with no
  // position), then order by position client-side (see sortSetCardsByPosition).
  @override
  Stream<List<String>> watchCardIdsInSet(String setId, String userId) {
    return _firestore
        .collection(AppConstants.setCardsCollection)
        .where('setId', isEqualTo: setId)
        .where('userId', isEqualTo: userId)
        .orderBy('addedAt')
        .snapshots()
        .map((s) => sortSetCardsByPosition(
                s.docs.map(SetCard.fromFirestore).toList())
            .map((c) => c.cardId)
            .toList());
  }

  // Stream full card objects with a live subscription per card (#320). A
  // one-time `.get()` per card — re-run only when the setCards join changes —
  // went stale whenever a card's own fields (e.g. its image) were edited
  // without touching the join doc: the cached list wouldn't refresh until the
  // whole listener was torn down and recreated (e.g. by leaving the set
  // entirely), which is what made a saved image "disappear" until you left
  // and came back. Instead, keep one doc-level listener per card alive and
  // recompute the combined list whenever any of them fires.
  @override
  Stream<List<FlashCard>> watchCardsInSet(String setId, String userId) {
    late final StreamController<List<FlashCard>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? joinSub;
    final cardSubs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final latestCards = <String, FlashCard>{};
    var order = <String>[];

    void emit() {
      if (controller.isClosed) return;
      controller.add([
        for (final id in order)
          if (latestCards[id] != null) latestCards[id]!,
      ]);
    }

    void setCardIds(List<String> cardIds) {
      order = cardIds;
      final idSet = cardIds.toSet();
      for (final id in cardSubs.keys.where((id) => !idSet.contains(id)).toList()) {
        cardSubs.remove(id)?.cancel();
        latestCards.remove(id);
      }
      for (final id in cardIds) {
        if (cardSubs.containsKey(id)) continue;
        cardSubs[id] = _firestore
            .collection(AppConstants.cardsCollection)
            .doc(id)
            .snapshots()
            .listen(
          (snap) {
            if (snap.exists) {
              latestCards[id] = FlashCard.fromFirestore(snap);
            } else {
              latestCards.remove(id);
            }
            emit();
          },
          // One inaccessible/errored card is dropped, not fatal to the rest.
          onError: (_) {
            latestCards.remove(id);
            emit();
          },
        );
      }
      emit();
    }

    controller = StreamController<List<FlashCard>>.broadcast(
      onListen: () {
        joinSub = _firestore
            .collection(AppConstants.setCardsCollection)
            .where('setId', isEqualTo: setId)
            .where('userId', isEqualTo: userId)
            .orderBy('addedAt')
            .snapshots()
            .listen((snapshot) {
          setCardIds(sortSetCardsByPosition(
                  snapshot.docs.map(SetCard.fromFirestore).toList())
              .map((c) => c.cardId)
              .toList());
        });
      },
      onCancel: () async {
        await joinSub?.cancel();
        for (final sub in cardSubs.values) {
          await sub.cancel();
        }
        cardSubs.clear();
        latestCards.clear();
      },
    );

    return controller.stream;
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

  // Stream all SetCard join documents for a set, ordered by position.
  // Includes cardType so callers can dispatch to the right card collection.
  @override
  Stream<List<SetCard>> watchSetCards(String setId, String userId) {
    return _firestore
        .collection(AppConstants.setCardsCollection)
        .where('setId', isEqualTo: setId)
        .where('userId', isEqualTo: userId)
        .orderBy('addedAt')
        .snapshots()
        .map((s) => sortSetCardsByPosition(
            s.docs.map(SetCard.fromFirestore).toList()));
  }

  // Stream all public sets ordered by creation date descending — the Market feed.
  @override
  Stream<List<CardSet>> watchPublicSets() {
    return _firestore
        .collection(AppConstants.setsCollection)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(CardSet.fromFirestore).toList());
  }

  @override
  Future<List<CardSet>> getSetsContainingCard(String cardId, String userId) async {
    try {
      final links = await _firestore
          .collection(AppConstants.setCardsCollection)
          .where('cardId', isEqualTo: cardId)
          .where('userId', isEqualTo: userId)
          .get();
      if (links.docs.isEmpty) return [];
      final setIds = links.docs.map((d) => d.data()['setId'] as String).toList();
      final sets = <CardSet>[];
      for (final setId in setIds) {
        final set = await getSet(setId);
        if (set != null) sets.add(set);
      }
      return sets;
    } catch (e) {
      _logger.e('Failed to get sets for card $cardId: $e');
      throw AppException('Failed to get sets for card', code: 'get-sets-for-card-failed');
    }
  }
}
