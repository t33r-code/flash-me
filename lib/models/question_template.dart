import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/card_question.dart';

// Prefix used in import JSON to signal a question-template reference.
// e.g. {"template": "##gender", "correctIndex": 2}
const String kTemplateIdPrefix = '##';

// A reusable single-question template stored in questionTemplates/{id}.
// Stores question structure and config; answer fields are always null
// (correctAnswers, correctIndex, correctOrder) — the user fills those in per card.
class QuestionTemplate {
  final String id;
  final String createdBy;
  final String name;
  final String? description;
  final CardQuestion question; // structure only, no answer
  // Optional user-defined slug for referencing this template in import files.
  // Format in JSON: "##<templateId>" (e.g. "##gender"). Must be unique per user.
  final String? templateId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QuestionTemplate({
    required this.id,
    required this.createdBy,
    required this.name,
    this.description,
    required this.question,
    this.templateId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuestionTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionTemplate(
      id: doc.id,
      createdBy: data['createdBy'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      question: CardQuestion.fromJson(data['question'] as Map<String, dynamic>),
      templateId: data['templateId'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'createdBy': createdBy,
        'name': name,
        'description': description,
        'question': question.toJson(),
        'templateId': templateId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  QuestionTemplate copyWith({
    String? name,
    String? description,
    CardQuestion? question,
    Object? templateId = _sentinel,
    DateTime? updatedAt,
  }) =>
      QuestionTemplate(
        id: id,
        createdBy: createdBy,
        name: name ?? this.name,
        description: description ?? this.description,
        question: question ?? this.question,
        // Use sentinel so callers can explicitly pass null to clear templateId.
        templateId: templateId == _sentinel
            ? this.templateId
            : templateId as String?,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// Sentinel value used by copyWith to distinguish "not passed" from null.
const Object _sentinel = Object();
