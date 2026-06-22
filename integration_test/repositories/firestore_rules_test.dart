// Security rules integration tests.
//
// These tests call the Firestore SDK directly (not through the repository layer)
// so that FirebaseException.code is visible before it gets wrapped by repository
// error handling.
//
// Requires the Firebase emulator to be running:
//   firebase emulators:start --only auth,firestore
// Run with: flutter test integration_test/repositories/firestore_rules_test.dart -d windows

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../firebase_test_config.dart';

// isA<FirebaseException> with code == 'permission-denied'.
final _permissionDenied = isA<FirebaseException>()
    .having((e) => e.code, 'code', 'permission-denied');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final db = FirebaseFirestore.instance;

  setUpAll(() async => initTestFirebase());

  // Build a minimal valid `sets` document owned by [userId].
  Map<String, dynamic> setDoc(String userId, {bool isPublic = false}) => {
        'userId': userId,
        'name': 'Rules Test Set',
        'isPublic': isPublic,
        'cardCount': 0,
        'acquisitionCount': 0,
        'tags': [],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

  // Build a minimal valid `cards` document owned by [userId].
  Map<String, dynamic> cardDoc(String userId) => {
        'createdBy': userId,
        'primaryWord': 'word',
        'translation': 'translation',
        'primaryWordHidden': false,
        'questions': [],
        'tags': [],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

  group('sets collection', () {
    test('user cannot read another user\'s private set', () async {
      final uidA = await createAndSignInTestUser('rules_set_a');
      final ref = db.collection('sets').doc();
      await ref.set(setDoc(uidA));

      await createAndSignInSecondUser('rules_set_b');

      await expectLater(() => ref.get(), throwsA(_permissionDenied));
    });

    test('user can read a public set owned by another user', () async {
      final uidA = await createAndSignInTestUser('rules_pubset_a');
      final ref = db.collection('sets').doc();
      await ref.set(setDoc(uidA, isPublic: true));

      await createAndSignInSecondUser('rules_pubset_b');

      final snap = await ref.get();
      expect(snap.exists, isTrue);
    });

    test('user cannot delete another user\'s set', () async {
      final uidA = await createAndSignInTestUser('rules_del_a');
      final ref = db.collection('sets').doc();
      await ref.set(setDoc(uidA));

      await createAndSignInSecondUser('rules_del_b');

      await expectLater(() => ref.delete(), throwsA(_permissionDenied));
    });
  });

  group('cards collection', () {
    test('any authenticated user can read another user\'s card', () async {
      // The security rules intentionally allow any authenticated user to read
      // cards — card IDs are unguessable and sharing / marketplace require it.
      final uidA = await createAndSignInTestUser('rules_card_a');
      final ref = db.collection('cards').doc();
      await ref.set(cardDoc(uidA));

      await createAndSignInSecondUser('rules_card_b');

      final snap = await ref.get();
      expect(snap.exists, isTrue);
    });

    test('user cannot delete a card owned by another user', () async {
      final uidA = await createAndSignInTestUser('rules_carddel_a');
      final ref = db.collection('cards').doc();
      await ref.set(cardDoc(uidA));

      await createAndSignInSecondUser('rules_carddel_b');

      await expectLater(() => ref.delete(), throwsA(_permissionDenied));
    });
  });

  group('study sessions subcollection', () {
    test('user cannot read another user\'s study sessions', () async {
      final uidA = await createAndSignInTestUser('rules_sess_a');
      final ref = db
          .collection('users')
          .doc(uidA)
          .collection('studySessions')
          .doc();
      await ref.set({
        'setId': 'some-set',
        'status': 'in_progress',
        'startTime': Timestamp.now(),
        'lastAccessTime': Timestamp.now(),
        'cardProgress': {},
        'cardSequence': [],
        'currentCardIndex': 0,
        'totalCardsStudied': 0,
        'cardsKnown': 0,
        'cardsUnknown': 0,
        'questionsCorrect': 0,
        'questionsTotal': 0,
        'sessionStats': {},
        'shuffled': false,
        'cardTypeMap': {},
      });

      await createAndSignInSecondUser('rules_sess_b');

      await expectLater(() => ref.get(), throwsA(_permissionDenied));
    });
  });

  group('templates collection', () {
    test('user cannot read templates created by another user', () async {
      final uidA = await createAndSignInTestUser('rules_tmpl_a');
      final ref = db.collection('templates').doc();
      await ref.set({
        'createdBy': uidA,
        'name': 'Private Template',
        'questions': [],
        'primaryWordHidden': false,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      await createAndSignInSecondUser('rules_tmpl_b');

      await expectLater(() => ref.get(), throwsA(_permissionDenied));
    });
  });

  group('unauthenticated access', () {
    test('signed-out user cannot read a public set', () async {
      final uid = await createAndSignInTestUser('rules_unauth');
      final ref = db.collection('sets').doc();
      await ref.set(setDoc(uid, isPublic: true));

      await FirebaseAuth.instance.signOut();

      await expectLater(() => ref.get(), throwsA(_permissionDenied));
    });
  });
}
