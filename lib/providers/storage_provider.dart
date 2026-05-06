import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/repositories/storage_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_storage_repository.dart';

// Bind the abstract StorageRepository to its Firebase Storage implementation.
// Used for uploading/downloading card media (images, audio clips).
final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => FirebaseStorageRepository(),
);
