import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/set_acquisition.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/repositories/firebase/firebase_set_acquisition_repository.dart';
import 'package:flash_me/repositories/set_acquisition_repository.dart';
import 'package:flash_me/utils/constants.dart';

// Bind the abstract SetAcquisitionRepository to its Firebase implementation.
final setAcquisitionRepositoryProvider = Provider<SetAcquisitionRepository>(
  (ref) => FirebaseSetAcquisitionRepository(),
);

// Streams the current user's acquisitions as a map from originalSetId to the
// acquisition record. Used by Market tiles to show "Cloned on …" badges.
// The (acquiredByUserId, acquiredAt DESC) index covers this query.
final userAcquisitionsProvider =
    StreamProvider<Map<String, SetAcquisition>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value({});
  return FirebaseFirestore.instance
      .collection(AppConstants.setAcquisitionsCollection)
      .where('acquiredByUserId', isEqualTo: uid)
      .orderBy('acquiredAt', descending: true)
      .snapshots()
      .map((snap) => {
            for (final doc in snap.docs)
              (doc.data()['originalSetId'] as String):
                  SetAcquisition.fromFirestore(doc),
          });
});
