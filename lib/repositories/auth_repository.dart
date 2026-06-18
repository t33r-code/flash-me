import 'package:flash_me/models/user.dart';

// Provider-agnostic contract for authentication and user-profile operations.
// The Firebase implementation lives in repositories/firebase/.
// Swap to a different provider by writing a new implementation class and
// changing the provider binding in auth_provider.dart — no other code changes.
abstract class AuthRepository {
  // Emits the signed-in user's uid, or null when signed out.
  // Using a plain String avoids leaking any provider-specific types.
  Stream<String?> get authStateChanges;

  // Synchronous uid from the auth cache; null if not signed in.
  String? get currentUserId;

  // --- Auth operations -------------------------------------------------------

  Future<void> registerWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  // Returns false if the user cancelled (not an error); throws on failure.
  Future<bool> signInWithGoogle();

  Future<void> signOut();

  // --- Account linking -------------------------------------------------------

  // Returns provider IDs currently linked to the signed-in account.
  // Known values: 'google.com' (Google), 'password' (email & password).
  List<String> getLinkedProviderIds();

  // Link Google as an additional sign-in method. Returns false if cancelled.
  Future<bool> linkWithGoogle();

  // Link an email & password credential to the current account.
  Future<void> linkWithEmailPassword({
    required String email,
    required String password,
  });

  // Remove a linked provider. Throws AppException with code
  // 'cannot-unlink-only-provider' if this would leave the account with none.
  Future<void> unlinkProvider(String providerId);

  Future<void> sendEmailVerification();

  Future<void> resetPassword(String email);

  // --- User profile operations -----------------------------------------------

  // Update display name / photo in both auth and the Firestore user document.
  Future<void> updateUserProfile({String? displayName, String? photoUrl});

  // Stream the full AppUser document from persistent storage for [userId].
  Stream<AppUser?> watchUser(String userId);

  // One-shot fetch of any user's display name — used by Market tile to show creator.
  Future<String?> getUserDisplayName(String userId);
}
