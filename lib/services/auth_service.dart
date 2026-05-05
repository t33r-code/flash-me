import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

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
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _logger.e('Registration failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

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

  // google_sign_in v7: uses GoogleSignIn.instance.authenticate() — no constructor.
  // authentication getter is synchronous and provides only idToken (accessToken
  // moved to authorizationClient, but idToken alone is sufficient for Firebase).
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _logger.i('Starting Google Sign-In');
      final googleAccount = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: googleAccount.authentication.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }
      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      _logger.e('Google sign-in failed: ${e.code} - ${e.description}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase auth failed after Google sign-in: ${e.code}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _logger.i('Signing out');
      await Future.wait([
        _firebaseAuth.signOut(),
        GoogleSignIn.instance.signOut(),
      ]);
    } catch (e) {
      _logger.e('Sign out failed: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile({String? displayName, String? photoUrl}) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoUrl);
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': displayName,
        'photoUrl': photoUrl,
      });
    } catch (e) {
      _logger.e('Failed to update user profile: $e');
      rethrow;
    }
  }

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

  Future<void> resetPassword(String email) async {
    try {
      _logger.i('Sending password reset email to $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      _logger.e('Failed to send password reset email: $e');
      rethrow;
    }
  }

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
        await userDoc.update({'lastLoginAt': Timestamp.now()});
      }
    } catch (e) {
      _logger.e('Failed to create/update user document: $e');
      rethrow;
    }
  }
}
