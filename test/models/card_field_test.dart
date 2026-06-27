import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/utils/constants.dart'; // fieldTypeTextInput, fieldTypeMultipleChoice
import 'package:test/test.dart';

void main() {
  // ── TextInputQuestion ──────────────────────────────────────────────────────

  group('TextInputQuestion', () {
    test('round-trips toJson / fromJson with answers, hint, and exactMatch', () {
      final q = TextInputQuestion(
        questionId: 'q1',
        prompt: 'Spell it',
        correctAnswers: ['casa', 'CASA'],
        hint: 'A building',
        exactMatch: true,
      );
      final restored = CardQuestion.fromJson(q.toJson()) as TextInputQuestion;
      expect(restored.questionId, equals('q1'));
      expect(restored.prompt, equals('Spell it'));
      expect(restored.correctAnswers, equals(['casa', 'CASA']));
      expect(restored.hint, equals('A building'));
      expect(restored.exactMatch, isTrue);
    });

    test('exactMatch defaults to false when absent from JSON', () {
      final q = TextInputQuestion(questionId: 'q1');
      final json = q.toJson();
      (json['content'] as Map).remove('exactMatch');
      final restored = CardQuestion.fromJson(json) as TextInputQuestion;
      expect(restored.exactMatch, isFalse);
    });

    test('null correctAnswers round-trips (template mode)', () {
      final q = TextInputQuestion(questionId: 'q1');
      final restored = CardQuestion.fromJson(q.toJson()) as TextInputQuestion;
      expect(restored.correctAnswers, isNull);
    });
  });

  // ── MultipleChoiceQuestion ─────────────────────────────────────────────────

  group('MultipleChoiceQuestion', () {
    test('round-trips with options, correctIndex, and explanation', () {
      final q = MultipleChoiceQuestion(
        questionId: 'q2',
        prompt: 'Gender',
        options: ['m', 'f', 'n'],
        correctIndex: 1,
        explanation: 'Feminine noun',
      );
      final restored = CardQuestion.fromJson(q.toJson()) as MultipleChoiceQuestion;
      expect(restored.questionId, equals('q2'));
      expect(restored.options, equals(['m', 'f', 'n']));
      expect(restored.correctIndex, equals(1));
      expect(restored.explanation, equals('Feminine noun'));
    });

    test('null correctIndex round-trips (template mode)', () {
      final q = MultipleChoiceQuestion(questionId: 'q2', options: ['m', 'f', 'n']);
      final restored = CardQuestion.fromJson(q.toJson()) as MultipleChoiceQuestion;
      expect(restored.correctIndex, isNull);
      expect(restored.options, equals(['m', 'f', 'n']));
    });

    test('null options round-trips', () {
      final q = MultipleChoiceQuestion(questionId: 'q2');
      final restored = CardQuestion.fromJson(q.toJson()) as MultipleChoiceQuestion;
      expect(restored.options, isNull);
      expect(restored.correctIndex, isNull);
    });
  });

  // ── WordOrderQuestion ──────────────────────────────────────────────────────

  group('WordOrderQuestion', () {
    test('round-trips with wordBank and correctOrder', () {
      final q = WordOrderQuestion(
        questionId: 'q3',
        prompt: 'Order the words',
        wordBank: ['el', 'gato', 'negro'],
        correctOrder: ['el', 'gato', 'negro'],
      );
      final restored = CardQuestion.fromJson(q.toJson()) as WordOrderQuestion;
      expect(restored.questionId, equals('q3'));
      expect(restored.prompt, equals('Order the words'));
      expect(restored.wordBank, equals(['el', 'gato', 'negro']));
      expect(restored.correctOrder, equals(['el', 'gato', 'negro']));
    });

    test('null wordBank and correctOrder round-trip (template mode)', () {
      final q = WordOrderQuestion(questionId: 'q3');
      final restored = CardQuestion.fromJson(q.toJson()) as WordOrderQuestion;
      expect(restored.wordBank, isNull);
      expect(restored.correctOrder, isNull);
    });
  });

  // ── FillInTheBlanksQuestion ───────────────────────────────────────────────

  group('FillInTheBlanksQuestion', () {
    test('round-trips sentence, tokens, blankCount, extraWords, mode', () {
      final q = FillInTheBlanksQuestion(
        questionId: 'q4',
        prompt: 'Complete the sentence',
        sentence: 'el gato es negro',
        tokens: const [
          FillBlankToken(word: 'el', eligible: false),
          FillBlankToken(word: 'gato', eligible: true),
          FillBlankToken(word: 'es', eligible: false),
          FillBlankToken(word: 'negro', eligible: true),
        ],
        blankCount: 2,
        extraWords: const ['perro', 'blanco'],
        completionMode: CompletionMode.textInput,
      );
      final restored =
          CardQuestion.fromJson(q.toJson()) as FillInTheBlanksQuestion;
      expect(restored.questionId, equals('q4'));
      expect(restored.prompt, equals('Complete the sentence'));
      expect(restored.sentence, equals('el gato es negro'));
      expect(restored.tokens!.length, equals(4));
      expect(restored.tokens![1].word, equals('gato'));
      expect(restored.tokens![1].eligible, isTrue);
      expect(restored.tokens![0].eligible, isFalse);
      expect(restored.blankCount, equals(2));
      expect(restored.extraWords, equals(['perro', 'blanco']));
      expect(restored.completionMode, equals(CompletionMode.textInput));
    });

    test('defaults: blankCount 1, empty extraWords, pill mode', () {
      final q = FillInTheBlanksQuestion(questionId: 'q4');
      final restored =
          CardQuestion.fromJson(q.toJson()) as FillInTheBlanksQuestion;
      expect(restored.blankCount, equals(1));
      expect(restored.extraWords, isEmpty);
      expect(restored.completionMode, equals(CompletionMode.pill));
    });

    test('null sentence and tokens round-trip (template mode)', () {
      final q = FillInTheBlanksQuestion(questionId: 'q4');
      final restored =
          CardQuestion.fromJson(q.toJson()) as FillInTheBlanksQuestion;
      expect(restored.sentence, isNull);
      expect(restored.tokens, isNull);
    });

    test('validate flags missing sentence and no eligible tokens', () {
      final q = FillInTheBlanksQuestion(
        questionId: 'q4',
        sentence: 'el gato',
        tokens: const [
          FillBlankToken(word: 'el', eligible: false),
          FillBlankToken(word: 'gato', eligible: false),
        ],
      );
      final errors = q.validate();
      expect(errors, contains('at least one word must be marked eligible to blank'));
    });

    test('validate flags blankCount exceeding eligible count', () {
      final q = FillInTheBlanksQuestion(
        questionId: 'q4',
        sentence: 'el gato',
        tokens: const [FillBlankToken(word: 'gato', eligible: true)],
        blankCount: 2,
      );
      expect(
        q.validate(),
        contains('blank count cannot exceed the number of eligible words'),
      );
    });

    test('validate passes in template mode regardless of content', () {
      final q = FillInTheBlanksQuestion(questionId: 'q4');
      expect(q.validate(isTemplate: true), isEmpty);
    });
  });

  // ── FillBlankToken.tokenize ───────────────────────────────────────────────

  group('FillBlankToken.tokenize', () {
    test('strips trailing sentence punctuation off the last word', () {
      final t = FillBlankToken.tokenize('The cat sat on the mat.');
      expect(t.map((e) => e.word).toList(),
          equals(['The', 'cat', 'sat', 'on', 'the', 'mat']));
      expect(t.last.trailing, equals('.'));
    });

    test('strips commas and other clause punctuation into trailing', () {
      final t = FillBlankToken.tokenize('Hello, world!');
      expect(t.map((e) => e.word).toList(), equals(['Hello', 'world']));
      expect(t[0].trailing, equals(','));
      expect(t[1].trailing, equals('!'));
    });

    test('keeps apostrophes in contractions', () {
      final t = FillBlankToken.tokenize("I don't know");
      expect(t.map((e) => e.word).toList(), equals(['I', "don't", 'know']));
      expect(t[1].trailing, isEmpty);
    });

    test('keeps hyphens in hyphenated words', () {
      final t = FillBlankToken.tokenize('a well-known fact');
      expect(t.map((e) => e.word).toList(), equals(['a', 'well-known', 'fact']));
    });

    test('captures leading punctuation (Spanish ¿) and trailing ?', () {
      final t = FillBlankToken.tokenize('¿Cómo estás?');
      expect(t.map((e) => e.word).toList(), equals(['Cómo', 'estás']));
      expect(t[0].leading, equals('¿'));
      expect(t[1].trailing, equals('?'));
    });

    test('all tokens start not-eligible', () {
      final t = FillBlankToken.tokenize('one two three');
      expect(t.every((e) => !e.eligible), isTrue);
    });

    test('a standalone all-punctuation dash is not a word token', () {
      final t = FillBlankToken.tokenize('He said -- stop');
      expect(t.map((e) => e.word).toList(), equals(['He', 'said', 'stop']));
      // The "--" folds into the preceding token rather than becoming a word.
      expect(t[1].trailing, contains('-'));
    });

    test('leading/trailing round-trip through json', () {
      const tok = FillBlankToken(
          word: 'estás', eligible: true, leading: '¿', trailing: '?');
      final restored = FillBlankToken.fromJson(tok.toJson());
      expect(restored.word, equals('estás'));
      expect(restored.eligible, isTrue);
      expect(restored.leading, equals('¿'));
      expect(restored.trailing, equals('?'));
    });

    test('empty affixes are omitted from json', () {
      const tok = FillBlankToken(word: 'cat', eligible: false);
      final json = tok.toJson();
      expect(json.containsKey('leading'), isFalse);
      expect(json.containsKey('trailing'), isFalse);
    });
  });

  // ── CompletionMode ────────────────────────────────────────────────────────

  group('CompletionMode', () {
    test('fromString maps textInput and defaults to pill', () {
      expect(CompletionMode.fromString('textInput'),
          equals(CompletionMode.textInput));
      expect(CompletionMode.fromString('pill'), equals(CompletionMode.pill));
      expect(CompletionMode.fromString(null), equals(CompletionMode.pill));
      expect(CompletionMode.fromString('garbage'), equals(CompletionMode.pill));
    });
  });

  // ── CardQuestion.fromJson dispatch ────────────────────────────────────────

  group('CardQuestion.fromJson dispatch', () {
    test('dispatches text_input to TextInputQuestion', () {
      expect(
        CardQuestion.fromJson(TextInputQuestion(questionId: 'q1').toJson()),
        isA<TextInputQuestion>(),
      );
    });

    test('dispatches multiple_choice to MultipleChoiceQuestion', () {
      expect(
        CardQuestion.fromJson(MultipleChoiceQuestion(questionId: 'q2').toJson()),
        isA<MultipleChoiceQuestion>(),
      );
    });

    test('dispatches word_order to WordOrderQuestion', () {
      expect(
        CardQuestion.fromJson(WordOrderQuestion(questionId: 'q3').toJson()),
        isA<WordOrderQuestion>(),
      );
    });

    test('dispatches fill_in_blanks to FillInTheBlanksQuestion', () {
      expect(
        CardQuestion.fromJson(
            FillInTheBlanksQuestion(questionId: 'q4').toJson()),
        isA<FillInTheBlanksQuestion>(),
      );
    });

    test('throws ArgumentError on unknown type', () {
      expect(
        () => CardQuestion.fromJson(<String, dynamic>{
          'questionId': 'q1',
          'type': 'unknown_type',
          'content': <String, dynamic>{},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

  });

  // ── Legacy CardField fieldId / name compat ────────────────────────────────

  group('legacy fieldId / name compat', () {
    test('reads fieldId as questionId and name as prompt', () {
      final json = {
        'fieldId': 'legacy-1',
        'name': 'Old field name',
        'type': AppConstants.fieldTypeTextInput,
        'content': {'correctAnswers': null, 'exactMatch': false},
      };
      final q = CardQuestion.fromJson(json) as TextInputQuestion;
      expect(q.questionId, equals('legacy-1'));
      expect(q.prompt, equals('Old field name'));
    });
  });
}