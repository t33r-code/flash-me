import 'package:flash_me/models/question_template.dart';

abstract class QuestionTemplateRepository {
  Stream<List<QuestionTemplate>> watchUserTemplates(String userId);
  // One-shot fetch — used by the import service to resolve ##templateId references.
  Future<List<QuestionTemplate>> getUserTemplates(String userId);
  Future<QuestionTemplate> createTemplate(QuestionTemplate template);
  Future<void> updateTemplate(QuestionTemplate template);
  Future<void> deleteTemplate(String templateId);
}
