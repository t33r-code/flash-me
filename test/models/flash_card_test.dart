import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:test/test.dart';

void main() {
  final baseDate = DateTime(2024, 1, 15);

  // Minimal valid card for tests that don't need specific question values.
  FlashCard makeCard() => FlashCard(
        id: 'card-1',
        primaryWord: 'hola',
        translation: 'hello',
        questions: [],
        createdAt: baseDate,
        updatedAt: baseDate,
        createdBy: 'user-1',
      );

  // ── toJson ─────────────────────────────────────────────────────────────────

  group('FlashCard.toJson', () {
    test('includes all required fields', () {
      final json = makeCard().toJson();
      expect(json['id'], equals('card-1'));
      expect(json['primaryWord'], equals('hola'));
      expect(json['translation'], equals('hello'));
      expect(json['createdBy'], equals('user-1'));
      expect(json['questions'], isEmpty);
      expect(json['tags'], isEmpty);
    });

    test('primaryWordHidden defaults to false', () {
      expect(makeCard().toJson()['primaryWordHidden'], isFalse);
    });

    test('serializes optional string fields when set', () {
      final card = makeCard().copyWith(
        primaryImageUrl: 'https://example.com/img.png',
        primaryAudioUrl: 'https://example.com/audio.mp3',
        nativeLanguage: 'en',
        targetLanguage: 'es',
        templateId: 'tmpl-1',
      );
      final json = card.toJson();
      expect(json['primaryImageUrl'], equals('https://example.com/img.png'));
      expect(json['primaryAudioUrl'], equals('https://example.com/audio.mp3'));
      expect(json['nativeLanguage'], equals('en'));
      expect(json['targetLanguage'], equals('es'));
      expect(json['templateId'], equals('tmpl-1'));
    });

    test('serializes optional fields as null when absent', () {
      final json = makeCard().toJson();
      expect(json['primaryImageUrl'], isNull);
      expect(json['primaryAudioUrl'], isNull);
      expect(json['nativeLanguage'], isNull);
      expect(json['targetLanguage'], isNull);
      expect(json['templateId'], isNull);
    });

    test('serializes tags list', () {
      final card = makeCard().copyWith(tags: ['verbs', 'beginner']);
      expect(card.toJson()['tags'], equals(['verbs', 'beginner']));
    });

    test('serializes dates as ISO 8601 strings', () {
      final json = makeCard().toJson();
      expect(json['createdAt'], equals(baseDate.toIso8601String()));
      expect(json['updatedAt'], equals(baseDate.toIso8601String()));
    });

    test('serializes nested CardQuestion list', () {
      final question = TextInputQuestion(
        questionId: 'q1',
        prompt: 'Pronunciation',
        correctAnswers: ['oh-lah'],
      );
      final json = makeCard().copyWith(questions: [question]).toJson();
      final questionsList = json['questions'] as List;
      expect(questionsList.length, equals(1));
      expect(questionsList[0]['prompt'], equals('Pronunciation'));
      expect(
        (questionsList[0]['content'] as Map)['correctAnswers'],
        equals(['oh-lah']),
      );
    });
  });

  // ── copyWith ───────────────────────────────────────────────────────────────

  group('FlashCard.copyWith', () {
    test('returns a new instance with only specified fields changed', () {
      final original = makeCard().copyWith(tags: ['verbs']);
      final updated = original.copyWith(translation: 'greetings', tags: ['nouns']);

      expect(updated.translation, equals('greetings'));
      expect(updated.tags, equals(['nouns']));
      // Unchanged fields carry over.
      expect(updated.id, equals(original.id));
      expect(updated.primaryWord, equals(original.primaryWord));
      expect(updated.createdBy, equals(original.createdBy));
      expect(updated.createdAt, equals(original.createdAt));
    });

    test('does not mutate the original', () {
      final original = makeCard();
      original.copyWith(primaryWord: 'adios');
      expect(original.primaryWord, equals('hola'));
    });
  });
}