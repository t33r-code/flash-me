// Integration tests for FirebaseWorkbookCardRepository.
// Requires the Firebase emulator to be running:
//   firebase emulators:start --only auth,firestore
// Run with: flutter test integration_test/repositories/workbook_card_repository_test.dart -d windows

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/repositories/firebase/firebase_card_set_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_workbook_card_repository.dart';
import 'package:flash_me/utils/constants.dart';
import '../firebase_test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String uid;
  late FirebaseWorkbookCardRepository repo;
  late FirebaseCardSetRepository setRepo;
  late FirebaseFirestore db;

  setUpAll(() async {
    await initTestFirebase();
    uid = await createAndSignInTestUser('workbook');
    repo = FirebaseWorkbookCardRepository();
    setRepo = FirebaseCardSetRepository();
    db = FirebaseFirestore.instance;
  });

  tearDownAll(cleanupCurrentUser);

  WorkbookCard makeCard({String prompt = 'Read and answer'}) => WorkbookCard(
        id: '',
        prompt: prompt,
        questions: const [],
        tags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      );

  CardSet makeSet({String name = 'Workbook Set'}) => CardSet(
        id: '',
        userId: uid,
        name: name,
        cardCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  // Count setCards links for a card — constrained by userId so the query is
  // allowed under the security rules (the same constraint deleteCard needs).
  Future<int> setCardLinksForCard(String cardId) async {
    final snap = await db
        .collection(AppConstants.setCardsCollection)
        .where('cardId', isEqualTo: cardId)
        .where('userId', isEqualTo: uid)
        .get();
    return snap.docs.length;
  }

  group('createCard', () {
    test('stores the card and returns it with a generated ID', () async {
      final created = await repo.createCard(makeCard());

      expect(created.id, isNotEmpty);
      expect(created.prompt, 'Read and answer');
      expect(created.createdBy, uid);
    });
  });

  group('getCard', () {
    test('fetches an existing card by ID', () async {
      final created = await repo.createCard(makeCard());

      final fetched = await repo.getCard(created.id);

      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
      expect(fetched.prompt, 'Read and answer');
    });

    test('returns null for a non-existent card ID', () async {
      expect(await repo.getCard('nonexistent-workbook-id'), isNull);
    });
  });

  group('updateCard', () {
    test('persists prompt changes to Firestore', () async {
      final created = await repo.createCard(makeCard());

      await repo.updateCard(created.copyWith(prompt: 'Updated prompt'));

      final fetched = await repo.getCard(created.id);
      expect(fetched!.prompt, 'Updated prompt');
    });
  });

  group('deleteCard', () {
    test('removes a card that is in no sets', () async {
      final created = await repo.createCard(makeCard());

      await repo.deleteCard(created.id);

      expect(await repo.getCard(created.id), isNull);
    });

    // Regression for #201: deleteCard queries setCards, which the security
    // rules only permit with a userId constraint. Without it the query — and
    // thus the whole delete — is rejected with permission-denied. This case
    // (a workbook card that belongs to a set) is the one that exercises it.
    test('removes the card and its set link, decrementing cardCount', () async {
      final card = await repo.createCard(makeCard(prompt: 'In a set'));
      final set = await setRepo.createSet(makeSet());

      await setRepo.addCardToSet(
        setId: set.id,
        cardId: card.id,
        userId: uid,
        cardType: AppConstants.cardTypeWorkbook,
      );
      expect(await setCardLinksForCard(card.id), 1);
      expect((await setRepo.getSet(set.id))!.cardCount, 1);

      await repo.deleteCard(card.id);

      expect(await repo.getCard(card.id), isNull);
      expect(await setCardLinksForCard(card.id), 0);
      expect((await setRepo.getSet(set.id))!.cardCount, 0);
    });
  });

  group('watchUserCards', () {
    test('stream emits the user\'s workbook cards', () async {
      final created = await repo.createCard(makeCard(prompt: 'Watched'));

      final cards = await repo.watchUserCards(uid).first;

      expect(cards.any((c) => c.id == created.id), isTrue);
    });
  });
}