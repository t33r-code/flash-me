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
// CompletionMode — how the user fills the gaps in a fill-in-the-blanks (#170)
// or complete-the-grid (#167) question. Shared by both types.
//   pill      → drag word pills from a pool into the empty slots
//   textInput → type the missing words into editable fields
// ---------------------------------------------------------------------------
enum CompletionMode {
  pill,
  textInput;

  static CompletionMode fromString(String? s) =>
      s == 'textInput' ? textInput : pill;

  String get asJson => name; // 'pill' | 'textInput'
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
//   fill_in_blanks  → FillInTheBlanksQuestion
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
      case AppConstants.questionTypeFillInBlanks:
        return FillInTheBlanksQuestion.fromJson(
            questionId: questionId, prompt: prompt, content: content);
      default:
        // Unknown types (e.g. legacy 'reveal') are silently skipped by the
        // caller; returning a minimal placeholder here avoids a hard crash.
        throw ArgumentError('Unknown question type: $type');
    }
  }

  Map<String, dynamic> toJson();

  // Returns validation errors for this question.
  // Pass isTemplate: true when validating templates — answer fields are nullable.
  List<String> validate({bool isTemplate = false});

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

  @override
  List<String> validate({bool isTemplate = false}) {
    if (isTemplate) return [];
    if (correctAnswers == null || correctAnswers!.isEmpty) {
      return ['text input question must have at least one correct answer'];
    }
    return [];
  }

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
  final bool randomizeOptions;   // shuffle option order each time shown in study

  const MultipleChoiceQuestion({
    required super.questionId,
    super.prompt,
    this.options,
    this.correctIndex,
    this.displayMode = MultipleChoiceDisplayMode.list,
    this.explanation,
    this.randomizeOptions = false,
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
        randomizeOptions: content['randomizeOptions'] as bool? ?? false,
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
          'randomizeOptions': randomizeOptions,
        },
      };

  @override
  List<String> validate({bool isTemplate = false}) {
    if (isTemplate) return [];
    final errors = <String>[];
    if (options == null || options!.length < 2) {
      errors.add('multiple choice question must have at least 2 options');
    }
    if (correctIndex == null) {
      errors.add('multiple choice question must have a correct answer selected');
    } else if (options != null && correctIndex! >= options!.length) {
      errors.add(
          'correct answer index $correctIndex is out of range (${options!.length} options)');
    }
    return errors;
  }

  MultipleChoiceQuestion copyWith({
    String? questionId,
    String? prompt,
    List<String>? options,
    int? correctIndex,
    MultipleChoiceDisplayMode? displayMode,
    String? explanation,
    bool? randomizeOptions,
  }) =>
      MultipleChoiceQuestion(
        questionId: questionId ?? this.questionId,
        prompt: prompt ?? this.prompt,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        displayMode: displayMode ?? this.displayMode,
        explanation: explanation ?? this.explanation,
        randomizeOptions: randomizeOptions ?? this.randomizeOptions,
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

  @override
  List<String> validate({bool isTemplate = false}) {
    if (isTemplate) return [];
    final errors = <String>[];
    if (wordBank == null || wordBank!.isEmpty) {
      errors.add('word order question must have a word bank');
    }
    if (correctOrder == null || correctOrder!.isEmpty) {
      errors.add('word order question must have a correct order');
    }
    if (wordBank != null && correctOrder != null) {
      final bankSet = wordBank!.toSet();
      for (final word in correctOrder!) {
        if (!bankSet.contains(word)) {
          errors.add('correct order contains "$word" which is not in the word bank');
        }
      }
    }
    return errors;
  }

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

// --- Fill-in-the-blanks question -------------------------------------------
// A sentence is tokenized into words; the author marks which words are
// eligible to be blanked. At display time `blankCount` eligible words are
// randomly hidden and the user fills them back in (pill drag-drop or text).
//
// QTI note: maps onto gapMatchInteraction — the blanked positions are "gaps"
// and the pill pool (blanked words + extraWords) are the "gapText" choices.

// One token of the tokenized sentence; preserves original word order.
// [word] is the clean, blankable/matchable word (no edge punctuation).
// [leading]/[trailing] hold formatting punctuation that hugs the word for
// display (e.g. '¿', '?', ','); they are never blanked and never matched.
class FillBlankToken {
  final String word;
  final bool eligible; // true = author allows this word to be blanked
  final String leading;  // formatting punctuation before the word, attached
  final String trailing; // formatting punctuation after the word, attached

  const FillBlankToken({
    required this.word,
    required this.eligible,
    this.leading = '',
    this.trailing = '',
  });

  factory FillBlankToken.fromJson(Map<String, dynamic> json) => FillBlankToken(
        word: json['word'] as String? ?? '',
        eligible: json['eligible'] as bool? ?? false,
        leading: json['leading'] as String? ?? '',
        trailing: json['trailing'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'eligible': eligible,
        // Omit empty affixes to keep stored docs lean and backward-compatible.
        if (leading.isNotEmpty) 'leading': leading,
        if (trailing.isNotEmpty) 'trailing': trailing,
      };

  FillBlankToken copyWith({String? word, bool? eligible, String? leading, String? trailing}) =>
      FillBlankToken(
        word: word ?? this.word,
        eligible: eligible ?? this.eligible,
        leading: leading ?? this.leading,
        trailing: trailing ?? this.trailing,
      );

  // Split a sentence into tokens on whitespace, stripping *formatting*
  // punctuation from each word's edges into leading/trailing while keeping
  // word-internal apostrophes (don't, l'eau) and hyphens (well-known).
  // Edge characters that are not letters/digits/apostrophes/hyphens are
  // treated as formatting punctuation. All tokens start not-eligible.
  static List<FillBlankToken> tokenize(String sentence) {
    final chunks = sentence
        .trim()
        .split(RegExp(r'\s+'))
        .where((c) => c.isNotEmpty);
    // Keep apostrophes (straight ' and curly ’) and hyphen-minus as part of
    // the word; strip everything else from the edges.
    final lead = RegExp(r"^[^\p{L}\p{N}'’-]+", unicode: true);
    final trail = RegExp(r"[^\p{L}\p{N}'’-]+$", unicode: true);
    final hasAlnum = RegExp(r'[\p{L}\p{N}]', unicode: true);

    final tokens = <FillBlankToken>[];
    var pendingLeading = ''; // punctuation from a pure-punctuation chunk
    for (final chunk in chunks) {
      final leadMatch = lead.firstMatch(chunk)?.group(0) ?? '';
      var rest = chunk.substring(leadMatch.length);
      final trailMatch = trail.firstMatch(rest)?.group(0) ?? '';
      var word = rest.substring(0, rest.length - trailMatch.length);

      // A "word" with no letters or digits (e.g. a "--" dash) is really
      // punctuation — fold the whole chunk into the affix stream.
      if (word.isNotEmpty && !hasAlnum.hasMatch(word)) {
        word = '';
      }

      if (word.isEmpty) {
        // Whole chunk was punctuation: attach to the previous token's trailing,
        // or buffer it as leading for the next word. Use the full chunk so a
        // reclassified all-punctuation "word" (e.g. "--") isn't dropped.
        final punct = chunk;
        if (tokens.isNotEmpty) {
          final prev = tokens.removeLast();
          tokens.add(FillBlankToken(
            word: prev.word,
            eligible: prev.eligible,
            leading: prev.leading,
            trailing: prev.trailing + punct,
          ));
        } else {
          pendingLeading += punct;
        }
        continue;
      }

      tokens.add(FillBlankToken(
        word: word,
        eligible: false,
        leading: pendingLeading + leadMatch,
        trailing: trailMatch,
      ));
      pendingLeading = '';
    }
    return tokens;
  }
}

class FillInTheBlanksQuestion extends CardQuestion {
  final String? sentence;            // complete original sentence; null in templates
  final List<FillBlankToken>? tokens; // tokenized sentence; null in templates
  final int blankCount;              // eligible words to hide per display
  final List<String> extraWords;     // author-added distractor words for the pool
  final CompletionMode completionMode;

  const FillInTheBlanksQuestion({
    required super.questionId,
    super.prompt,
    this.sentence,
    this.tokens,
    this.blankCount = 1,
    this.extraWords = const [],
    this.completionMode = CompletionMode.pill,
  });

  factory FillInTheBlanksQuestion.fromJson({
    required String questionId,
    String? prompt,
    required Map<String, dynamic> content,
  }) =>
      FillInTheBlanksQuestion(
        questionId: questionId,
        prompt: prompt,
        sentence: content['sentence'] as String?,
        tokens: content['tokens'] != null
            ? (content['tokens'] as List)
                .map((t) => FillBlankToken.fromJson(t as Map<String, dynamic>))
                .toList()
            : null,
        blankCount: content['blankCount'] as int? ?? 1,
        extraWords: content['extraWords'] != null
            ? List<String>.from(content['extraWords'] as List)
            : const [],
        completionMode:
            CompletionMode.fromString(content['completionMode'] as String?),
      );

  @override
  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'type': AppConstants.questionTypeFillInBlanks,
        'prompt': prompt,
        'content': {
          'sentence': sentence,
          'tokens': tokens?.map((t) => t.toJson()).toList(),
          'blankCount': blankCount,
          'extraWords': extraWords,
          'completionMode': completionMode.asJson,
        },
      };

  @override
  List<String> validate({bool isTemplate = false}) {
    if (isTemplate) return [];
    final errors = <String>[];
    if (sentence == null || sentence!.trim().isEmpty) {
      errors.add('fill-in-the-blanks question must have a sentence');
    }
    if (tokens == null || tokens!.isEmpty) {
      errors.add('fill-in-the-blanks question must be tokenized');
      return errors; // remaining checks need tokens
    }
    final eligibleCount = tokens!.where((t) => t.eligible).length;
    if (eligibleCount == 0) {
      errors.add('at least one word must be marked eligible to blank');
    }
    if (blankCount < 1) {
      errors.add('blank count must be at least 1');
    }
    if (blankCount > eligibleCount) {
      errors.add('blank count cannot exceed the number of eligible words');
    }
    return errors;
  }

  FillInTheBlanksQuestion copyWith({
    String? questionId,
    String? prompt,
    String? sentence,
    List<FillBlankToken>? tokens,
    int? blankCount,
    List<String>? extraWords,
    CompletionMode? completionMode,
  }) =>
      FillInTheBlanksQuestion(
        questionId: questionId ?? this.questionId,
        prompt: prompt ?? this.prompt,
        sentence: sentence ?? this.sentence,
        tokens: tokens ?? this.tokens,
        blankCount: blankCount ?? this.blankCount,
        extraWords: extraWords ?? this.extraWords,
        completionMode: completionMode ?? this.completionMode,
      );
}
