import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/import_diff.dart';
import 'package:flash_me/repositories/card_repository.dart';
import 'package:flash_me/repositories/card_set_repository.dart';
import 'package:flash_me/repositories/question_template_repository.dart';
import 'package:flash_me/repositories/template_repository.dart';
import 'package:flash_me/services/import_service.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';
import 'package:flash_me/utils/import_media_validation.dart';
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
    return Uint8List.fromList(ZipEncoder().encode(archive));
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

  // ── Archive size guards (#298) ────────────────────────────────────────────

  group('archive size guards', () {
    Future<void> expectRejectedAsOversized(Uint8List bytes) => expectLater(
          service.analyze(
            zipBytes: bytes,
            userId: 'user-1',
            cardSetRepo: mockSetRepo,
            cardRepo: mockCardRepo,
            questionTemplateRepo: mockQtRepo,
            templateRepo: mockTemplateRepo,
          ),
          // Asserting on the message, not just the type: the raw-size check
          // sits next to a catch that reports 'Not a valid ZIP file.', and
          // these inputs would satisfy isA<AppException>() either way.
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              contains('50 MB'),
            ),
          ),
        );

    test('rejects a raw archive larger than the limit', () async {
      // Junk bytes rather than a real ZIP: proves the raw-size guard runs
      // *before* decoding, since a decode attempt would fail differently.
      await expectRejectedAsOversized(
        Uint8List(AppConstants.maxImportArchiveBytes + 1),
      );
    });

    test('rejects a zip bomb that inflates past the limit', () async {
      // Zeros compress to almost nothing, so this lands well under the raw cap
      // while declaring >50 MB uncompressed — exactly the case the old
      // `archive.length` (entry count) check could never catch.
      final payload =
          Uint8List(AppConstants.maxImportArchiveBytes + 1024 * 1024);
      final archive = Archive()
        ..addFile(ArchiveFile('cards.json', payload.length, payload));
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      expect(
        zipBytes.length,
        lessThan(AppConstants.maxImportArchiveBytes),
        reason: 'compressed size must stay under the raw cap, or this would '
            'test the raw guard instead of the inflated-size guard',
      );
      await expectRejectedAsOversized(zipBytes);
    });

    test('rejects a zip bomb that understates its declared size (#331)',
        () async {
      // The declared-sum guard trusts the header, which a bomb can fake:
      // encode a valid archive, then patch the central directory's
      // uncompressed-size field down to 1 byte. ZipDecoder prefers the
      // central-directory sizes, so the declared sum becomes 1 while the
      // deflate stream still inflates well past the cap. Only the measured
      // inflated-size guard can catch this.
      final payload =
          Uint8List(AppConstants.maxImportArchiveBytes + 1024 * 1024);
      final archive = Archive()
        ..addFile(ArchiveFile('cards.json', payload.length, payload));
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      // Central directory file header: signature PK\x01\x02, with the
      // uncompressed-size field at byte offset 24.
      var patched = 0;
      for (var i = 0; i + 28 <= zipBytes.length; i++) {
        if (zipBytes[i] == 0x50 &&
            zipBytes[i + 1] == 0x4b &&
            zipBytes[i + 2] == 0x01 &&
            zipBytes[i + 3] == 0x02) {
          zipBytes[i + 24] = 1;
          zipBytes[i + 25] = 0;
          zipBytes[i + 26] = 0;
          zipBytes[i + 27] = 0;
          patched++;
        }
      }
      expect(patched, 1,
          reason: 'expected exactly 1 central-directory entry to patch');

      final declared =
          ZipDecoder().decodeBytes(zipBytes).files.fold<int>(0, (s, f) => s + f.size);
      expect(
        declared,
        lessThan(AppConstants.maxImportArchiveBytes),
        reason: 'declared sizes must pass the #298 sum guard, or this would '
            'test that guard instead of the inflated-size guard',
      );
      await expectRejectedAsOversized(zipBytes);
    });
  });

  // ── Malformed-but-valid JSON (#300 F3) ────────────────────────────────────

  group('malformed JSON shapes', () {
    Future<void> expectFriendlyError(
      Map<String, dynamic> root,
      String expectedFragment,
    ) =>
        expectLater(
          service.analyze(
            zipBytes: makeZip(root),
            userId: 'user-1',
            cardSetRepo: mockSetRepo,
            cardRepo: mockCardRepo,
            questionTemplateRepo: mockQtRepo,
            templateRepo: mockTemplateRepo,
          ),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              contains(expectedFragment),
            ),
          ),
        );

    test('"sets" that is not a list', () async {
      await expectFriendlyError({'sets': 'x'}, 'must be a list');
    });

    test('"set" that is not an object', () async {
      await expectFriendlyError({'set': 'x'}, 'must be an object');
    });

    test('"sets" containing a non-object entry', () async {
      await expectFriendlyError({
        'sets': ['x'],
      }, 'not an object');
    });

    test('"cards" that is not a list', () async {
      await expectFriendlyError({
        'set': {'name': 'S', 'cards': 'x'},
      }, 'must be a list');
    });

    // Exercises the TypeError safety net rather than an explicit check: `tags`
    // is cast deep inside _parseCard, well past the structural validation.
    test('a wrong-typed field deep inside a card', () async {
      await expectFriendlyError({
        'set': {
          'name': 'S',
          'cards': [
            {'primaryWord': 'a', 'translation': 'b', 'tags': 'oops'},
          ],
        },
      }, 'unexpected data types');
    });
  });

  // ── Media validated during analyze (#330) ─────────────────────────────────

  group('media issues reported by analyze', () {
    // Build a ZIP containing cards.json plus one media entry of [mediaBytes].
    Uint8List makeZipWithMedia(
      Map<String, dynamic> root,
      String mediaPath,
      int mediaBytes,
    ) {
      final jsonBytes = utf8.encode(jsonEncode(root));
      final media = Uint8List(mediaBytes);
      final archive = Archive()
        ..addFile(ArchiveFile('cards.json', jsonBytes.length, jsonBytes))
        ..addFile(ArchiveFile(mediaPath, media.length, media));
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    Map<String, dynamic> cardWithImage(String path) => {
          ...rawCard(),
          'primaryImageUrl': path,
        };

    Future<ImportAnalysis> analyzeWith(Uint8List zipBytes) => service.analyze(
          zipBytes: zipBytes,
          userId: 'user-1',
          cardSetRepo: mockSetRepo,
          cardRepo: mockCardRepo,
          questionTemplateRepo: mockQtRepo,
          templateRepo: mockTemplateRepo,
        );

    setUp(() {
      // New set, and no library card matches — so every card lands in
      // newCards, which is the path that uploads media.
      when(mockSetRepo.findSetByName(any, any)).thenAnswer((_) async => null);
      when(mockCardRepo.findCardByWordAndTranslation(any, any, any))
          .thenAnswer((_) async => null);
    });

    test('reports an oversized media entry', () async {
      final zip = makeZipWithMedia(
        singleSet('S', [cardWithImage('media/big.jpg')]),
        'media/big.jpg',
        AppConstants.maxMediaUploadBytes + 1,
      );

      final analysis = await analyzeWith(zip);

      expect(analysis.mediaIssues, hasLength(1));
      expect(analysis.mediaIssues.single.path, 'media/big.jpg');
      expect(analysis.mediaIssues.single.kind, MediaIssueKind.tooLarge);
    });

    test('reports an unsupported media type', () async {
      final zip = makeZipWithMedia(
        singleSet('S', [cardWithImage('media/pic.bmp')]),
        'media/pic.bmp',
        1024,
      );

      final analysis = await analyzeWith(zip);

      expect(analysis.mediaIssues, hasLength(1));
      expect(
          analysis.mediaIssues.single.kind, MediaIssueKind.unsupportedType);
    });

    test('reports nothing for valid media', () async {
      final zip = makeZipWithMedia(
        singleSet('S', [cardWithImage('media/ok.jpg')]),
        'media/ok.jpg',
        1024,
      );

      expect((await analyzeWith(zip)).mediaIssues, isEmpty);
    });

    test('does not report media that is absent from the archive', () async {
      // A missing entry is already tolerated at upload time (returns null);
      // surfacing it as a rules problem would be a misleading diagnosis.
      final zip = makeZipWithMedia(
        singleSet('S', [cardWithImage('media/missing.jpg')]),
        'media/unrelated.jpg',
        1024,
      );

      expect((await analyzeWith(zip)).mediaIssues, isEmpty);
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
