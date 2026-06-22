// Cross-repository workflow tests: card ↔ set membership and cascade deletes.
//
// These tests exercise code paths that span multiple repositories (card,
// card-set, setCards join collection). They verify invariants that individual
// repository tests cannot — specifically that the batch operations that
// maintain denormalised cardCount and setCards links are correct under the
// full Firestore security rules.
//
// Requires the Firebase emulator:
//   firebase emulators:start --only auth,firestore
// Run with: flutter test integration_test/all_tests.dart -d windows

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/repositories/firebase/firebase_card_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_card_set_repository.dart';
import 'package:flash_me/utils/constants.dart';
import '../firebase_test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String uid;
  late FirebaseCardRepository cardRepo;
  late FirebaseCardSetRepository setRepo;
  late FirebaseFirestore db;

  setUpAll(() async {
    await initTestFirebase();
    uid = await createAndSignInTestUser('lifecycle');
    cardRepo = FirebaseCardRepository();
    setRepo = FirebaseCardSetRepository();
    db = FirebaseFirestore.instance;
  });

  tearDownAll(cleanupCurrentUser);

  FlashCard makeCard({String word = 'hola'}) => FlashCard(
        id: '',
        primaryWord: word,
        translation: 'hello',
        questions: [],
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      );

  CardSet makeSet({String name = 'Lifecycle Set'}) => CardSet(
        id: '',
        userId: uid,
        name: name,
        cardCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  // Fetch the raw setCards docs for a card — used to verify cascade cleanup.
  Future<int> setCardLinksForCard(String cardId) async {
    final snap = await db
        .collection(AppConstants.setCardsCollection)
        .where('cardId', isEqualTo: cardId)
        .where('userId', isEqualTo: uid)
        .get();
    return snap.docs.length;
  }

  // Fetch the raw setCards docs for a set — used to verify cascade cleanup.
  Future<int> setCardLinksForSet(String setId) async {
    final snap = await db
        .collection(AppConstants.setCardsCollection)
        .where('setId', isEqualTo: setId)
        .where('userId', isEqualTo: uid)
        .get();
    return snap.docs.length;
  }

  group('deleteCard cascade', () {
    test('removes all setCards links and decrements cardCount on each set',
        () async {
      final card = await cardRepo.createCard(makeCard());
      final setA = await setRepo.createSet(makeSet(name: 'Set A'));
      final setB = await setRepo.createSet(makeSet(name: 'Set B'));

      // Add the same card to two different sets.
      await setRepo.addCardToSet(setId: setA.id, cardId: card.id, userId: uid);
      await setRepo.addCardToSet(setId: setB.id, cardId: card.id, userId: uid);

      expect((await setRepo.getSet(setA.id))!.cardCount, 1);
      expect((await setRepo.getSet(setB.id))!.cardCount, 1);
      expect(await setCardLinksForCard(card.id), 2);

      // Deleting the card should cascade: both links gone, both counts back to 0.
      await cardRepo.deleteCard(card.id);

      expect(await setCardLinksForCard(card.id), 0);
      expect((await setRepo.getSet(setA.id))!.cardCount, 0);
      expect((await setRepo.getSet(setB.id))!.cardCount, 0);

      // Clean up sets.
      await setRepo.deleteSet(setA.id, uid);
      await setRepo.deleteSet(setB.id, uid);
    });
  });

  group('deleteSet cascade', () {
    test('removes all setCards links but leaves the cards intact', () async {
      final card = await cardRepo.createCard(makeCard(word: 'adios'));
      final set = await setRepo.createSet(makeSet(name: 'Cascade Set'));

      await setRepo.addCardToSet(setId: set.id, cardId: card.id, userId: uid);
      expect(await setCardLinksForSet(set.id), 1);

      // Deleting the set should remove the link; the card should still exist.
      await setRepo.deleteSet(set.id, uid);

      expect(await setCardLinksForSet(set.id), 0);
      final cardStillExists = await cardRepo.getCard(card.id);
      expect(cardStillExists, isNotNull);

      // Clean up card.
      await cardRepo.deleteCard(card.id);
    });
  });

  group('multi-card set membership', () {
    test('cardCount tracks adds and removes correctly across multiple cards',
        () async {
      final set = await setRepo.createSet(makeSet(name: 'Multi Card Set'));
      final cards = await Future.wait([
        cardRepo.createCard(makeCard(word: 'uno')),
        cardRepo.createCard(makeCard(word: 'dos')),
        cardRepo.createCard(makeCard(word: 'tres')),
      ]);

      // Add all three cards.
      for (final c in cards) {
        await setRepo.addCardToSet(setId: set.id, cardId: c.id, userId: uid);
      }
      expect((await setRepo.getSet(set.id))!.cardCount, 3);

      // Remove the middle one.
      await setRepo.removeCardFromSet(
          setId: set.id, cardId: cards[1].id, userId: uid);
      expect((await setRepo.getSet(set.id))!.cardCount, 2);

      // The remaining two should still appear in the membership stream.
      final memberIds = await setRepo.watchCardIdsInSet(set.id, uid).first;
      expect(memberIds, containsAll([cards[0].id, cards[2].id]));
      expect(memberIds, isNot(contains(cards[1].id)));

      // Clean up.
      await setRepo.deleteSet(set.id, uid);
      for (final c in cards) {
        await cardRepo.deleteCard(c.id);
      }
    });
  });
}
