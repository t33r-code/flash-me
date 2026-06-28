import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/models/card_question.dart';

// Re-export so callers that previously imported question types from here
// can continue to resolve them without an immediate import change.
export 'package:flash_me/models/card_question.dart'
    show
        CardQuestion,
        TextInputQuestion,
        MultipleChoiceQuestion,
        WordOrderQuestion,
        FillInTheBlanksQuestion,
        FillBlankToken,
        GridQuestion,
        CompletionMode,
        MultipleChoiceDisplayMode;

// ---------------------------------------------------------------------------
// WorkbookCard — a prompt block followed by one or more structured questions.
// Stored in workbookCards/{cardId}; separate collection from cards/.
// ---------------------------------------------------------------------------
class WorkbookCard {
  final String id; // Firestore document ID
  // Task description shown before the questions expand (e.g. "Read and answer").
  final String prompt;
  final List<CardQuestion> questions;
  final List<String> tags;
  final String? nativeLanguage; // ISO 639-1 code
  final String? targetLanguage; // ISO 639-1 code
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy; // uid of the owning user

  const WorkbookCard({
    required this.id,
    required this.prompt,
    required this.questions,
    this.tags = const [],
    this.nativeLanguage,
    this.targetLanguage,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory WorkbookCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkbookCard(
      id: doc.id,
      prompt: data['prompt'] as String? ?? '',
      questions: (data['questions'] as List<dynamic>? ?? [])
          .map((q) => CardQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      tags: List<String>.from(data['tags'] as List? ?? []),
      nativeLanguage: data['nativeLanguage'] as String?,
      targetLanguage: data['targetLanguage'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'prompt': prompt,
        'questions': questions.map((q) => q.toJson()).toList(),
        'tags': tags,
        'nativeLanguage': nativeLanguage,
        'targetLanguage': targetLanguage,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdBy': createdBy,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'questions': questions.map((q) => q.toJson()).toList(),
        'tags': tags,
        'nativeLanguage': nativeLanguage,
        'targetLanguage': targetLanguage,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
      };

  WorkbookCard copyWith({
    String? id,
    String? prompt,
    List<CardQuestion>? questions,
    List<String>? tags,
    String? nativeLanguage,
    String? targetLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) =>
      WorkbookCard(
        id: id ?? this.id,
        prompt: prompt ?? this.prompt,
        questions: questions ?? this.questions,
        tags: tags ?? this.tags,
        nativeLanguage: nativeLanguage ?? this.nativeLanguage,
        targetLanguage: targetLanguage ?? this.targetLanguage,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
      );
}
