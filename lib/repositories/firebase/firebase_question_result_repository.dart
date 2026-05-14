import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/question_result.dart';
import 'package:flash_me/repositories/question_result_repository.dart';
import 'package:flash_me/utils/constants.dart';

// Firestore implementation — stores results at:
//   users/{uid}/questionResults/{cardId}_{fieldId}
//
// recordResult does a read-then-write to prepend the new outcome and trim the
// window. Fire-and-forget at the call site, so transient failures are silent.
class FirebaseQuestionResultRepository implements QuestionResultRepository {
  final FirebaseFirestore _db;
  FirebaseQuestionResultRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference _col(String userId) => _db
      .collection(AppConstants.usersCollection)
      .doc(userId)
      .collection(AppConstants.questionResultsSubcollection);

  @override
  Future<void> recordResult({
    required String userId,
    required String cardId,
    required String fieldId,
    required String fieldName,
    required String fieldType,
    required String outcome,
  }) async {
    final ref = _col(userId).doc(QuestionResult.docId(cardId, fieldId));
    final snap = await ref.get();

    final QuestionResult current;
    if (snap.exists) {
      current = QuestionResult.fromFirestore(snap);
    } else {
      current = QuestionResult(
        cardId: cardId,
        fieldId: fieldId,
        fieldName: fieldName,
        fieldType: fieldType,
        results: QuestionResult.defaultResults,
        updatedAt: DateTime.now(),
      );
    }

    await ref.set(current.withNewResult(outcome).toFirestore());
  }

  @override
  Stream<List<QuestionResult>> watchResults(String userId) => _col(userId)
      .snapshots()
      .map((s) => s.docs.map(QuestionResult.fromFirestore).toList());

  @override
  Future<List<QuestionResult>> getResultsForCard(
      String userId, String cardId) async {
    // Document IDs start with "{cardId}_", so prefix-query with >= / <.
    final snap = await _col(userId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${cardId}_')
        .where(FieldPath.documentId, isLessThan: '${cardId}_￿')
        .get();
    return snap.docs.map(QuestionResult.fromFirestore).toList();
  }
}
