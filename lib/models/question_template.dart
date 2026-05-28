import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/card_question.dart';

// A reusable single-question template stored in questionTemplates/{id}.
// Stores question structure and config; answer fields are always null
// (correctAnswers, correctIndex, correctOrder) — the user fills those in per card.
class QuestionTemplate {
  final String id;
  final String createdBy;
  final String name;
  final String? description;
  final CardQuestion question; // structure only, no answer
  final DateTime createdAt;
  final DateTime updatedAt;

  const QuestionTemplate({
    required this.id,
    required this.createdBy,
    required this.name,
    this.description,
    required this.question,
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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'createdBy': createdBy,
        'name': name,
        'description': description,
        'question': question.toJson(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  QuestionTemplate copyWith({
    String? name,
    String? description,
    CardQuestion? question,
    DateTime? updatedAt,
  }) =>
      QuestionTemplate(
        id: id,
        createdBy: createdBy,
        name: name ?? this.name,
        description: description ?? this.description,
        question: question ?? this.question,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
