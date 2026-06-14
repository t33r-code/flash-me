import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';
import 'package:flash_me/utils/helpers.dart';

// Orchestrates soft-delete account deletion:
//   1. Anonymise user document (tombstone — PII removed, document retained)
//   2. Unpublish all public sets (stop appearing in Market)
//   3. Delete Storage files attached to cards/workbook cards
//   4. Hard-delete all private Firestore content
//   5. Delete Firebase Auth account
//
// Step 5 throws AppException('requires-recent-login') if the session is stale —
// the caller should prompt the user to sign out and back in before retrying.
class AccountDeletionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> deleteAccount(String userId) async {
    AppLogger.info('AccountDeletionService: starting deletion for $userId');

    // 1. Anonymise user document — removes PII while retaining tombstone for
    //    content attribution and future abuse-reporting needs.
    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'email': null,
      'displayName': 'Deleted User',
      'photoUrl': null,
    });
    AppLogger.info('AccountDeletionService: user document anonymised');

    // 2. Query all sets upfront — needed for both unpublish and delete steps.
    final setsSnap = await _db
        .collection(AppConstants.setsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    // Unpublish any sets that are currently public so they vanish from the Market.
    final publicRefs = setsSnap.docs
        .where((d) => d.data()['isPublic'] == true)
        .map((d) => d.reference)
        .toList();
    if (publicRefs.isNotEmpty) {
      final batch = _db.batch();
      for (final ref in publicRefs) {
        batch.update(ref, {'isPublic': false});
      }
      await batch.commit();
      AppLogger.info(
          'AccountDeletionService: unpublished ${publicRefs.length} sets');
    }

    // 3. Delete Firebase Storage files attached to flash cards and workbook cards.
    final cardsSnap = await _db
        .collection(AppConstants.cardsCollection)
        .where('createdBy', isEqualTo: userId)
        .get();
    final workbookCardsSnap = await _db
        .collection(AppConstants.workbookCardsCollection)
        .where('createdBy', isEqualTo: userId)
        .get();

    for (final doc in [...cardsSnap.docs, ...workbookCardsSnap.docs]) {
      await _deleteStorageFile(doc.data()['primaryImageUrl'] as String?);
      await _deleteStorageFile(doc.data()['primaryAudioUrl'] as String?);
    }
    AppLogger.info('AccountDeletionService: Storage files deleted');

    // 4. Hard-delete all private Firestore content.
    final templatesSnap = await _db
        .collection(AppConstants.templatesCollection)
        .where('createdBy', isEqualTo: userId)
        .get();
    final questionTemplatesSnap = await _db
        .collection(AppConstants.questionTemplatesCollection)
        .where('createdBy', isEqualTo: userId)
        .get();
    final setCardsSnap = await _db
        .collection(AppConstants.setCardsCollection)
        .where('userId', isEqualTo: userId)
        .get();
    final setAcquisitionsSnap = await _db
        .collection(AppConstants.setAcquisitionsCollection)
        .where('acquiredByUserId', isEqualTo: userId)
        .get();
    final cardAcquisitionsSnap = await _db
        .collection(AppConstants.cardAcquisitionsCollection)
        .where('acquiredByUserId', isEqualTo: userId)
        .get();

    await _batchDelete([
      ...cardsSnap.docs.map((d) => d.reference),
      ...workbookCardsSnap.docs.map((d) => d.reference),
      ...setsSnap.docs.map((d) => d.reference),
      ...templatesSnap.docs.map((d) => d.reference),
      ...questionTemplatesSnap.docs.map((d) => d.reference),
      ...setCardsSnap.docs.map((d) => d.reference),
      ...setAcquisitionsSnap.docs.map((d) => d.reference),
      ...cardAcquisitionsSnap.docs.map((d) => d.reference),
    ]);
    AppLogger.info('AccountDeletionService: top-level collections deleted');

    // Delete subcollections stored under users/{userId}/.
    await _deleteSubcollection(userId, AppConstants.studySessionsSubcollection);
    await _deleteSubcollection(userId, AppConstants.cardMarksSubcollection);
    await _deleteSubcollection(userId, AppConstants.questionResultsSubcollection);
    AppLogger.info('AccountDeletionService: subcollections deleted');

    // 5. Delete Firebase Auth account — point of no return.
    //    Throws requires-recent-login if the session is stale.
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      AppLogger.error('AccountDeletionService: auth delete failed: ${e.code}');
      throw AppException(e.message ?? 'Account deletion failed', code: e.code);
    }
    AppLogger.info('AccountDeletionService: Firebase Auth account deleted');
  }

  // Delete a Storage file by download URL; silently ignores missing files.
  Future<void> _deleteStorageFile(String? url) async {
    if (url == null) return;
    try {
      await _storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        AppLogger.error('AccountDeletionService: Storage delete failed: $e');
      }
    }
  }

  // Delete a list of Firestore document references in batches of 400.
  Future<void> _batchDelete(List<DocumentReference> refs) async {
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  // Delete all documents in a subcollection under users/{userId}, paginated
  // to handle arbitrarily large collections without memory pressure.
  Future<void> _deleteSubcollection(
      String userId, String subcollection) async {
    const pageSize = 400;
    while (true) {
      final snap = await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(subcollection)
          .limit(pageSize)
          .get();
      if (snap.docs.isEmpty) break;
      await _batchDelete(snap.docs.map((d) => d.reference).toList());
    }
  }
}
