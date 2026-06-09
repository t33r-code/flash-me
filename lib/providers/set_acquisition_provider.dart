import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/repositories/firebase/firebase_set_acquisition_repository.dart';
import 'package:flash_me/repositories/set_acquisition_repository.dart';

// Bind the abstract SetAcquisitionRepository to its Firebase implementation.
final setAcquisitionRepositoryProvider = Provider<SetAcquisitionRepository>(
  (ref) => FirebaseSetAcquisitionRepository(),
);
