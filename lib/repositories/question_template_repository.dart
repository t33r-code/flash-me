import 'package:flash_me/models/question_template.dart';

abstract class QuestionTemplateRepository {
  Stream<List<QuestionTemplate>> watchUserTemplates(String userId);
  Future<QuestionTemplate> createTemplate(QuestionTemplate template);
  Future<void> updateTemplate(QuestionTemplate template);
  Future<void> deleteTemplate(String templateId);
}
