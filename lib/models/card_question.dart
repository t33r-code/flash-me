import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/utils/constants.dart';

// ---------------------------------------------------------------------------
// MultipleChoiceDisplayMode — rendering hint stored on the question.
// Does not affect validation logic, only how options are drawn.
// ---------------------------------------------------------------------------
enum MultipleChoiceDisplayMode {
  list,  // full-width vertical buttons (default)
  chips; // compact wrapping chip row, best for short single-word options

  static MultipleChoiceDisplayMode fromString(String? s) =>
      s == 'chips' ? chips : list;
}

// ---------------------------------------------------------------------------
// CardQuestion — unified sealed hierarchy shared by FlashCards and WorkbookCards.
//
// Each subtype stores all data for one interactive question on a card.
// Answer fields (correctAnswers, options/correctIndex, wordBank/correctOrder)
// are nullable so templates can store structure and config without answers.
//
// Type strings (AppConstants):
//   text_input      → TextInputQuestion
//   multiple_choice → MultipleChoiceQuestion
//   word_order      → WordOrderQuestion
// ---------------------------------------------------------------------------
sealed class CardQuestion {
  final String questionId; // unique ID within the card; used as result tracking key
  final String? prompt;    // optional label shown above the question

  const CardQuestion({required this.questionId, this.prompt});

  // Reconstruct the correct subtype from a Firestore/JSON map.
  // Supports both the new format (questionId/prompt) and the legacy CardField
  // format (fieldId/name) to allow reading pre-migration flash card data.
  factory CardQuestion.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final content = json['content'] as Map<String, dynamic>? ?? {};
    // Accept both 'questionId' (new) and 'fieldId' (legacy CardField).
    final questionId =
        (json['questionId'] ?? json['fieldId']) as String? ?? '';
    // Accept both 'prompt' (new) and 'name' (legacy CardField).
    final prompt = (json['prompt'] ?? json['name']) as String?;

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
        // Unknown types (e.g. legacy 'reveal') are silently skipped by the
        // caller; returning a minimal placeholder here avoids a hard crash.
        throw ArgumentError('Unknown question type: $type');
    }
  }

  Map<String, dynamic> toJson();

  // Generate a new questionId using Firestore's local ID generator (no network call).
  static String generateId() =>
      FirebaseFirestore.instance.collection('_').doc().id;
}

// --- Text input question ---------------------------------------------------
// User types a free-text answer validated against correctAnswers.
class TextInputQuestion extends CardQuestion {
  final List<String>? correctAnswers; // null in templates
  final String? hint;                 // optional guidance shown during study
  final bool exactMatch;              // false = case-insensitive (default)

  const TextInputQuestion({
    required super.questionId,
    super.prompt,
    this.correctAnswers,
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
        correctAnswers: content['correctAnswers'] != null
            ? List<String>.from(content['correctAnswers'] as List)
            : null,
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
// User selects one option; displayMode controls how options are rendered.
class MultipleChoiceQuestion extends CardQuestion {
  final List<String>? options;   // CAN be pre-filled in templates
  final int? correctIndex;       // index into options; null in templates
  final MultipleChoiceDisplayMode displayMode;
  final String? explanation;     // shown after the user answers

  const MultipleChoiceQuestion({
    required super.questionId,
    super.prompt,
    this.options,
    this.correctIndex,
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
        options: content['options'] != null
            ? List<String>.from(content['options'] as List)
            : null,
        correctIndex: content['correctIndex'] as int?,
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
class WordOrderQuestion extends CardQuestion {
  final List<String>? wordBank;    // available tiles; null in templates
  final List<String>? correctOrder; // expected answer sequence; null in templates

  const WordOrderQuestion({
    required super.questionId,
    super.prompt,
    this.wordBank,
    this.correctOrder,
  });

  factory WordOrderQuestion.fromJson({
    required String questionId,
    String? prompt,
    required Map<String, dynamic> content,
  }) =>
      WordOrderQuestion(
        questionId: questionId,
        prompt: prompt,
        wordBank: content['wordBank'] != null
            ? List<String>.from(content['wordBank'] as List)
            : null,
        correctOrder: content['correctOrder'] != null
            ? List<String>.from(content['correctOrder'] as List)
            : null,
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
