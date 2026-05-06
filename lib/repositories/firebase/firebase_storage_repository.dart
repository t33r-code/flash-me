import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/repositories/storage_repository.dart';
import 'package:flash_me/utils/exceptions.dart';

// Firebase Storage implementation of StorageRepository.
// All firebase_storage calls are isolated here.
class FirebaseStorageRepository implements StorageRepository {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();

  @override
  Future<String> uploadFile({
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    try {
      final ref = _storage.ref(path);
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();
      _logger.i('Uploaded file to $path');
      return url;
    } catch (e) {
      _logger.e('Upload failed for $path: $e');
      throw AppException('Failed to upload file', code: 'upload-failed');
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    try {
      await _storage.ref(path).delete();
      _logger.i('Deleted file at $path');
    } on FirebaseException catch (e) {
      // Treat "object not found" as a no-op — already deleted.
      if (e.code == 'object-not-found') return;
      _logger.e('Delete failed for $path: $e');
      throw AppException('Failed to delete file', code: 'delete-failed');
    }
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    try {
      return await _storage.ref(path).getDownloadURL();
    } catch (e) {
      _logger.e('Failed to get download URL for $path: $e');
      throw AppException('Failed to get file URL', code: 'url-failed');
    }
  }
}
