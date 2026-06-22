// Import/export round-trip tests for all field types, tags, and templates.
//
// Completes the #88 acceptance criteria (minus media, which is tracked
// separately in #160 and requires the Storage emulator).
//
// Requires the Firebase emulator:
//   firebase emulators:start --only auth,firestore
// Run with: flutter test integration_test/all_tests.dart -d windows

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/repositories/firebase/firebase_card_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_card_set_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_question_template_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_tag_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_template_repository.dart';
import 'package:flash_me/services/export_service.dart';
import 'package:flash_me/services/import_service.dart';
import 'package:flash_me/utils/constants.dart';
import '../firebase_test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String uid;
  late FirebaseCardRepository cardRepo;
  late FirebaseCardSetRepository setRepo;
  late FirebaseTemplateRepository templateRepo;
  late FirebaseQuestionTemplateRepository questionTemplateRepo;
  late FirebaseTagRepository tagRepo;

  setUpAll(() async {
    await initTestFirebase();
    uid = await createAndSignInTestUser('fields');
    cardRepo = FirebaseCardRepository();
    setRepo = FirebaseCardSetRepository();
    templateRepo = FirebaseTemplateRepository();
    questionTemplateRepo = FirebaseQuestionTemplateRepository();
    tagRepo = FirebaseTagRepository();
  });

  tearDownAll(cleanupCurrentUser);

  // Build a ZIP from a raw cards.json map — used for template-embedding tests.
  Uint8List buildZip(Map<String, dynamic> cardsJson) {
    final jsonBytes = utf8.encode(jsonEncode(cardsJson));
    final archive = Archive()
      ..addFile(ArchiveFile('cards.json', jsonBytes.length, jsonBytes));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // Run the full analyze → execute pipeline with default options.
  Future<void> runImport(Uint8List zipBytes) async {
    final analysis = await ImportService().analyze(
      zipBytes: zipBytes,
      userId: uid,
      cardSetRepo: setRepo,
      cardRepo: cardRepo,
      questionTemplateRepo: questionTemplateRepo,
      templateRepo: templateRepo,
    );
    await ImportService().execute(
      analysis: analysis,
      deleteNotInImport: false,
      skipUpdates: false,
      userId: uid,
      cardSetRepo: setRepo,
      cardRepo: cardRepo,
      templateRepo: templateRepo,
      questionTemplateRepo: questionTemplateRepo,
      tagRepo: tagRepo,
    );
  }

  // Delete a set and all its cards after a test.
  Future<void> cleanup(String setName) async {
    final set = await setRepo.findSetByName(setName, uid);
    if (set == null) return;
    final cards = await setRepo.watchCardsInSet(set.id, uid).first;
    await setRepo.deleteSet(set.id, uid);
    for (final c in cards) { await cardRepo.deleteCard(c.id); }
  }

  // ── Question-type round-trips via ExportService ────────────────────────────

  group('question types round-trip', () {
    // Creates a card with the given questions, exports it, deletes the
    // originals, imports, and returns the reimported card for assertion.
    Future<FlashCard> roundTrip(
      String setName,
      List<CardQuestion> questions,
    ) async {
      final card = await cardRepo.createCard(FlashCard(
        id: '',
        primaryWord: 'test_word',
        translation: 'test_translation',
        questions: questions,
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      ));
      final set = await setRepo.createSet(CardSet(
        id: '',
        userId: uid,
        name: setName,
        cardCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await setRepo.addCardToSet(setId: set.id, cardId: card.id, userId: uid);

      // Export → read file → delete file.
      final path = await ExportService().exportSet(set, [card]);
      final zipBytes = await File(path!).readAsBytes();
      await File(path).delete();

      // Delete originals so the import treats them as new.
      await setRepo.deleteSet(set.id, uid);
      await cardRepo.deleteCard(card.id);

      await runImport(zipBytes);

      final importedSet = await setRepo.findSetByName(setName, uid);
      final importedCards =
          await setRepo.watchCardsInSet(importedSet!.id, uid).first;
      return importedCards.first;
    }

    test('text_input question survives round-trip', () async {
      const setName = 'Fields: TextInput';
      final q = TextInputQuestion(
        questionId: CardQuestion.generateId(),
        prompt: 'Type the translation',
        correctAnswers: ['bonjour', 'hello'],
        hint: 'starts with b',
        exactMatch: false,
      );

      final imported = await roundTrip(setName, [q]);

      expect(imported.questions.length, 1);
      final iq = imported.questions.first as TextInputQuestion;
      expect(iq.prompt, 'Type the translation');
      expect(iq.correctAnswers, containsAll(['bonjour', 'hello']));
      expect(iq.hint, 'starts with b');
      expect(iq.exactMatch, false);

      await cleanup(setName);
    });

    test('multiple_choice question survives round-trip', () async {
      const setName = 'Fields: MultipleChoice';
      final q = MultipleChoiceQuestion(
        questionId: CardQuestion.generateId(),
        prompt: 'Select the gender',
        options: ['der', 'die', 'das'],
        correctIndex: 1,
        explanation: 'die Sonne is feminine',
      );

      final imported = await roundTrip(setName, [q]);

      expect(imported.questions.length, 1);
      final iq = imported.questions.first as MultipleChoiceQuestion;
      expect(iq.prompt, 'Select the gender');
      expect(iq.options, ['der', 'die', 'das']);
      expect(iq.correctIndex, 1);
      expect(iq.explanation, 'die Sonne is feminine');

      await cleanup(setName);
    });

    test('word_order question survives round-trip', () async {
      const setName = 'Fields: WordOrder';
      final q = WordOrderQuestion(
        questionId: CardQuestion.generateId(),
        prompt: 'Build the sentence',
        wordBank: ['ich', 'bin', 'müde', 'sehr'],
        correctOrder: ['ich', 'bin', 'sehr', 'müde'],
      );

      final imported = await roundTrip(setName, [q]);

      expect(imported.questions.length, 1);
      final iq = imported.questions.first as WordOrderQuestion;
      expect(iq.prompt, 'Build the sentence');
      expect(iq.wordBank, containsAll(['ich', 'bin', 'müde', 'sehr']));
      expect(iq.correctOrder, ['ich', 'bin', 'sehr', 'müde']);

      await cleanup(setName);
    });

    test('card with all three question types preserves count and order',
        () async {
      const setName = 'Fields: AllTypes';
      final questions = [
        TextInputQuestion(
          questionId: CardQuestion.generateId(),
          prompt: 'Type it',
          correctAnswers: ['answer'],
        ),
        MultipleChoiceQuestion(
          questionId: CardQuestion.generateId(),
          prompt: 'Pick one',
          options: ['a', 'b', 'c'],
          correctIndex: 0,
        ),
        WordOrderQuestion(
          questionId: CardQuestion.generateId(),
          prompt: 'Order them',
          wordBank: ['x', 'y'],
          correctOrder: ['x', 'y'],
        ),
      ];

      final imported = await roundTrip(setName, questions);

      expect(imported.questions.length, 3);
      expect(imported.questions[0], isA<TextInputQuestion>());
      expect(imported.questions[1], isA<MultipleChoiceQuestion>());
      expect(imported.questions[2], isA<WordOrderQuestion>());

      await cleanup(setName);
    });
  });

  // ── Tags round-trip ────────────────────────────────────────────────────────

  group('tags round-trip', () {
    test('card tags survive export → import', () async {
      const setName = 'Tags: Round-trip';
      final card = await cardRepo.createCard(FlashCard(
        id: '',
        primaryWord: 'Hund',
        translation: 'dog',
        questions: [],
        tags: ['german', 'animals', 'a1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      ));
      final set = await setRepo.createSet(CardSet(
        id: '',
        userId: uid,
        name: setName,
        cardCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await setRepo.addCardToSet(setId: set.id, cardId: card.id, userId: uid);

      final path = await ExportService().exportSet(set, [card]);
      final zipBytes = await File(path!).readAsBytes();
      await File(path).delete();

      await setRepo.deleteSet(set.id, uid);
      await cardRepo.deleteCard(card.id);

      await runImport(zipBytes);

      final importedSet = await setRepo.findSetByName(setName, uid);
      final importedCards =
          await setRepo.watchCardsInSet(importedSet!.id, uid).first;
      expect(importedCards.first.tags, containsAll(['german', 'animals', 'a1']));

      await cleanup(setName);
    });
  });

  // ── Template round-trips ───────────────────────────────────────────────────

  group('question templates in ZIP', () {
    test('new question template in ZIP is created in Firestore on execute',
        () async {
      const templateId = 'qt-fields-test';
      const setName = 'QT: Round-trip';

      final zip = buildZip({
        'version': '1.0',
        'exportDate': DateTime.now().toUtc().toIso8601String(),
        'questionTemplates': [
          {
            'name': 'Gender picker',
            'templateId': templateId,
            'question': {
              'questionId': CardQuestion.generateId(),
              'type': AppConstants.fieldTypeMultipleChoice,
              'prompt': 'Select the gender',
              'content': {
                'options': ['der', 'die', 'das'],
                'correctIndex': null,
                'displayMode': 'list',
                'explanation': null,
              },
            },
          },
        ],
        'set': {
          'name': setName,
          'tags': <String>[],
          'cards': [
            {
              'primaryWord': 'Sonne',
              'translation': 'sun',
              'primaryWordHidden': false,
              'primaryImageUrl': null,
              'primaryAudioUrl': null,
              // Reference the template by its ##id.
              'questions': [
                {
                  'template': '##$templateId',
                  'correctIndex': 1, // die Sonne
                },
              ],
              'templateId': null,
              'tags': <String>[],
            },
          ],
        },
      });

      await runImport(zip);

      // The question template should now exist in Firestore.
      final templates = await questionTemplateRepo.getUserTemplates(uid);
      final created =
          templates.where((t) => t.templateId == templateId).toList();
      expect(created, hasLength(1));
      expect(created.first.name, 'Gender picker');

      // The card should have the question expanded correctly.
      final importedSet = await setRepo.findSetByName(setName, uid);
      expect(importedSet, isNotNull);
      final importedCards =
          await setRepo.watchCardsInSet(importedSet!.id, uid).first;
      expect(importedCards.first.questions.length, 1);
      final q = importedCards.first.questions.first as MultipleChoiceQuestion;
      expect(q.options, ['der', 'die', 'das']);
      expect(q.correctIndex, 1);

      // Re-importing should not duplicate the template.
      await runImport(zip);
      final templatesAfter = await questionTemplateRepo.getUserTemplates(uid);
      expect(
        templatesAfter.where((t) => t.templateId == templateId).length,
        1,
      );

      await cleanup(setName);
    });

    test('new card template in ZIP is created in Firestore on execute',
        () async {
      const ctName = 'Basic vocab template';
      const setName = 'CT: Round-trip';

      final zip = buildZip({
        'version': '1.0',
        'exportDate': DateTime.now().toUtc().toIso8601String(),
        'cardTemplates': [
          {
            'name': ctName,
            'primaryWordHidden': false,
            'questions': <dynamic>[],
          },
        ],
        'set': {
          'name': setName,
          'tags': <String>[],
          'cards': [
            {
              'primaryWord': 'chat',
              'translation': 'cat',
              'primaryWordHidden': false,
              'primaryImageUrl': null,
              'primaryAudioUrl': null,
              'questions': <dynamic>[],
              'templateId': null,
              'tags': <String>[],
            },
          ],
        },
      });

      await runImport(zip);

      final templates = await templateRepo.watchUserTemplates(uid).first;
      expect(templates.any((t) => t.name == ctName), isTrue);

      // Re-importing should not duplicate the card template.
      await runImport(zip);
      final templatesAfter = await templateRepo.watchUserTemplates(uid).first;
      expect(templatesAfter.where((t) => t.name == ctName).length, 1);

      await cleanup(setName);
    });
  });
}