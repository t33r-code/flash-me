import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/user.dart';
import 'package:flash_me/services/auth_service.dart';
import 'package:flash_me/utils/constants.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authServiceProvider).currentUser;
});

/// Streams the Firestore AppUser document for the currently signed-in user.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
});
