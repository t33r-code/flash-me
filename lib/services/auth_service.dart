import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Register with email and password
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Registering user with email: $email');
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      _logger.e('Registration failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Signing in with email: $email');
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _logger.e('Sign in failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Sign in with Google (disabled - google_sign_in v7.2.0 API needs update)
  /// TODO: Update this after resolving google_sign_in 7.2.0 API compatibility
  Future<UserCredential?> signInWithGoogle() async {
    _logger.w('Google Sign-In not yet implemented for this version');
    return null;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _logger.i('Signing out');
      await _firebaseAuth.signOut();
    } catch (e) {
      _logger.e('Sign out failed: $e');
      rethrow;
    }
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        _logger.i('Creating new user document for ${user.uid}');
        await userDoc.set({
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'createdAt': Timestamp.now(),
          'lastLoginAt': Timestamp.now(),
        });
      } else {
        // Update last login
        await userDoc.update({
          'lastLoginAt': Timestamp.now(),
        });
      }
    } catch (e) {
      _logger.e('Failed to create/update user document: $e');
      rethrow;
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      if (currentUser != null && !currentUser!.emailVerified) {
        _logger.i('Sending email verification to ${currentUser!.email}');
        await currentUser!.sendEmailVerification();
      }
    } catch (e) {
      _logger.e('Failed to send email verification: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      _logger.i('Sending password reset email to $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      _logger.e('Failed to send password reset email: $e');
      rethrow;
    }
  }
}
