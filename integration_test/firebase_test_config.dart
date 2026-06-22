// Shared Firebase emulator setup for integration tests.
//
// HOW TO RUN
// ----------
// 1. Start the emulator (keep it running):
//      firebase emulators:start --only auth,firestore,storage
//
// 2. Run a specific test file (Windows desktop runner):
//      flutter test integration_test/repositories/card_repository_test.dart -d windows
//
//    Or run all integration tests:
//      flutter test integration_test/ -d windows
//
// The emulator resets every time it restarts, so each `firebase emulators:start`
// begins with a clean slate — no manual data teardown needed between full runs.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flash_me/firebase_options.dart';

const emulatorHost = 'localhost';
const firestorePort = 8080;
const authPort = 9099;

bool _initialized = false;

// Minimal FirebaseOptions for Linux CI runners, where DefaultFirebaseOptions
// throws UnsupportedError. The emulator ignores apiKey/appId; only projectId
// needs to match the --project flag passed to `firebase emulators:exec`.
const _linuxOptions = FirebaseOptions(
  apiKey: 'emulator-only',
  appId: '1:000000000000:linux:000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-test',
  storageBucket: 'demo-test.appspot.com',
);

/// Initialise Firebase once per test process and point it at the local emulators.
/// Safe to call from multiple setUpAll() blocks — subsequent calls are no-ops.
///
/// On Linux, DefaultFirebaseOptions is not configured, so a hardcoded demo-project
/// config is used instead. This matches `firebase emulators:exec --project demo-test`
/// in the CI workflow.
Future<void> initTestFirebase() async {
  if (_initialized) return;
  final options = Platform.isLinux
      ? _linuxOptions
      : DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: options);
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, firestorePort);
  _initialized = true;
}

/// Create a fresh emulator user with a unique email and sign in.
/// Returns the user's uid. Use [prefix] to distinguish users across test groups.
Future<String> createAndSignInTestUser([String prefix = 'test']) async {
  final email =
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}@test.example';
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: 'TestPassword1!',
  );
  return cred.user!.uid;
}

/// Sign in as a second test user — used by security-rules tests that need two actors.
Future<String> createAndSignInSecondUser([String prefix = 'other']) async {
  await FirebaseAuth.instance.signOut();
  return createAndSignInTestUser(prefix);
}

/// Delete the current auth user and sign out.
/// The emulator allows deletion without re-authentication.
Future<void> cleanupCurrentUser() async {
  try {
    await FirebaseAuth.instance.currentUser?.delete();
  } catch (_) {}
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {}
}