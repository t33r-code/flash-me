import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/utils/constants.dart';

// ---------------------------------------------------------------------------
// MultipleChoiceDisplayMode — rendering hint stored on the question.
// Does not affect validation logic, only how options are drawn.
// ---------------------------------------------------------------------------
enum MultipleChoiceDisplayMode {
  list,  // full-width vertical buttons (default)
  chips; // compact wrapping chip row, best for short single-word options

  // Deserialise from the stored string; unknown values fall back to list.
  static MultipleChoiceDisplayMode fromString(String? s) =>
      s == 'chips' ? chips : list;
}

// ---------------------------------------------------------------------------
// WorkbookQuestion — sealed hierarchy, one entry per question on a card.
//
// Same pattern as CardFieldContent: adding a new question type requires only
// a new subclass + updated fromJson/toJson; all switch sites get a compile
// error if a case is missing.
//
// Type strings reuse fieldType* constants where the semantics match:
//   text_input      → TextInputQuestion
//   multiple_choice → MultipleChoiceQuestion
// A new constant covers the new type:
//   word_order      → WordOrderQuestion
// ---------------------------------------------------------------------------
sealed class WorkbookQuestion {
  final String questionId;
  final String? prompt; // optional per-question label / instruction

  const WorkbookQuestion({required this.questionId, this.prompt});

  // Reconstruct the correct subtype from a Firestore/JSON map.
  factory WorkbookQuestion.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final content = json['content'] as Map<String, dynamic>;
    final questionId = json['questionId'] as String;
    final prompt = json['prompt'] as String?;
    switch (type) {
      case AppConstants.fieldTypeTextInput:
        return TextInputQuestion.fromJson(
            questionId: questionId, prompt: prompt, content: content);
      case AppConstants.fieldTypeMultipleChoice:
        return MultipleChoiceQuestion.fromJson(
            questionId: questionId, prompt: prompt, content: content);
      case AppConstants.questionTypeWordOrder:
        return WordOrderQuestion.fromJson(
            questionId: questionId, prompt: prompt, content: content);
      default:
        throw ArgumentError('Unknown workbook question type: $type');
    }
  }

  Map<String, dynamic> toJson();

  // Generate a new questionId using Firestore's local ID generator (no network call).
  static String generateId() =>
      FirebaseFirestore.instance.collection('_').doc().id;
}

// --- Text input question ---------------------------------------------------
// User types a free-text answer validated against correctAnswers.
class TextInputQuestion extends WorkbookQuestion {
  final List<String> correctAnswers;
  final String? hint;
  final bool exactMatch; // false = case-insensitive (default)

  const TextInputQuestion({
    required super.questionId,
    super.prompt,
    required this.correctAnswers,
    this.hint,
    this.exactMatch = false,
  });

  factory TextInputQuestion.fromJson({
    required String questionId,
    String? prompt,
    required Map<String, dynamic> content,
  }) =>
      TextInputQuestion(
        questionId: questionId,
        prompt: prompt,
        correctAnswers:
            List<String>.from(content['correctAnswers'] as List? ?? []),
        hint: content['hint'] as String?,
        exactMatch: content['exactMatch'] as bool? ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'type': AppConstants.fieldTypeTextInput,
        'prompt': prompt,
        'content': {
          'correctAnswers': correctAnswers,
          'hint': hint,
          'exactMatch': exactMatch,
        },
      };

  TextInputQuestion copyWith({
    String? questionId,
    String? prompt,
    List<String>? correctAnswers,
    String? hint,
    bool? exactMatch,
  }) =>
      TextInputQuestion(
        questionId: questionId ?? this.questionId,
        prompt: prompt ?? this.prompt,
        correctAnswers: correctAnswers ?? this.correctAnswers,
        hint: hint ?? this.hint,
        exactMatch: exactMatch ?? this.exactMatch,
      );
}

// --- Multiple choice question ----------------------------------------------
// User selects one option from a list; displayMode controls rendering.
class MultipleChoiceQuestion extends WorkbookQuestion {
  final List<String> options;
  final int correctIndex;
  final MultipleChoiceDisplayMode displayMode;
  final String? explanation; // shown after the user answers

  const MultipleChoiceQuestion({
    required super.questionId,
    super.prompt,
    required this.options,
    required this.correctIndex,
    this.displayMode = MultipleChoiceDisplayMode.list,
    this.explanation,
  });

  factory MultipleChoiceQuestion.fromJson({
    required String questionId,
    String? prompt,
    required Map<String, dynamic> content,
  }) =>
      MultipleChoiceQuestion(
        questionId: questionId,
        prompt: prompt,
        options: List<String>.from(content['options'] as List? ?? []),
        correctIndex: content['correctIndex'] as int? ?? 0,
        displayMode: MultipleChoiceDisplayMode.fromString(
            content['displayMode'] as String?),
        explanation: content['explanation'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'type': AppConstants.fieldTypeMultipleChoice,
        'prompt': prompt,
        'content': {
          'options': options,
          'correctIndex': correctIndex,
          'displayMode': displayMode.name,
          'explanation': explanation,
        },
      };

  MultipleChoiceQuestion copyWith({
    String? questionId,
    String? prompt,
    List<String>? options,
    int? correctIndex,
    MultipleChoiceDisplayMode? displayMode,
    String? explanation,
  }) =>
      MultipleChoiceQuestion(
        questionId: questionId ?? this.questionId,
        prompt: prompt ?? this.prompt,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        displayMode: displayMode ?? this.displayMode,
        explanation: explanation ?? this.explanation,
      );
}

// --- Word order question ---------------------------------------------------
// User assembles an answer by tapping tiles from wordBank into an answer row.
// correctOrder is an ordered subset of (or equal to) wordBank.
class WordOrderQuestion extends WorkbookQuestion {
  // All available word tiles — correct words plus optional distractors.
  final List<String> wordBank;
  // The expected answer: an ordered list of words from wordBank.
  final List<String> correctOrder;

  const WordOrderQuestion({
    required super.questionId,
    super.prompt,
    required this.wordBank,
    required this.correctOrder,
  });

  factory WordOrderQuestion.fromJson({
    required String questionId,
    String? prompt,
    required Map<String, dynamic> content,
  }) =>
      WordOrderQuestion(
        questionId: questionId,
        prompt: prompt,
        wordBank: List<String>.from(content['wordBank'] as List? ?? []),
        correctOrder:
            List<String>.from(content['correctOrder'] as List? ?? []),
      );

  @override
  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'type': AppConstants.questionTypeWordOrder,
        'prompt': prompt,
        'content': {
          'wordBank': wordBank,
          'correctOrder': correctOrder,
        },
      };

  WordOrderQuestion copyWith({
    String? questionId,
    String? prompt,
    List<String>? wordBank,
    List<String>? correctOrder,
  }) =>
      WordOrderQuestion(
        questionId: questionId ?? this.questionId,
        prompt: prompt ?? this.prompt,
        wordBank: wordBank ?? this.wordBank,
        correctOrder: correctOrder ?? this.correctOrder,
      );
}

// ---------------------------------------------------------------------------
// WorkbookCard — a prompt block followed by one or more structured questions.
// Stored in workbookCards/{cardId}; separate collection from cards/.
// ---------------------------------------------------------------------------
class WorkbookCard {
  final String id; // Firestore document ID
  // Task description shown before the questions expand (e.g. "Read and answer").
  final String prompt;
  final List<WorkbookQuestion> questions;
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
          .map((q) => WorkbookQuestion.fromJson(q as Map<String, dynamic>))
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

  // Plain JSON serialisation (for future export support).
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
    List<WorkbookQuestion>? questions,
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
