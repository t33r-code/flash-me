import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/repositories/set_acquisition_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

// Firebase implementation of SetAcquisitionRepository.
// All clone logic lives here; no external repository dependencies — this class
// speaks directly to Firestore so it can combine reads from multiple collections
// without coupling to the individual repository abstractions.
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
        final cardType = linkData['cardType'] as String? ??
            AppConstants.cardTypeFlashcard;

        // Step 3a: check cardAcquisitions — covers re-cloning and overlapping sets.
        final previouslyAcquired =
            await _lookupCardAcquisition(sourceCardId, clonerId);
        if (previouslyAcquired != null) {
          cardEntries.add((cardId: previouslyAcquired, cardType: cardType));
          continue;
        }

        // Step 3b: type-specific resolution (also writes cardAcquisitions when copying).
        if (cardType == AppConstants.cardTypeFlashcard) {
          final resolvedId = await _resolveFlashCard(sourceCardId, clonerId);
          if (resolvedId != null) {
            cardEntries.add((cardId: resolvedId, cardType: cardType));
          }
        } else if (cardType == AppConstants.cardTypeWorkbook) {
          final copiedId = await _copyWorkbookCard(sourceCardId, clonerId);
          if (copiedId != null) {
            cardEntries.add((cardId: copiedId, cardType: cardType));
          }
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

  // --- Private helpers -------------------------------------------------------

  // Check whether the cloner already has a cardAcquisitions record for
  // [sourceCardId]. Returns the acquired card's ID, or null if not found.
  // This is the universal dedup key — works for any card type.
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

  // Resolve a flash card for the cloner:
  //   • Content match (primaryWord + translation) → link the existing card,
  //     no cardAcquisitions record (it's a pre-existing library card).
  //   • No match → copy the card and write a cardAcquisitions record.
  // Returns null if the source card can't be read.
  Future<String?> _resolveFlashCard(
      String sourceCardId, String clonerId) async {
    final sourceDoc = await _db
        .collection(AppConstants.cardsCollection)
        .doc(sourceCardId)
        .get();
    if (!sourceDoc.exists) return null;
    final data = sourceDoc.data()!;
    final primaryWord = data['primaryWord'] as String? ?? '';
    final translation = data['translation'] as String? ?? '';

    // Search the cloner's library for a content match.
    final existing = await _db
        .collection(AppConstants.cardsCollection)
        .where('createdBy', isEqualTo: clonerId)
        .where('primaryWord', isEqualTo: primaryWord)
        .where('translation', isEqualTo: translation)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Pre-existing card — link without recording provenance.
      return existing.docs.first.id;
    }

    // No match — copy the card and record its provenance.
    final now = DateTime.now();
    final newRef = _db.collection(AppConstants.cardsCollection).doc();
    await newRef.set({
      ...data,
      'createdBy': clonerId,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    await _writeCardAcquisition(
      sourceCardId: sourceCardId,
      acquiredCardId: newRef.id,
      cardType: AppConstants.cardTypeFlashcard,
      clonerId: clonerId,
      now: now,
    );
    return newRef.id;
  }

  // Copy a workbook card into the cloner's library and record its provenance.
  // Workbook cards have no content-based dedup key — cardAcquisitions is the
  // only dedup mechanism (checked before this method is called).
  // Returns null if the source card can't be read.
  Future<String?> _copyWorkbookCard(
      String sourceCardId, String clonerId) async {
    final sourceDoc = await _db
        .collection(AppConstants.workbookCardsCollection)
        .doc(sourceCardId)
        .get();
    if (!sourceDoc.exists) return null;
    final data = sourceDoc.data()!;
    final now = DateTime.now();
    final newRef = _db.collection(AppConstants.workbookCardsCollection).doc();
    await newRef.set({
      ...data,
      'createdBy': clonerId,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    await _writeCardAcquisition(
      sourceCardId: sourceCardId,
      acquiredCardId: newRef.id,
      cardType: AppConstants.cardTypeWorkbook,
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
