// Integration tests for FirebaseStudySessionRepository.
// Requires the Firebase emulator to be running:
//   firebase emulators:start --only auth,firestore
// Run with: flutter test integration_test/repositories/study_session_repository_test.dart -d windows

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/repositories/firebase/firebase_study_session_repository.dart';
import 'package:flash_me/utils/constants.dart';
import '../firebase_test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String uid;
  late FirebaseStudySessionRepository repo;
  // Arbitrary placeholder set ID — session tests don't need a real set.
  const testSetId = 'test-set-id-for-sessions';

  setUpAll(() async {
    await initTestFirebase();
    uid = await createAndSignInTestUser('session');
    repo = FirebaseStudySessionRepository();
  });

  tearDownAll(cleanupCurrentUser);

  StudySession makeSession({String? setId}) => StudySession(
        id: '',
        setId: setId ?? testSetId,
        startTime: DateTime.now(),
        lastAccessTime: DateTime.now(),
        status: AppConstants.sessionStatusInProgress,
        cardProgress: {},
        cardSequence: [],
        currentCardIndex: 0,
        totalCardsStudied: 0,
        cardsKnown: 0,
        cardsUnknown: 0,
        sessionStats: const SessionStats(),
      );

  group('createSession', () {
    test('stores the session and returns it with a generated ID', () async {
      final created = await repo.createSession(makeSession(), uid);

      expect(created.id, isNotEmpty);
      expect(created.setId, testSetId);
      expect(created.status, AppConstants.sessionStatusInProgress);
    });
  });

  group('saveSession', () {
    test('persists progress changes to Firestore', () async {
      final created = await repo.createSession(makeSession(), uid);
      // Simulate advancing one card in the session.
      final updated = created.copyWith(
        currentCardIndex: 1,
        totalCardsStudied: 1,
      );

      await repo.saveSession(updated, uid);

      final active = await repo.getActiveSession(testSetId, uid);
      expect(active?.currentCardIndex, 1);
      expect(active?.totalCardsStudied, 1);
    });
  });

  group('completeSession', () {
    test('transitions status to completed', () async {
      final created = await repo.createSession(
          makeSession(setId: 'complete-set'), uid);

      await repo.completeSession(created, uid);

      // getActiveSession only returns in-progress sessions, so result is null.
      final active =
          await repo.getActiveSession('complete-set', uid);
      expect(active, isNull);
    });
  });

  group('getActiveSession', () {
    test('returns the most recent in-progress session for a set', () async {
      const uniqueSetId = 'set-for-active-lookup';
      final created =
          await repo.createSession(makeSession(setId: uniqueSetId), uid);

      final active = await repo.getActiveSession(uniqueSetId, uid);

      expect(active, isNotNull);
      expect(active!.id, created.id);
      expect(active.status, AppConstants.sessionStatusInProgress);
    });

    test('returns null when no in-progress session exists', () async {
      final result =
          await repo.getActiveSession('set-with-no-sessions', uid);
      expect(result, isNull);
    });
  });

  group('watchSessionHistory', () {
    test('stream emits sessions for the set, newest first', () async {
      const uniqueSetId = 'set-for-history';
      final s1 =
          await repo.createSession(makeSession(setId: uniqueSetId), uid);
      final s2 =
          await repo.createSession(makeSession(setId: uniqueSetId), uid);

      final history =
          await repo.watchSessionHistory(uniqueSetId, uid).first;

      // Both sessions should appear; newest (s2) should come first.
      final ids = history.map((s) => s.id).toList();
      expect(ids, containsAll([s1.id, s2.id]));
      expect(ids.indexOf(s2.id), lessThan(ids.indexOf(s1.id)));
    });
  });
}