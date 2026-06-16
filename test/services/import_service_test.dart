import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/repositories/card_repository.dart';
import 'package:flash_me/repositories/card_set_repository.dart';
import 'package:flash_me/repositories/question_template_repository.dart';
import 'package:flash_me/repositories/template_repository.dart';
import 'package:flash_me/services/import_service.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'import_service_test.mocks.dart';

@GenerateMocks([CardSetRepository, CardRepository, QuestionTemplateRepository, TemplateRepository])
void main() {
  late MockCardSetRepository mockSetRepo;
  late MockCardRepository mockCardRepo;
  late MockQuestionTemplateRepository mockQtRepo;
  late MockTemplateRepository mockTemplateRepo;
  late ImportService service;
  final baseDate = DateTime(2024, 1, 15);

  setUp(() {
    mockSetRepo = MockCardSetRepository();
    mockCardRepo = MockCardRepository();
    mockQtRepo = MockQuestionTemplateRepository();
    mockTemplateRepo = MockTemplateRepository();
    service = ImportService();
    // Default stubs for template lookups called on every analyze().
    when(mockQtRepo.getUserTemplates(any))
        .thenAnswer((_) async => []);
    when(mockTemplateRepo.watchUserTemplates(any))
        .thenAnswer((_) => Stream.value([]));
  });

  // Encode a cards.json root map into a valid ZIP archive.
  Uint8List makeZip(Map<String, dynamic> root) {
    final jsonBytes = utf8.encode(jsonEncode(root));
    final archive = Archive()
      ..addFile(ArchiveFile('cards.json', jsonBytes.length, jsonBytes));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // Minimal valid raw card map for use in cards.json.
  Map<String, dynamic> rawCard({
    String primaryWord = 'hola',
    String translation = 'hello',
    List<Map<String, dynamic>>? fields,
    List<String>? tags,
  }) =>
      {
        'primaryWord': primaryWord,
        'translation': translation,
        'fields': fields ?? [],
        'tags': tags ?? [],
      };

  // Minimal set wrapper: {"sets": [{"name": name, "cards": cards}]}.
  Map<String, dynamic> singleSet(
    String name,
    List<Map<String, dynamic>> cards,
  ) =>
      {
        'sets': [
          {'name': name, 'cards': cards}
        ]
      };

  FlashCard existingCard({
    String id = 'card-1',
    String primaryWord = 'hola',
    String translation = 'hello',
    List<CardQuestion> questions = const [],
    List<String> tags = const [],
    bool primaryWordHidden = false,
    String? primaryImageUrl,
  }) =>
      FlashCard(
        id: id,
        primaryWord: primaryWord,
        translation: translation,
        primaryWordHidden: primaryWordHidden,
        primaryImageUrl: primaryImageUrl,
        questions: questions,
        tags: tags,
        createdAt: baseDate,
        updatedAt: baseDate,
        createdBy: 'user-1',
      );

  CardSet existingSet({String id = 'set-1', String name = 'Test Set'}) =>
      CardSet(
        id: id,
        userId: 'user-1',
        name: name,
        cardCount: 1,
        createdAt: baseDate,
        updatedAt: baseDate,
      );

  // ── _parseCard validation ──────────────────────────────────────────────────

  group('_parseCard validation', () {
    // Mocks are not called for parse errors — exception is thrown before repo access.

    test('throws AppException when primaryWord is empty', () async {
      final zip = makeZip(singleSet('Test Set', [rawCard(primaryWord: '')]));
      await expectLater(
        service.analyze(
          zipBytes: zip,
          userId: 'user-1',
          cardSetRepo: mockSetRepo,
          cardRepo: mockCardRepo,
          questionTemplateRepo: mockQtRepo,
          templateRepo: mockTemplateRepo,
        ),
        throwsA(isA<AppException>()
            .having((e) => e.message, 'message', contains('primaryWord'))),
      );
    });

    test('throws AppException when translation is empty', () async {
      final zip = makeZip(singleSet('Test Set', [rawCard(translation: '')]));
      await expectLater(
        service.analyze(
          zipBytes: zip,
          userId: 'user-1',
          cardSetRepo: mockSetRepo,
          cardRepo: mockCardRepo,
          questionTemplateRepo: mockQtRepo,
          templateRepo: mockTemplateRepo,
        ),
        throwsA(isA<AppException>()
            .having((e) => e.message, 'message', contains('translation'))),
      );
    });

    test('throws AppException when a field is missing required keys', () async {
      final zip = makeZip(singleSet('Test Set', [
        rawCard(fields: [
          {'type': 'reveal'}, // missing 'name' and 'content'
        ]),
      ]));
      await expectLater(
        service.analyze(
          zipBytes: zip,
          userId: 'user-1',
          cardSetRepo: mockSetRepo,
          cardRepo: mockCardRepo,
          questionTemplateRepo: mockQtRepo,
          templateRepo: mockTemplateRepo,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('throws AppException when set name is empty', () async {
      final zip = makeZip({'sets': [{'name': '', 'cards': <dynamic>[]}]});
      await expectLater(
        service.analyze(
          zipBytes: zip,
          userId: 'user-1',
          cardSetRepo: mockSetRepo,
          cardRepo: mockCardRepo,
          questionTemplateRepo: mockQtRepo,
          templateRepo: mockTemplateRepo,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('throws AppException for non-ZIP bytes', () async {
      await expectLater(
        service.analyze(
          zipBytes: Uint8List.fromList([0, 1, 2, 3]),
          userId: 'user-1',
          cardSetRepo: mockSetRepo,
          cardRepo: mockCardRepo,
          questionTemplateRepo: mockQtRepo,
          templateRepo: mockTemplateRepo,
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  // ── _buildChanges — diff detection ────────────────────────────────────────

  group('_buildChanges', () {
    test('detects translation change', () async {
      final set = existingSet();
      final card = existingCard(translation: 'hello');

      when(mockSetRepo.findSetByName('Test Set', 'user-1'))
          .thenAnswer((_) async => set);
      when(mockSetRepo.watchCardsInSet('set-1', 'user-1'))
          .thenAnswer((_) => Stream.value([card]));
      when(mockSetRepo.getSetsContainingCard('card-1', 'user-1'))
          .thenAnswer((_) async => [set]);

      final zip = makeZip(singleSet('Test Set', [rawCard(translation: 'hi')]));
      final analysis = await service.analyze(
        zipBytes: zip,
        userId: 'user-1',
        cardSetRepo: mockSetRepo,
        cardRepo: mockCardRepo,
        questionTemplateRepo: mockQtRepo,
        templateRepo: mockTemplateRepo,
      );

      final updated = analysis.setDiffs.first.updatedCards;
      expect(updated.length, equals(1));
      final translationChange =
          updated.first.changes.firstWhere((c) => c.label == 'translation');
      expect(translationChange.oldValue, equals('hello'));
      expect(translationChange.newValue, equals('hi'));
    });

    test('no changes when import card matches existing card exactly', () async {
      final set = existingSet();
      final card = existingCard();

      when(mockSetRepo.findSetByName('Test Set', 'user-1'))
          .thenAnswer((_) async => set);
      when(mockSetRepo.watchCardsInSet('set-1', 'user-1'))
          .thenAnswer((_) => Stream.value([card]));

      final zip = makeZip(singleSet('Test Set', [rawCard()]));
      final analysis = await service.analyze(
        zipBytes: zip,
        userId: 'user-1',
        cardSetRepo: mockSetRepo,
        cardRepo: mockCardRepo,
        questionTemplateRepo: mockQtRepo,
        templateRepo: mockTemplateRepo,
      );

      expect(analysis.setDiffs.first.updatedCards, isEmpty);
      expect(analysis.setDiffs.first.newCards, isEmpty);
    });

    test('detects tags change', () async {
      final set = existingSet();
      final card = existingCard(tags: ['verbs']);

      when(mockSetRepo.findSetByName('Test Set', 'user-1'))
          .thenAnswer((_) async => set);
      when(mockSetRepo.watchCardsInSet('set-1', 'user-1'))
          .thenAnswer((_) => Stream.value([card]));
      when(mockSetRepo.getSetsContainingCard('card-1', 'user-1'))
          .thenAnswer((_) async => []);

      final zip = makeZip(singleSet('Test Set', [
        rawCard(tags: ['verbs', 'beginner']),
      ]));
      final analysis = await service.analyze(
        zipBytes: zip,
        userId: 'user-1',
        cardSetRepo: mockSetRepo,
        cardRepo: mockCardRepo,
        questionTemplateRepo: mockQtRepo,
        templateRepo: mockTemplateRepo,
      );

      final updated = analysis.setDiffs.first.updatedCards;
      expect(updated.length, equals(1));
      expect(updated.first.changes.any((c) => c.label == 'tags'), isTrue);
    });

    test('detects word-visibility change', () async {
      final set = existingSet();
      final card = existingCard(primaryWordHidden: false);

      when(mockSetRepo.findSetByName('Test Set', 'user-1'))
          .thenAnswer((_) async => set);
      when(mockSetRepo.watchCardsInSet('set-1', 'user-1'))
          .thenAnswer((_) => Stream.value([card]));
      when(mockSetRepo.getSetsContainingCard('card-1', 'user-1'))
          .thenAnswer((_) async => []);

      final zip = makeZip(singleSet('Test Set', [
        {...rawCard(), 'primaryWordHidden': true},
      ]));
      final analysis = await service.analyze(
        zipBytes: zip,
        userId: 'user-1',
        cardSetRepo: mockSetRepo,
        cardRepo: mockCardRepo,
        questionTemplateRepo: mockQtRepo,
        templateRepo: mockTemplateRepo,
      );

      final updated = analysis.setDiffs.first.updatedCards;
      expect(updated.length, equals(1));
      expect(
          updated.first.changes.any((c) => c.label == 'word visibility'), isTrue);
    });
  });

  // ── New card routing ───────────────────────────────────────────────────────

  group('new card routing', () {
    test('adds to newCards when word is absent from set and library', () async {
      final set = existingSet();

      when(mockSetRepo.findSetByName('Test Set', 'user-1'))
          .thenAnswer((_) async => set);
      when(mockSetRepo.watchCardsInSet('set-1', 'user-1'))
          .thenAnswer((_) => Stream.value([])); // empty set
      when(mockCardRepo.findCardByWordAndTranslation('hola', 'hello', 'user-1'))
          .thenAnswer((_) async => null); // not in library

      final zip = makeZip(singleSet('Test Set', [rawCard()]));
      final analysis = await service.analyze(
        zipBytes: zip,
        userId: 'user-1',
        cardSetRepo: mockSetRepo,
        cardRepo: mockCardRepo,
        questionTemplateRepo: mockQtRepo,
        templateRepo: mockTemplateRepo,
      );

      expect(analysis.setDiffs.first.newCards.length, equals(1));
      expect(
          analysis.setDiffs.first.newCards.first.data.primaryWord, equals('hola'));
    });

    test('adds to libraryLinkCards when word+translation matches a library card', () async {
      final set = existingSet();
      final libraryCard = existingCard();

      when(mockSetRepo.findSetByName('Test Set', 'user-1'))
          .thenAnswer((_) async => set);
      when(mockSetRepo.watchCardsInSet('set-1', 'user-1'))
          .thenAnswer((_) => Stream.value([])); // not in this set
      when(mockCardRepo.findCardByWordAndTranslation('hola', 'hello', 'user-1'))
          .thenAnswer((_) async => libraryCard); // exists in library

      final zip = makeZip(singleSet('Test Set', [rawCard()]));
      final analysis = await service.analyze(
        zipBytes: zip,
        userId: 'user-1',
        cardSetRepo: mockSetRepo,
        cardRepo: mockCardRepo,
        questionTemplateRepo: mockQtRepo,
        templateRepo: mockTemplateRepo,
      );

      expect(analysis.setDiffs.first.libraryLinkCards.length, equals(1));
      expect(analysis.setDiffs.first.newCards, isEmpty);
    });
  });

  // ── _fieldsChanged detection ───────────────────────────────────────────────

  group('_fieldsChanged', () {
    test('detects changed field answer', () async {
      final set = existingSet();
      final card = existingCard(
        questions: [
          MultipleChoiceQuestion(
            questionId: 'q1',
            prompt: 'Gender',
            options: ['m', 'f'],
            correctIndex: 0,
          ),
        ],
      );

      when(mockSetRepo.findSetByName('Test Set', 'user-1'))
          .thenAnswer((_) async => set);
      when(mockSetRepo.watchCardsInSet('set-1', 'user-1'))
          .thenAnswer((_) => Stream.value([card]));
      when(mockSetRepo.getSetsContainingCard('card-1', 'user-1'))
          .thenAnswer((_) async => []);

      final zip = makeZip(singleSet('Test Set', [
        {
          'primaryWord': 'hola',
          'translation': 'hello',
          'tags': <dynamic>[],
          'fields': [
            {
              'name': 'Gender',
              'type': AppConstants.fieldTypeMultipleChoice,
              'content': {
                'options': ['m', 'f'],
                'correctIndex': 1, // changed from 0
                'explanation': null,
              },
            },
          ],
        },
      ]));

      final analysis = await service.analyze(
        zipBytes: zip,
        userId: 'user-1',
        cardSetRepo: mockSetRepo,
        cardRepo: mockCardRepo,
        questionTemplateRepo: mockQtRepo,
        templateRepo: mockTemplateRepo,
      );

      final updated = analysis.setDiffs.first.updatedCards;
      expect(updated.length, equals(1));
      expect(updated.first.changes.any((c) => c.label == 'Gender'), isTrue);
    });

    test('no change when field content is identical', () async {
      final set = existingSet();
      final card = existingCard(
        questions: [
          MultipleChoiceQuestion(
            questionId: 'q1',
            prompt: 'Gender',
            options: ['m', 'f'],
            correctIndex: 0,
          ),
        ],
      );

      when(mockSetRepo.findSetByName('Test Set', 'user-1'))
          .thenAnswer((_) async => set);
      when(mockSetRepo.watchCardsInSet('set-1', 'user-1'))
          .thenAnswer((_) => Stream.value([card]));
      when(mockSetRepo.getSetsContainingCard('card-1', 'user-1'))
          .thenAnswer((_) async => []);

      final zip = makeZip(singleSet('Test Set', [
        {
          'primaryWord': 'hola',
          'translation': 'hello',
          'tags': <dynamic>[],
          'fields': [
            {
              'name': 'Gender',
              'type': AppConstants.fieldTypeMultipleChoice,
              'content': {
                'options': ['m', 'f'],
                'correctIndex': 0, // same as existing
                'displayMode': 'list', // matches MultipleChoiceQuestion.toJson default
                'explanation': null,
              },
            },
          ],
        },
      ]));

      final analysis = await service.analyze(
        zipBytes: zip,
        userId: 'user-1',
        cardSetRepo: mockSetRepo,
        cardRepo: mockCardRepo,
        questionTemplateRepo: mockQtRepo,
        templateRepo: mockTemplateRepo,
      );

      expect(analysis.setDiffs.first.updatedCards, isEmpty);
    });
  });
}
