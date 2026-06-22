// Import/export round-trip workflow tests.
//
// Tests cover:
//   - ImportService analyze(): new cards, idempotency, update detection,
//     deletable card detection
//   - ImportService execute(): cards and sets created with correct content
//
// ZIPs are built in memory using the same format as ExportService so that
// these tests run on all platforms including web (dart:io is not available
// on web, and ExportService's file-delivery path is platform-specific).
// ExportService file delivery is tested locally with -d windows.
//
// Requires the Firebase emulator:
//   firebase emulators:start --only auth,firestore
// Run all tests with: flutter test integration_test/all_tests.dart -d windows
// CI runs with:       flutter test integration_test/all_tests.dart -d windows

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/repositories/firebase/firebase_card_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_card_set_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_question_template_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_tag_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_template_repository.dart';
import 'package:flash_me/services/import_service.dart';
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
    uid = await createAndSignInTestUser('impexp');
    cardRepo = FirebaseCardRepository();
    setRepo = FirebaseCardSetRepository();
    templateRepo = FirebaseTemplateRepository();
    questionTemplateRepo = FirebaseQuestionTemplateRepository();
    tagRepo = FirebaseTagRepository();
  });

  tearDownAll(cleanupCurrentUser);

  // Build a minimal Agora ZIP in memory, matching the ExportService format.
  // [cards] entries must have 'primaryWord' and 'translation'.
  Uint8List buildZipBytes(String setName, List<Map<String, dynamic>> cards) {
    final jsonMap = {
      'version': '1.0',
      'exportDate': DateTime.now().toUtc().toIso8601String(),
      'set': {
        'name': setName,
        'tags': <String>[],
        'cards': cards
            .map((c) => {
                  'primaryWord': c['primaryWord'],
                  'translation': c['translation'],
                  'primaryWordHidden': false,
                  'primaryImageUrl': null,
                  'primaryAudioUrl': null,
                  'questions': <dynamic>[],
                  'templateId': null,
                  'tags': <String>[],
                })
            .toList(),
      },
    };
    final jsonBytes = utf8.encode(jsonEncode(jsonMap));
    final archive = Archive()
      ..addFile(ArchiveFile('cards.json', jsonBytes.length, jsonBytes));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // Build a ZIP from existing FlashCard objects, serialising questions the same
  // way ExportService does (toJson() minus questionId so importers get fresh IDs).
  Uint8List buildZipFromCards(String setName, List<FlashCard> cards) {
    final cardMaps = cards.map((card) => {
          'primaryWord': card.primaryWord,
          'translation': card.translation,
          'primaryWordHidden': card.primaryWordHidden,
          'primaryImageUrl': null,
          'primaryAudioUrl': null,
          'questions': card.questions.map((q) {
            final m = Map<String, dynamic>.from(q.toJson());
            m.remove('questionId');
            return m;
          }).toList(),
          'templateId': card.templateId,
          'tags': card.tags,
        }).toList();

    final jsonMap = {
      'version': '1.0',
      'exportDate': DateTime.now().toUtc().toIso8601String(),
      'set': {
        'name': setName,
        'tags': <String>[],
        'cards': cardMaps,
      },
    };
    final jsonBytes = utf8.encode(jsonEncode(jsonMap));
    final archive = Archive()
      ..addFile(ArchiveFile('cards.json', jsonBytes.length, jsonBytes));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // Convenience wrapper: analyze + execute with default options.
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

  group('export → import round-trip', () {
    test('cards created in Firestore survive a ZIP round-trip intact', () async {
      // Create two cards in Firestore.
      final card1 = await cardRepo.createCard(FlashCard(
        id: '',
        primaryWord: 'bonjour',
        translation: 'hello',
        questions: [],
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      ));
      final card2 = await cardRepo.createCard(FlashCard(
        id: '',
        primaryWord: 'merci',
        translation: 'thank you',
        questions: [],
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      ));

      // Serialise to ExportService format in memory, then delete the originals.
      final zipBytes = buildZipFromCards('French Round-trip', [card1, card2]);
      await cardRepo.deleteCard(card1.id);
      await cardRepo.deleteCard(card2.id);

      // Analyse: expect 2 new cards, 0 updates.
      final analysis = await ImportService().analyze(
        zipBytes: zipBytes,
        userId: uid,
        cardSetRepo: setRepo,
        cardRepo: cardRepo,
        questionTemplateRepo: questionTemplateRepo,
        templateRepo: templateRepo,
      );
      expect(analysis.setDiffs.length, 1);
      final diff = analysis.setDiffs.first;
      expect(diff.setName, 'French Round-trip');
      expect(diff.newCards.length, 2);
      expect(diff.updatedCards, isEmpty);

      // Execute and verify Firestore state.
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

      final importedSet = await setRepo.findSetByName('French Round-trip', uid);
      expect(importedSet, isNotNull);
      expect(importedSet!.cardCount, 2);

      final importedCards =
          await setRepo.watchCardsInSet(importedSet.id, uid).first;
      final translations = {
        for (final c in importedCards) c.primaryWord: c.translation
      };
      expect(translations['bonjour'], 'hello');
      expect(translations['merci'], 'thank you');

      // Cleanup.
      await setRepo.deleteSet(importedSet.id, uid);
      for (final c in importedCards) { await cardRepo.deleteCard(c.id); }
    });
  });

  group('import diff analysis', () {
    test('analyze detects all cards as new when the set does not exist',
        () async {
      final zipBytes = buildZipBytes('New Set XYZ', [
        {'primaryWord': 'uno', 'translation': 'one'},
        {'primaryWord': 'dos', 'translation': 'two'},
      ]);

      final analysis = await ImportService().analyze(
        zipBytes: zipBytes,
        userId: uid,
        cardSetRepo: setRepo,
        cardRepo: cardRepo,
        questionTemplateRepo: questionTemplateRepo,
        templateRepo: templateRepo,
      );

      expect(analysis.setDiffs.first.newCards.length, 2);
      expect(analysis.setDiffs.first.updatedCards, isEmpty);
      expect(analysis.setDiffs.first.deletableCards, isEmpty);
    });

    test('re-importing identical data shows no new or updated cards', () async {
      final zipBytes = buildZipBytes('Idempotent Set', [
        {'primaryWord': 'ja', 'translation': 'yes'},
        {'primaryWord': 'nein', 'translation': 'no'},
      ]);

      await runImport(zipBytes);

      final analysis2 = await ImportService().analyze(
        zipBytes: zipBytes,
        userId: uid,
        cardSetRepo: setRepo,
        cardRepo: cardRepo,
        questionTemplateRepo: questionTemplateRepo,
        templateRepo: templateRepo,
      );
      final diff = analysis2.setDiffs.first;
      expect(diff.newCards, isEmpty);
      expect(diff.updatedCards, isEmpty);

      // Cleanup.
      final set = await setRepo.findSetByName('Idempotent Set', uid);
      if (set != null) {
        final cards = await setRepo.watchCardsInSet(set.id, uid).first;
        await setRepo.deleteSet(set.id, uid);
        for (final c in cards) { await cardRepo.deleteCard(c.id); }
      }
    });

    test('analyze detects a translation change as an update', () async {
      final zipV1 = buildZipBytes('Update Test Set', [
        {'primaryWord': 'chat', 'translation': 'cat'},
      ]);
      await runImport(zipV1);

      final zipV2 = buildZipBytes('Update Test Set', [
        {'primaryWord': 'chat', 'translation': 'cat (updated)'},
      ]);
      final analysis = await ImportService().analyze(
        zipBytes: zipV2,
        userId: uid,
        cardSetRepo: setRepo,
        cardRepo: cardRepo,
        questionTemplateRepo: questionTemplateRepo,
        templateRepo: templateRepo,
      );
      final diff = analysis.setDiffs.first;
      expect(diff.updatedCards.length, 1);
      expect(diff.updatedCards.first.existing.primaryWord, 'chat');
      expect(diff.updatedCards.first.incoming.translation, 'cat (updated)');
      expect(diff.newCards, isEmpty);

      // Cleanup.
      final set = await setRepo.findSetByName('Update Test Set', uid);
      if (set != null) {
        final cards = await setRepo.watchCardsInSet(set.id, uid).first;
        await setRepo.deleteSet(set.id, uid);
        for (final c in cards) { await cardRepo.deleteCard(c.id); }
      }
    });

    test('deletableCards lists cards present in Firestore but absent from ZIP',
        () async {
      final zipFull = buildZipBytes('Deletable Test Set', [
        {'primaryWord': 'rouge', 'translation': 'red'},
        {'primaryWord': 'bleu', 'translation': 'blue'},
      ]);
      await runImport(zipFull);

      final zipPartial = buildZipBytes('Deletable Test Set', [
        {'primaryWord': 'rouge', 'translation': 'red'},
      ]);
      final analysis = await ImportService().analyze(
        zipBytes: zipPartial,
        userId: uid,
        cardSetRepo: setRepo,
        cardRepo: cardRepo,
        questionTemplateRepo: questionTemplateRepo,
        templateRepo: templateRepo,
      );
      final diff = analysis.setDiffs.first;
      expect(diff.deletableCards.length, 1);
      expect(diff.deletableCards.first.primaryWord, 'bleu');

      // Cleanup.
      final set = await setRepo.findSetByName('Deletable Test Set', uid);
      if (set != null) {
        final cards = await setRepo.watchCardsInSet(set.id, uid).first;
        await setRepo.deleteSet(set.id, uid);
        for (final c in cards) { await cardRepo.deleteCard(c.id); }
      }
    });
  });
}