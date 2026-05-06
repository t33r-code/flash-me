import 'package:flash_me/models/card_template.dart';

// Provider-agnostic contract for card template persistence.
abstract class TemplateRepository {
  Future<CardTemplate> createTemplate(CardTemplate template);
  Future<CardTemplate?> getTemplate(String templateId);
  Stream<List<CardTemplate>> watchUserTemplates(String userId);
  Future<void> updateTemplate(CardTemplate template);

  // Hard-delete a template. Cards created from it keep their fields intact.
  Future<void> deleteTemplate(String templateId);
}
