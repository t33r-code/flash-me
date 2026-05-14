import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/card_mark.dart';
import 'package:flash_me/repositories/card_mark_repository.dart';
import 'package:flash_me/utils/constants.dart';

// Firestore implementation — stores marks as users/{userId}/cardMarks/{cardId}.
// Using cardId as the document ID gives O(1) lookup and natural upsert semantics.
class FirebaseCardMarkRepository implements CardMarkRepository {
  final FirebaseFirestore _db;
  FirebaseCardMarkRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _col(String userId) => _db
      .collection(AppConstants.usersCollection)
      .doc(userId)
      .collection(AppConstants.cardMarksSubcollection);

  @override
  Future<void> setMark(String userId, String cardId, String mark) async {
    final now = Timestamp.now();
    final ref = _col(userId).doc(cardId);
    final snap = await ref.get();
    // Preserve the original markedAt so we know when the user first marked it.
    await ref.set({
      'mark': mark,
      'markedAt': snap.exists ? snap['markedAt'] : now,
      'updatedAt': now,
    });
  }

  @override
  Future<void> removeMark(String userId, String cardId) =>
      _col(userId).doc(cardId).delete();

  @override
  Stream<List<CardMark>> watchMarks(String userId) => _col(userId)
      .snapshots()
      .map((s) => s.docs.map(CardMark.fromFirestore).toList());
}
