import 'dart:typed_data';

// Provider-agnostic contract for binary file storage (images, audio clips).
// The Firebase Storage implementation lives in repositories/firebase/.
// Swap to S3 or another provider by writing a new implementation class.
abstract class StorageRepository {
  // Upload [bytes] to [path] and return the public download URL.
  // [contentType] is the MIME type, e.g. 'image/jpeg', 'audio/mpeg'.
  Future<String> uploadFile({
    required String path,
    required Uint8List bytes,
    String? contentType,
  });

  // Delete the file at [path]. No-ops silently if the file does not exist.
  Future<void> deleteFile(String path);

  // Return the download URL for an existing file at [path].
  Future<String> getDownloadUrl(String path);
}
