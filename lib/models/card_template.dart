import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/card_question.dart';

// A reusable question layout stored in Firestore under templates/{templateId}.
//
// Templates use the same CardQuestion model as cards, but answer fields are
// nullable. For example, a "Gender" multiple choice template question stores the
// options list but leaves correctIndex null — the user fills that in per card.
class CardTemplate {
  final String id; // Firestore document ID
  final String createdBy; // uid of the owning user
  final String name; // e.g. "Spanish Verb"
  final String? description;
  // Questions with the same structure as FlashCard.questions; answers are nullable.
  // Stored as 'questions' in Firestore; legacy docs may use 'fields' (handled in fromFirestore).
  final List<CardQuestion> questions;
  // Whether the primary word should be hidden on first display when media is present.
  final bool primaryWordHidden;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CardTemplate({
    required this.id,
    required this.createdBy,
    required this.name,
    this.description,
    required this.questions,
    this.primaryWordHidden = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Reads 'questions' first; falls back to legacy 'fields' key for pre-migration docs.
  // Unknown question types (e.g. legacy 'reveal') are silently dropped.
  factory CardTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawQuestions =
        (data['questions'] ?? data['fields']) as List<dynamic>? ?? [];
    final questions = rawQuestions
        .map((q) {
          try {
            return CardQuestion.fromJson(q as Map<String, dynamic>);
          } on ArgumentError {
            return null; // skip unsupported types (e.g. legacy 'reveal')
          }
        })
        .whereType<CardQuestion>()
        .toList();

    return CardTemplate(
      id: doc.id,
      createdBy: data['createdBy'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      questions: questions,
      primaryWordHidden: data['primaryWordHidden'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'createdBy': createdBy,
        'name': name,
        'description': description,
        'questions': questions.map((q) => q.toJson()).toList(),
        'primaryWordHidden': primaryWordHidden,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdBy': createdBy,
        'name': name,
        'description': description,
        'questions': questions.map((q) => q.toJson()).toList(),
        'primaryWordHidden': primaryWordHidden,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  CardTemplate copyWith({
    String? id,
    String? createdBy,
    String? name,
    String? description,
    List<CardQuestion>? questions,
    bool? primaryWordHidden,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CardTemplate(
        id: id ?? this.id,
        createdBy: createdBy ?? this.createdBy,
        name: name ?? this.name,
        description: description ?? this.description,
        questions: questions ?? this.questions,
        primaryWordHidden: primaryWordHidden ?? this.primaryWordHidden,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
