// Integration tests for FirebaseCardRepository.
// Requires the Firebase emulator to be running:
//   firebase emulators:start --only auth,firestore
// Run with: flutter test integration_test/repositories/card_repository_test.dart -d windows

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/repositories/firebase/firebase_card_repository.dart';
import '../firebase_test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String uid;
  late FirebaseCardRepository repo;

  setUpAll(() async {
    await initTestFirebase();
    uid = await createAndSignInTestUser('card');
    repo = FirebaseCardRepository();
  });

  tearDownAll(cleanupCurrentUser);

  // Builds a minimal valid flash card owned by [uid].
  FlashCard makeCard({String word = 'hola', String translation = 'hello'}) =>
      FlashCard(
        id: '',
        primaryWord: word,
        translation: translation,
        questions: [],
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      );

  group('createCard', () {
    test('stores the card and returns it with a generated ID', () async {
      final created = await repo.createCard(makeCard());

      expect(created.id, isNotEmpty);
      expect(created.primaryWord, 'hola');
      expect(created.translation, 'hello');
      expect(created.createdBy, uid);
    });
  });

  group('getCard', () {
    test('fetches an existing card by ID', () async {
      final created = await repo.createCard(makeCard());

      final fetched = await repo.getCard(created.id);

      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
      expect(fetched.primaryWord, 'hola');
    });

    test('returns null for a non-existent card ID', () async {
      final result = await repo.getCard('nonexistent-card-id');
      expect(result, isNull);
    });
  });

  group('updateCard', () {
    test('persists field changes to Firestore', () async {
      final created = await repo.createCard(makeCard());
      final changed = created.copyWith(primaryWord: 'adiós');

      await repo.updateCard(changed);

      final fetched = await repo.getCard(created.id);
      expect(fetched!.primaryWord, 'adiós');
    });
  });

  group('deleteCard', () {
    test('removes the card from Firestore', () async {
      final created = await repo.createCard(makeCard());

      await repo.deleteCard(created.id);

      final fetched = await repo.getCard(created.id);
      expect(fetched, isNull);
    });
  });

  group('watchUserCards', () {
    test('stream emits the user\'s cards', () async {
      final created = await repo.createCard(makeCard(word: 'perro'));

      final cards = await repo.watchUserCards(uid).first;

      expect(cards.any((c) => c.id == created.id), isTrue);
    });
  });

  group('getCardsByIds', () {
    test('returns the requested cards in any order', () async {
      final a = await repo.createCard(makeCard(word: 'uno'));
      final b = await repo.createCard(makeCard(word: 'dos'));

      final results = await repo.getCardsByIds([a.id, b.id], uid);

      expect(results.map((c) => c.id), containsAll([a.id, b.id]));
    });

    test('returns empty list when given no IDs', () async {
      final results = await repo.getCardsByIds([], uid);
      expect(results, isEmpty);
    });
  });

  group('findCardByWordAndTranslation', () {
    test('locates a card that matches the word and translation exactly',
        () async {
      await repo.createCard(makeCard(word: 'libro', translation: 'book'));

      final found = await repo.findCardByWordAndTranslation(
          'libro', 'book', uid);

      expect(found, isNotNull);
      expect(found!.primaryWord, 'libro');
    });

    test('returns null when no match exists', () async {
      final result = await repo.findCardByWordAndTranslation(
          'xyz_no_match', 'xyz_no_match', uid);
      expect(result, isNull);
    });
  });
}