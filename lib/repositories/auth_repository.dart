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

  Future<void> sendEmailVerification();

  Future<void> resetPassword(String email);

  // --- User profile operations -----------------------------------------------

  // Update display name / photo in both auth and the Firestore user document.
  Future<void> updateUserProfile({String? displayName, String? photoUrl});

  // Stream the full AppUser document from persistent storage for [userId].
  Stream<AppUser?> watchUser(String userId);
}
