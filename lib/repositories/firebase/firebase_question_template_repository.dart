import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/question_template.dart';
import 'package:flash_me/repositories/question_template_repository.dart';
import 'package:flash_me/utils/constants.dart';

class FirebaseQuestionTemplateRepository implements QuestionTemplateRepository {
  final FirebaseFirestore _firestore;
  FirebaseQuestionTemplateRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.questionTemplatesCollection);

  @override
  Stream<List<QuestionTemplate>> watchUserTemplates(String userId) =>
      _col
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) =>
              snap.docs.map(QuestionTemplate.fromFirestore).toList());

  @override
  Future<List<QuestionTemplate>> getUserTemplates(String userId) async {
    final snap = await _col
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(QuestionTemplate.fromFirestore).toList();
  }

  @override
  Future<QuestionTemplate> createTemplate(QuestionTemplate template) async {
    final ref = await _col.add(template.toFirestore());
    final snap = await ref.get();
    return QuestionTemplate.fromFirestore(snap);
  }

  @override
  Future<void> updateTemplate(QuestionTemplate template) =>
      _col.doc(template.id).update({
        ...template.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteTemplate(String templateId) =>
      _col.doc(templateId).delete();
}
