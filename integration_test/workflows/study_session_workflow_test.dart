// Cross-repository workflow tests: full study session lifecycle.
//
// These tests span the card, card-set, and study-session repositories to
// verify that a complete "user studies a set" flow works end-to-end: cards
// are created, added to a set, a session is started for that set, progress
// is saved, the session is resumed (as a user would after closing the app),
// and finally completed and visible in history.
//
// Requires the Firebase emulator:
//   firebase emulators:start --only auth,firestore
// Run with: flutter test integration_test/all_tests.dart -d windows

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/repositories/firebase/firebase_card_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_card_set_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_study_session_repository.dart';
import 'package:flash_me/utils/constants.dart';
import '../firebase_test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String uid;
  late FirebaseCardRepository cardRepo;
  late FirebaseCardSetRepository setRepo;
  late FirebaseStudySessionRepository sessionRepo;

  setUpAll(() async {
    await initTestFirebase();
    uid = await createAndSignInTestUser('workflow');
    cardRepo = FirebaseCardRepository();
    setRepo = FirebaseCardSetRepository();
    sessionRepo = FirebaseStudySessionRepository();
  });

  tearDownAll(cleanupCurrentUser);

  FlashCard makeCard(String word) => FlashCard(
        id: '',
        primaryWord: word,
        translation: '$word (translation)',
        questions: [],
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: uid,
      );

  CardSet makeSet(String name) => CardSet(
        id: '',
        userId: uid,
        name: name,
        cardCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  StudySession makeSession(String setId, List<String> cardIds) => StudySession(
        id: '',
        setId: setId,
        startTime: DateTime.now(),
        lastAccessTime: DateTime.now(),
        status: AppConstants.sessionStatusInProgress,
        cardProgress: {},
        // cardSequence stores the ordered IDs the study engine will present.
        cardSequence: cardIds,
        currentCardIndex: 0,
        totalCardsStudied: 0,
        cardsKnown: 0,
        cardsUnknown: 0,
        sessionStats: const SessionStats(),
      );

  group('full study session workflow', () {
    test(
        'create cards, build set, start session, resume after "app close", complete',
        () async {
      // --- Setup: 3 cards in a set ---
      final cards = await Future.wait([
        cardRepo.createCard(makeCard('hola')),
        cardRepo.createCard(makeCard('gracias')),
        cardRepo.createCard(makeCard('por favor')),
      ]);
      final cardIds = cards.map((c) => c.id).toList();

      final set = await setRepo.createSet(makeSet('Spanish Basics'));
      for (final id in cardIds) {
        await setRepo.addCardToSet(setId: set.id, cardId: id, userId: uid);
      }
      expect((await setRepo.getSet(set.id))!.cardCount, 3);

      // --- Start session ---
      final session = await sessionRepo.createSession(
        makeSession(set.id, cardIds),
        uid,
      );
      expect(session.id, isNotEmpty);
      expect(session.currentCardIndex, 0);

      // Verify the active session is retrievable (simulates app cold-start resume).
      final retrieved = await sessionRepo.getActiveSession(set.id, uid);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, session.id);

      // --- Simulate studying: advance through all 3 cards ---
      final afterCard1 = session.copyWith(
        currentCardIndex: 1,
        totalCardsStudied: 1,
        cardsKnown: 1,
        cardProgress: {
          cardIds[0]: const CardSessionData(
              status: AppConstants.cardStatusAnswered, markedKnown: true),
        },
      );
      await sessionRepo.saveSession(afterCard1, uid);

      // "App close" — retrieve and resume.
      final resumed = await sessionRepo.getActiveSession(set.id, uid);
      expect(resumed!.currentCardIndex, 1);
      expect(resumed.cardsKnown, 1);

      final afterCard2 = resumed.copyWith(
        currentCardIndex: 2,
        totalCardsStudied: 2,
        cardsUnknown: 1,
        cardProgress: {
          cardIds[0]: const CardSessionData(
              status: AppConstants.cardStatusAnswered, markedKnown: true),
          cardIds[1]: const CardSessionData(
              status: AppConstants.cardStatusAnswered, markedUnknown: true),
        },
      );
      await sessionRepo.saveSession(afterCard2, uid);

      final afterCard3 = afterCard2.copyWith(
        currentCardIndex: 3,
        totalCardsStudied: 3,
        cardsKnown: 2,
      );
      await sessionRepo.saveSession(afterCard3, uid);

      // --- Complete ---
      await sessionRepo.completeSession(afterCard3, uid);

      // No active session for this set any more.
      final noActive = await sessionRepo.getActiveSession(set.id, uid);
      expect(noActive, isNull);

      // Session appears in history with completed status.
      final history =
          await sessionRepo.watchSessionHistory(set.id, uid).first;
      expect(history, isNotEmpty);
      expect(history.first.status, AppConstants.sessionStatusCompleted);
      expect(history.first.totalCardsStudied, 3);

      // Clean up.
      await setRepo.deleteSet(set.id, uid);
      for (final id in cardIds) {
        await cardRepo.deleteCard(id);
      }
    });

    test('two concurrent sessions for different sets are independent', () async {
      // Ensures session lookup is correctly scoped to setId.
      final setA = await setRepo.createSet(makeSet('Set A'));
      final setB = await setRepo.createSet(makeSet('Set B'));

      final sessionA = await sessionRepo.createSession(
          makeSession(setA.id, []), uid);
      final sessionB = await sessionRepo.createSession(
          makeSession(setB.id, []), uid);

      final activeA = await sessionRepo.getActiveSession(setA.id, uid);
      final activeB = await sessionRepo.getActiveSession(setB.id, uid);

      expect(activeA!.id, sessionA.id);
      expect(activeB!.id, sessionB.id);

      // Completing A doesn't affect B.
      await sessionRepo.completeSession(sessionA, uid);
      expect(await sessionRepo.getActiveSession(setA.id, uid), isNull);
      expect(
          (await sessionRepo.getActiveSession(setB.id, uid))!.id, sessionB.id);

      // Clean up.
      await sessionRepo.completeSession(sessionB, uid);
      await setRepo.deleteSet(setA.id, uid);
      await setRepo.deleteSet(setB.id, uid);
    });
  });
}