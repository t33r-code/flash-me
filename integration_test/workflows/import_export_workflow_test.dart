// Import/export round-trip workflow tests.
//
// Tests cover:
//   - ExportService producing a valid ZIP that ImportService can parse
//   - ImportService analyze(): new cards, idempotency, update detection
//   - ImportService execute(): cards and sets created with correct content
//
// Export tests write a ZIP to the system Downloads folder, read it back,
// and delete it — the file is named with a timestamp so it won't conflict.
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

import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/repositories/firebase/firebase_card_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_card_set_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_question_template_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_tag_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_template_repository.dart';
import 'package:flash_me/services/export_service.dart';
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

  // Build a minimal valid Agora ZIP in memory — mirrors ExportService format.
  // [cards] entries must have 'primaryWord' and 'translation'.
  Uint8List buildZipBytes(
      String setName, List<Map<String, dynamic>> cards) {
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

  // Convenience wrapper: analyze + execute with default options (no deletions,
  // apply updates).
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
    test(
        'ExportService produces a ZIP that ImportService can parse and execute',
        () async {
      // Create two cards and a set.
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
      final set = await setRepo.createSet(CardSet(
        id: '',
        userId: uid,
        name: 'French Round-trip',
        cardCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await setRepo.addCardToSet(setId: set.id, cardId: card1.id, userId: uid);
      await setRepo.addCardToSet(setId: set.id, cardId: card2.id, userId: uid);

      // Export to disk.
      final zipPath = await ExportService().exportSet(set, [card1, card2]);
      expect(zipPath, isNotNull);
      final zipFile = File(zipPath!);
      expect(await zipFile.exists(), isTrue);
      final zipBytes = await zipFile.readAsBytes();
      await zipFile.delete(); // clean up Downloads file

      // Delete the original set + cards so the import treats them as new.
      await setRepo.deleteSet(set.id, uid);
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

      // Execute import and verify Firestore state.
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
      final words = importedCards.map((c) => c.primaryWord).toSet();
      expect(words, containsAll(['bonjour', 'merci']));
      // Translations must survive the round-trip.
      final translations = {for (final c in importedCards) c.primaryWord: c.translation};
      expect(translations['bonjour'], 'hello');
      expect(translations['merci'], 'thank you');

      // Cleanup.
      await setRepo.deleteSet(importedSet.id, uid);
      for (final c in importedCards) {
        await cardRepo.deleteCard(c.id);
      }
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

      // First import — creates the set and cards.
      await runImport(zipBytes);

      // Second import — same data, same user.
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
        final cards =
            await setRepo.watchCardsInSet(set.id, uid).first;
        await setRepo.deleteSet(set.id, uid);
        for (final c in cards) { await cardRepo.deleteCard(c.id); }
      }
    });

    test('analyze detects a translation change as an update', () async {
      // First import.
      final zipV1 = buildZipBytes('Update Test Set', [
        {'primaryWord': 'chat', 'translation': 'cat'},
      ]);
      await runImport(zipV1);

      // Second import with different translation.
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
      // Import 2 cards.
      final zipFull = buildZipBytes('Deletable Test Set', [
        {'primaryWord': 'rouge', 'translation': 'red'},
        {'primaryWord': 'bleu', 'translation': 'blue'},
      ]);
      await runImport(zipFull);

      // Re-import with only 1 card — the other should appear as deletable.
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