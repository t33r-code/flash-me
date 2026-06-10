import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/set_update_diff.dart';
import 'package:flash_me/repositories/set_acquisition_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

// Firebase implementation of SetAcquisitionRepository.
// All clone/update logic lives here; no external repository dependencies —
// this class speaks directly to Firestore so it can combine reads from
// multiple collections without coupling to the individual repository abstractions.
class FirebaseSetAcquisitionRepository implements SetAcquisitionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  @override
  Future<CardSet> cloneSet({
    required String originalSetId,
    required String clonerId,
  }) async {
    try {
      // --- 1. Read the source set -------------------------------------------
      final sourceDoc = await _db
          .collection(AppConstants.setsCollection)
          .doc(originalSetId)
          .get();
      if (!sourceDoc.exists) {
        throw AppException('Source set not found', code: 'set-not-found');
      }
      final sourceSet = CardSet.fromFirestore(sourceDoc);

      // --- 2. Read all setCards join docs for the source set ----------------
      // Include userId so the query uses the existing (setId, userId, addedAt) index.
      final setCardsSnap = await _db
          .collection(AppConstants.setCardsCollection)
          .where('setId', isEqualTo: originalSetId)
          .where('userId', isEqualTo: sourceSet.userId)
          .orderBy('addedAt')
          .get();

      // --- 3. Resolve each card into a cardId owned by the cloner -----------
      final cardEntries = <({String cardId, String cardType})>[];

      for (final link in setCardsSnap.docs) {
        final linkData = link.data();
        final sourceCardId = linkData['cardId'] as String;
        final cardType =
            linkData['cardType'] as String? ?? AppConstants.cardTypeFlashcard;

        // Step 3a: check cardAcquisitions — covers re-cloning and overlapping sets.
        final previouslyAcquired =
            await _lookupCardAcquisition(sourceCardId, clonerId);
        if (previouslyAcquired != null) {
          cardEntries.add((cardId: previouslyAcquired, cardType: cardType));
          continue;
        }

        // Step 3b: type-specific copy (also writes cardAcquisitions).
        final copiedId = await _copyCard(sourceCardId, cardType, clonerId);
        if (copiedId != null) {
          cardEntries.add((cardId: copiedId, cardType: cardType));
        }
      }

      // --- 4. Create the cloned CardSet -------------------------------------
      final now = DateTime.now();
      final setRef = _db.collection(AppConstants.setsCollection).doc();
      final clonedSet = CardSet(
        id: setRef.id,
        userId: clonerId,
        name: sourceSet.name,
        description: sourceSet.description,
        cardCount: cardEntries.length,
        acquisitionCount: 0,
        createdAt: now,
        updatedAt: now,
        isPublic: false,
        tags: sourceSet.tags,
        color: sourceSet.color,
        nativeLanguage: sourceSet.nativeLanguage,
        targetLanguage: sourceSet.targetLanguage,
      );

      // --- 5. Write set + setCards + acquisition record + counter -----------
      // Batch in groups of 249 to stay under the 500-op Firestore limit.
      final firstBatch = _db.batch();
      firstBatch.set(setRef, clonedSet.toFirestore());

      const maxLinksPerBatch = 248;
      final firstChunk = cardEntries.take(maxLinksPerBatch).toList();
      for (final entry in firstChunk) {
        final linkRef = _db.collection(AppConstants.setCardsCollection).doc();
        firstBatch.set(linkRef, {
          'setId': setRef.id,
          'cardId': entry.cardId,
          'userId': clonerId,
          'addedAt': Timestamp.fromDate(now),
          'cardType': entry.cardType,
        });
      }
      await firstBatch.commit();

      // Overflow batches for sets with more than 248 cards.
      final remaining = cardEntries.skip(maxLinksPerBatch).toList();
      for (var i = 0; i < remaining.length; i += 249) {
        final chunk = remaining.sublist(i, min(i + 249, remaining.length));
        final batch = _db.batch();
        for (final entry in chunk) {
          final linkRef = _db.collection(AppConstants.setCardsCollection).doc();
          batch.set(linkRef, {
            'setId': setRef.id,
            'cardId': entry.cardId,
            'userId': clonerId,
            'addedAt': Timestamp.fromDate(now),
            'cardType': entry.cardType,
          });
        }
        await batch.commit();
      }

      // Final batch: set-level acquisition record + acquisitionCount increment.
      final finalBatch = _db.batch();
      final acquisitionRef =
          _db.collection(AppConstants.setAcquisitionsCollection).doc();
      finalBatch.set(acquisitionRef, {
        'acquiredByUserId': clonerId,
        'originalSetId': originalSetId,
        'originalUserId': sourceSet.userId,
        'acquiredSetId': setRef.id,
        'acquisitionType': 'clone',
        'acquiredAt': Timestamp.fromDate(now),
      });
      finalBatch.update(
        _db.collection(AppConstants.setsCollection).doc(originalSetId),
        {'acquisitionCount': FieldValue.increment(1)},
      );
      await finalBatch.commit();

      _logger.i(
        'Cloned set $originalSetId → ${setRef.id} '
        '(${cardEntries.length} cards, cloner: $clonerId)',
      );
      return clonedSet;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.e('Clone failed: $e');
      throw AppException('Failed to clone set', code: 'clone-set-failed');
    }
  }

  @override
  Future<SetUpdateDiff> checkForUpdates({
    required String originalSetId,
    required String clonerId,
  }) async {
    try {
      // Read the source set to get the creator's userId for the setCards query.
      final sourceDoc = await _db
          .collection(AppConstants.setsCollection)
          .doc(originalSetId)
          .get();
      if (!sourceDoc.exists) {
        throw AppException('Source set not found', code: 'set-not-found');
      }
      final sourceSet = CardSet.fromFirestore(sourceDoc);

      // Enumerate all cards currently in the source set.
      final setCardsSnap = await _db
          .collection(AppConstants.setCardsCollection)
          .where('setId', isEqualTo: originalSetId)
          .where('userId', isEqualTo: sourceSet.userId)
          .orderBy('addedAt')
          .get();

      final newCards =
          <({String sourceCardId, String cardType})>[];
      final updatedCards =
          <({String sourceCardId, String acquiredCardId, String cardType})>[];

      for (final link in setCardsSnap.docs) {
        final linkData = link.data();
        final sourceCardId = linkData['cardId'] as String;
        final cardType =
            linkData['cardType'] as String? ?? AppConstants.cardTypeFlashcard;

        // Check whether the cloner has previously acquired this card.
        final acqSnap = await _db
            .collection(AppConstants.cardAcquisitionsCollection)
            .where('acquiredByUserId', isEqualTo: clonerId)
            .where('originalCardId', isEqualTo: sourceCardId)
            .limit(1)
            .get();

        if (acqSnap.docs.isEmpty) {
          // Card was added to the source set after the original clone.
          newCards.add((sourceCardId: sourceCardId, cardType: cardType));
          continue;
        }

        // Card was previously cloned — compare updatedAt timestamps.
        final acquiredCardId =
            acqSnap.docs.first.data()['acquiredCardId'] as String;
        final collection = _collectionFor(cardType);

        final sourceFuture =
            _db.collection(collection).doc(sourceCardId).get();
        final acquiredFuture =
            _db.collection(collection).doc(acquiredCardId).get();
        final results = await Future.wait([sourceFuture, acquiredFuture]);
        final sourceCard = results[0];
        final acquiredCard = results[1];

        if (!sourceCard.exists || !acquiredCard.exists) continue;

        final sourceUpdatedAt =
            (sourceCard.data()!['updatedAt'] as Timestamp).toDate();
        final acquiredUpdatedAt =
            (acquiredCard.data()!['updatedAt'] as Timestamp).toDate();

        if (sourceUpdatedAt.isAfter(acquiredUpdatedAt)) {
          updatedCards.add((
            sourceCardId: sourceCardId,
            acquiredCardId: acquiredCardId,
            cardType: cardType,
          ));
        }
      }

      return SetUpdateDiff(newCards: newCards, updatedCards: updatedCards);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.e('checkForUpdates failed: $e');
      throw AppException('Failed to check for updates',
          code: 'check-updates-failed');
    }
  }

  @override
  Future<void> applySetUpdate({
    required String originalSetId,
    required String acquiredSetId,
    required String clonerId,
    required SetUpdateDiff diff,
  }) async {
    try {
      final now = DateTime.now();

      // --- 1. Overwrite updated cards with source data ----------------------
      // Uses set() (full replace) rather than update() so removed fields are
      // also removed. createdBy and createdAt are preserved from the cloner's copy.
      for (final entry in diff.updatedCards) {
        final collection = _collectionFor(entry.cardType);
        final sourceFuture =
            _db.collection(collection).doc(entry.sourceCardId).get();
        final acquiredFuture =
            _db.collection(collection).doc(entry.acquiredCardId).get();
        final results = await Future.wait([sourceFuture, acquiredFuture]);
        final sourceDoc = results[0];
        final acquiredDoc = results[1];

        if (!sourceDoc.exists || !acquiredDoc.exists) continue;

        // Keep the cloner's createdAt so the card's age in their library is preserved.
        final originalCreatedAt = acquiredDoc.data()!['createdAt'];
        await _db.collection(collection).doc(entry.acquiredCardId).set({
          ...sourceDoc.data()!,
          'createdBy': clonerId,
          'createdAt': originalCreatedAt,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // --- 2. Copy new cards and add setCard links --------------------------
      final addedEntries = <({String cardId, String cardType})>[];

      for (final entry in diff.newCards) {
        // Guard against a card being acquired between checkForUpdates and now.
        final existing =
            await _lookupCardAcquisition(entry.sourceCardId, clonerId);
        if (existing != null) {
          addedEntries.add((cardId: existing, cardType: entry.cardType));
          continue;
        }

        final copiedId =
            await _copyCard(entry.sourceCardId, entry.cardType, clonerId);
        if (copiedId != null) {
          addedEntries.add((cardId: copiedId, cardType: entry.cardType));
        }
      }

      if (addedEntries.isNotEmpty) {
        // Write setCard links in batches of 249.
        const maxPerBatch = 249;
        for (var i = 0; i < addedEntries.length; i += maxPerBatch) {
          final chunk =
              addedEntries.sublist(i, min(i + maxPerBatch, addedEntries.length));
          final batch = _db.batch();
          for (final entry in chunk) {
            final linkRef =
                _db.collection(AppConstants.setCardsCollection).doc();
            batch.set(linkRef, {
              'setId': acquiredSetId,
              'cardId': entry.cardId,
              'userId': clonerId,
              'addedAt': Timestamp.fromDate(now),
              'cardType': entry.cardType,
            });
          }
          await batch.commit();
        }

        // Bump cardCount on the cloner's set.
        await _db
            .collection(AppConstants.setsCollection)
            .doc(acquiredSetId)
            .update({
          'cardCount': FieldValue.increment(addedEntries.length),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      _logger.i(
        'Updated set $acquiredSetId from source $originalSetId: '
        '${diff.updatedCards.length} refreshed, '
        '${addedEntries.length} added (cloner: $clonerId)',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.e('applySetUpdate failed: $e');
      throw AppException('Failed to update set', code: 'update-set-failed');
    }
  }

  // --- Private helpers -------------------------------------------------------

  // Firestore collection name for a given card type.
  String _collectionFor(String cardType) => cardType == AppConstants.cardTypeWorkbook
      ? AppConstants.workbookCardsCollection
      : AppConstants.cardsCollection;

  // Check whether the cloner already has a cardAcquisitions record for
  // [sourceCardId]. Returns the acquired card's ID, or null if not found.
  Future<String?> _lookupCardAcquisition(
      String sourceCardId, String clonerId) async {
    final snap = await _db
        .collection(AppConstants.cardAcquisitionsCollection)
        .where('acquiredByUserId', isEqualTo: clonerId)
        .where('originalCardId', isEqualTo: sourceCardId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['acquiredCardId'] as String;
  }

  // Copy a card (any type) into the cloner's library and write a provenance record.
  // Returns the new card's document ID, or null if the source card is missing.
  Future<String?> _copyCard(
      String sourceCardId, String cardType, String clonerId) async {
    final collection = _collectionFor(cardType);
    final sourceDoc =
        await _db.collection(collection).doc(sourceCardId).get();
    if (!sourceDoc.exists) return null;

    final now = DateTime.now();
    final newRef = _db.collection(collection).doc();
    await newRef.set({
      ...sourceDoc.data()!,
      'createdBy': clonerId,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    await _writeCardAcquisition(
      sourceCardId: sourceCardId,
      acquiredCardId: newRef.id,
      cardType: cardType,
      clonerId: clonerId,
      now: now,
    );
    return newRef.id;
  }

  // Write a single cardAcquisitions provenance record.
  Future<void> _writeCardAcquisition({
    required String sourceCardId,
    required String acquiredCardId,
    required String cardType,
    required String clonerId,
    required DateTime now,
  }) async {
    final ref = _db.collection(AppConstants.cardAcquisitionsCollection).doc();
    await ref.set({
      'acquiredByUserId': clonerId,
      'originalCardId': sourceCardId,
      'originalCardType': cardType,
      'acquiredCardId': acquiredCardId,
      'acquiredAt': Timestamp.fromDate(now),
    });
  }
}
