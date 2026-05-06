import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/user.dart';
import 'package:flash_me/repositories/auth_repository.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

// Firebase + Google Sign-In implementation of AuthRepository.
// All firebase_auth and google_sign_in calls are isolated here.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Map Firebase User? → uid String? so the rest of the app stays provider-agnostic.
  @override
  Stream<String?> get authStateChanges =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  // --- Auth operations -------------------------------------------------------

  @override
  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Registering user: $email');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) await _createUserDocument(credential.user!);
    } on FirebaseAuthException catch (e) {
      _logger.e('Registration failed: ${e.code}');
      throw AppException(e.message ?? 'Registration failed', code: e.code);
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Signing in: $email');
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      _logger.e('Sign-in failed: ${e.code}');
      throw AppException(e.message ?? 'Sign-in failed', code: e.code);
    }
  }

  // google_sign_in v7: singleton pattern, authenticate() not signIn().
  // Returns false if the user cancelled — not treated as an error.
  @override
  Future<bool> signInWithGoogle() async {
    try {
      _logger.i('Starting Google Sign-In');
      final googleAccount = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: googleAccount.authentication.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      _logger.e('Google sign-in failed: ${e.code}');
      throw AppException('Google sign-in failed', code: e.code.toString());
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase auth failed after Google sign-in: ${e.code}');
      throw AppException(e.message ?? 'Sign-in failed', code: e.code);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      _logger.i('Signing out');
      await Future.wait([
        _auth.signOut(),
        GoogleSignIn.instance.signOut(),
      ]);
    } catch (e) {
      _logger.e('Sign-out failed: $e');
      throw AppException('Sign-out failed', code: 'sign-out-failed');
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } catch (e) {
      _logger.e('Email verification failed: $e');
      throw AppException('Failed to send verification email');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      _logger.i('Sending password reset to $email');
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AppException(e.message ?? 'Password reset failed', code: e.code);
    }
  }

  // --- User profile operations -----------------------------------------------

  @override
  Future<void> updateUserProfile({String? displayName, String? photoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoUrl);
      // Mirror changes to the Firestore user document.
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({'displayName': displayName, 'photoUrl': photoUrl});
    } catch (e) {
      _logger.e('Profile update failed: $e');
      throw AppException('Failed to update profile', code: 'update-profile-failed');
    }
  }

  // Stream the Firestore user document; used by appUserProvider.
  @override
  Stream<AppUser?> watchUser(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  // --- Private helpers --------------------------------------------------------

  // Create the Firestore user document on first sign-in; update lastLoginAt on repeat.
  Future<void> _createUserDocument(User user) async {
    try {
      final ref = _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid);
      final doc = await ref.get();
      if (!doc.exists) {
        _logger.i('Creating Firestore user document for ${user.uid}');
        await ref.set({
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'createdAt': Timestamp.now(),
          'lastLoginAt': Timestamp.now(),
        });
      } else {
        await ref.update({'lastLoginAt': Timestamp.now()});
      }
    } catch (e) {
      _logger.e('Failed to create/update user document: $e');
      rethrow;
    }
  }
}
