import 'package:flash_me/models/card_field.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:test/test.dart';

void main() {
  // ── RevealContent ──────────────────────────────────────────────────────────

  group('RevealContent', () {
    test('round-trips toJson / fromJson with an answer', () {
      const content = RevealContent(answer: 'Hola');
      final restored = RevealContent.fromJson(content.toJson());
      expect(restored.answer, equals('Hola'));
    });

    test('null answer round-trips (template mode)', () {
      const content = RevealContent();
      final json = content.toJson();
      expect(json['answer'], isNull);
      expect(RevealContent.fromJson(json).answer, isNull);
    });
  });

  // ── TextInputContent ───────────────────────────────────────────────────────

  group('TextInputContent', () {
    test('round-trips with correctAnswers, hint, and exactMatch', () {
      const content = TextInputContent(
        correctAnswers: ['hello', 'hi'],
        hint: 'A greeting',
        exactMatch: true,
      );
      final restored = TextInputContent.fromJson(content.toJson());
      expect(restored.correctAnswers, equals(['hello', 'hi']));
      expect(restored.hint, equals('A greeting'));
      expect(restored.exactMatch, isTrue);
    });

    test('exactMatch defaults to false when absent from JSON', () {
      final restored = TextInputContent.fromJson({'correctAnswers': null});
      expect(restored.exactMatch, isFalse);
    });

    test('null correctAnswers round-trips (template mode)', () {
      const content = TextInputContent();
      final json = content.toJson();
      expect(json['correctAnswers'], isNull);
      expect(TextInputContent.fromJson(json).correctAnswers, isNull);
    });
  });

  // ── MultipleChoiceContent ──────────────────────────────────────────────────

  group('MultipleChoiceContent', () {
    test('round-trips with options, correctIndex, and explanation', () {
      const content = MultipleChoiceContent(
        options: ['m', 'f', 'n'],
        correctIndex: 1,
        explanation: 'Feminine noun',
      );
      final restored = MultipleChoiceContent.fromJson(content.toJson());
      expect(restored.options, equals(['m', 'f', 'n']));
      expect(restored.correctIndex, equals(1));
      expect(restored.explanation, equals('Feminine noun'));
    });

    test('null correctIndex round-trips (template mode)', () {
      const content = MultipleChoiceContent(options: ['m', 'f', 'n']);
      final restored = MultipleChoiceContent.fromJson(content.toJson());
      expect(restored.correctIndex, isNull);
      expect(restored.options, equals(['m', 'f', 'n']));
    });

    test('null options round-trips', () {
      const content = MultipleChoiceContent();
      final restored = MultipleChoiceContent.fromJson(content.toJson());
      expect(restored.options, isNull);
      expect(restored.correctIndex, isNull);
    });
  });

  // ── CardFieldContent factory dispatch ─────────────────────────────────────

  group('CardFieldContent.fromJson dispatch', () {
    test('dispatches to RevealContent', () {
      final c = CardFieldContent.fromJson(AppConstants.fieldTypeReveal, {'answer': 'yes'});
      expect(c, isA<RevealContent>());
    });

    test('dispatches to TextInputContent', () {
      final c = CardFieldContent.fromJson(AppConstants.fieldTypeTextInput, {'correctAnswers': null});
      expect(c, isA<TextInputContent>());
    });

    test('dispatches to MultipleChoiceContent', () {
      final c = CardFieldContent.fromJson(
        AppConstants.fieldTypeMultipleChoice,
        {'options': null, 'correctIndex': null},
      );
      expect(c, isA<MultipleChoiceContent>());
    });

    test('throws ArgumentError on unknown type', () {
      expect(
        () => CardFieldContent.fromJson('unknown_type', {}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── CardField ──────────────────────────────────────────────────────────────

  group('CardField', () {
    test('fromJson / toJson round-trips for a multiple-choice field', () {
      final field = CardField(
        fieldId: 'f1',
        name: 'Gender',
        type: AppConstants.fieldTypeMultipleChoice,
        content: const MultipleChoiceContent(options: ['m', 'f'], correctIndex: 0),
      );
      final json = field.toJson();
      expect(json['fieldId'], equals('f1'));
      expect(json['name'], equals('Gender'));
      expect(json['type'], equals(AppConstants.fieldTypeMultipleChoice));

      final restored = CardField.fromJson(json);
      expect(restored.fieldId, equals('f1'));
      expect(restored.name, equals('Gender'));
      expect(restored.type, equals(AppConstants.fieldTypeMultipleChoice));
      final restoredContent = restored.content as MultipleChoiceContent;
      expect(restoredContent.options, equals(['m', 'f']));
      expect(restoredContent.correctIndex, equals(0));
    });

    test('fromJson / toJson round-trips for a reveal field', () {
      final field = CardField(
        fieldId: 'f2',
        name: 'Example',
        type: AppConstants.fieldTypeReveal,
        content: const RevealContent(answer: 'Un ejemplo'),
      );
      final restored = CardField.fromJson(field.toJson());
      expect(restored.fieldId, equals('f2'));
      expect((restored.content as RevealContent).answer, equals('Un ejemplo'));
    });

    test('fromJson / toJson round-trips for a text-input field', () {
      final field = CardField(
        fieldId: 'f3',
        name: 'Spelling',
        type: AppConstants.fieldTypeTextInput,
        content: const TextInputContent(
          correctAnswers: ['casa', 'CASA'],
          exactMatch: false,
        ),
      );
      final restored = CardField.fromJson(field.toJson());
      final restoredContent = restored.content as TextInputContent;
      expect(restoredContent.correctAnswers, equals(['casa', 'CASA']));
      expect(restoredContent.exactMatch, isFalse);
    });
  });
}
