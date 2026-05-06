import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

class TemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // --- Write operations -------------------------------------------------------

  // Create a new template and return it with its Firestore-assigned ID.
  Future<CardTemplate> createTemplate(CardTemplate template) async {
    try {
      final docRef =
          _firestore.collection(AppConstants.templatesCollection).doc();
      final now = DateTime.now();
      final newTemplate = template.copyWith(
        id: docRef.id,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(newTemplate.toFirestore());
      _logger.i('Created template ${docRef.id}');
      return newTemplate;
    } catch (e) {
      _logger.e('Failed to create template: $e');
      throw AppException('Failed to create template',
          code: 'create-template-failed');
    }
  }

  // Overwrite all mutable fields on an existing template document.
  Future<void> updateTemplate(CardTemplate template) async {
    try {
      final updated = template.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(AppConstants.templatesCollection)
          .doc(template.id)
          .update(updated.toFirestore());
      _logger.i('Updated template ${template.id}');
    } catch (e) {
      _logger.e('Failed to update template ${template.id}: $e');
      throw AppException('Failed to update template',
          code: 'update-template-failed');
    }
  }

  // Hard-delete a template. Cards that were created from it keep their fields;
  // only the templateId reference is affected (cards are not deleted).
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _firestore
          .collection(AppConstants.templatesCollection)
          .doc(templateId)
          .delete();
      _logger.i('Deleted template $templateId');
    } catch (e) {
      _logger.e('Failed to delete template $templateId: $e');
      throw AppException('Failed to delete template',
          code: 'delete-template-failed');
    }
  }

  // --- Read operations --------------------------------------------------------

  // Fetch a single template by ID; returns null if not found.
  Future<CardTemplate?> getTemplate(String templateId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.templatesCollection)
          .doc(templateId)
          .get();
      return doc.exists ? CardTemplate.fromFirestore(doc) : null;
    } catch (e) {
      _logger.e('Failed to get template $templateId: $e');
      throw AppException('Failed to load template', code: 'get-template-failed');
    }
  }

  // Stream all templates owned by [userId], ordered newest first.
  Stream<List<CardTemplate>> watchUserTemplates(String userId) {
    return _firestore
        .collection(AppConstants.templatesCollection)
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(CardTemplate.fromFirestore).toList());
  }
}
