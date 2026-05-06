import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/user.dart';
import 'package:flash_me/repositories/auth_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_auth_repository.dart';

// Bind the abstract AuthRepository to its Firebase implementation.
// To swap providers, change FirebaseAuthRepository to a different class here.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);

// Emits the signed-in user's uid, or null when signed out.
// Used throughout the app to gate authenticated content.
final authStateProvider = StreamProvider<String?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Streams the full AppUser document (display name, photo, etc.) from
// persistent storage. Null when signed out or document not yet loaded.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchUser(uid);
});
