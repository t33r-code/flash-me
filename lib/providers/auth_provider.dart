import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/user.dart';
import 'package:flash_me/repositories/auth_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_auth_repository.dart';
import 'package:flash_me/services/account_deletion_service.dart';

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

// Fetches the display name of any user by uid — used by Market tiles to show
// the creator's name. Riverpod caches the result per uid for the session.
final creatorDisplayNameProvider =
    FutureProvider.family<String?, String>((ref, userId) {
  return ref.read(authRepositoryProvider).getUserDisplayName(userId);
});

// Service that orchestrates full account deletion across Firestore, Storage,
// and Firebase Auth. Kept here rather than in a separate provider file since
// it depends on auth lifecycle and is closely related to auth state.
final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  (_) => AccountDeletionService(),
);
