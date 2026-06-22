// Integration tests for FirebaseCardSetRepository.
// Requires the Firebase emulator to be running:
//   firebase emulators:start --only auth,firestore
// Run with: flutter test integration_test/repositories/card_set_repository_test.dart -d windows

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/repositories/firebase/firebase_card_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_card_set_repository.dart';
import '../firebase_test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String uid;
  late FirebaseCardSetRepository setRepo;
  late FirebaseCardRepository cardRepo;

  setUpAll(() async {
    await initTestFirebase();
    uid = await createAndSignInTestUser('cardset');
    setRepo = FirebaseCardSetRepository();
    cardRepo = FirebaseCardRepository();
  });

  tearDownAll(cleanupCurrentUser);

  CardSet makeSet({String name = 'Test Set'}) => CardSet(
        id: '',
        userId: uid,
        name: name,
        cardCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  FlashCard makeCard() => FlashCard(
        id: '',
        primaryWord: 'gato',
        translation: 'cat',
        questions: [],
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      );

  group('createSet', () {
    test('stores the set and returns it with a generated ID', () async {
      final created = await setRepo.createSet(makeSet());

      expect(created.id, isNotEmpty);
      expect(created.name, 'Test Set');
      expect(created.userId, uid);
      expect(created.cardCount, 0);
    });
  });

  group('getSet', () {
    test('fetches an existing set by ID', () async {
      final created = await setRepo.createSet(makeSet());

      final fetched = await setRepo.getSet(created.id);

      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
    });

    test('returns null for a non-existent set ID', () async {
      final result = await setRepo.getSet('nonexistent-set-id');
      expect(result, isNull);
    });
  });

  group('updateSet', () {
    test('persists name and description changes', () async {
      final created = await setRepo.createSet(makeSet());
      final changed = created.copyWith(name: 'Renamed Set');

      await setRepo.updateSet(changed);

      final fetched = await setRepo.getSet(created.id);
      expect(fetched!.name, 'Renamed Set');
    });
  });

  group('addCardToSet / removeCardFromSet', () {
    test('addCardToSet increments cardCount by 1', () async {
      final set = await setRepo.createSet(makeSet());
      final card = await cardRepo.createCard(makeCard());

      await setRepo.addCardToSet(
          setId: set.id, cardId: card.id, userId: uid);

      final updated = await setRepo.getSet(set.id);
      expect(updated!.cardCount, 1);
    });

    test('removeCardFromSet decrements cardCount back to 0', () async {
      final set = await setRepo.createSet(makeSet());
      final card = await cardRepo.createCard(makeCard());
      await setRepo.addCardToSet(
          setId: set.id, cardId: card.id, userId: uid);

      await setRepo.removeCardFromSet(
          setId: set.id, cardId: card.id, userId: uid);

      final updated = await setRepo.getSet(set.id);
      expect(updated!.cardCount, 0);
    });
  });

  group('watchCardIdsInSet', () {
    test('stream includes the ID of a card that was added', () async {
      final set = await setRepo.createSet(makeSet());
      final card = await cardRepo.createCard(makeCard());
      await setRepo.addCardToSet(
          setId: set.id, cardId: card.id, userId: uid);

      final ids = await setRepo.watchCardIdsInSet(set.id, uid).first;

      expect(ids, contains(card.id));
    });
  });

  group('watchUserSets', () {
    test('stream includes a set created by the user', () async {
      final set = await setRepo.createSet(makeSet(name: 'Watch Test Set'));

      final sets = await setRepo.watchUserSets(uid).first;

      expect(sets.any((s) => s.id == set.id), isTrue);
    });
  });

  group('deleteSet', () {
    test('removes the set document', () async {
      final created = await setRepo.createSet(makeSet());

      await setRepo.deleteSet(created.id, uid);

      final fetched = await setRepo.getSet(created.id);
      expect(fetched, isNull);
    });
  });

  group('findSetByName', () {
    test('returns a set whose name matches exactly', () async {
      await setRepo.createSet(makeSet(name: 'Unique Named Set'));

      final found = await setRepo.findSetByName('Unique Named Set', uid);

      expect(found, isNotNull);
    });

    test('returns null when no set has that name', () async {
      final result = await setRepo.findSetByName('No Such Set XYZ', uid);
      expect(result, isNull);
    });
  });
}