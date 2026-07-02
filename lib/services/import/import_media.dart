part of '../import_service.dart';

// ---------------------------------------------------------------------------
// Media handling — upload files from the ZIP archive to Firebase Storage.
// ---------------------------------------------------------------------------

// Upload a media file from the archive to Firebase Storage.
// Returns the download URL, or null if [path] is null or the file is missing.
Future<String?> _uploadMedia(
  Archive archive,
  String? path,
  String userId,
) async {
  if (path == null) return null;
  final file = archive.findFile(path);
  if (file == null) return null;

  final bytes = Uint8List.fromList(file.content as List<int>);
  final ext = path.contains('.') ? path.split('.').last : '';
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
  final ref = FirebaseStorage.instance
      .ref()
      .child('users/$userId/cards/$fileName');

  final contentType = _contentType(ext);
  final metadata =
      contentType != null ? SettableMetadata(contentType: contentType) : null;
  final task = metadata != null
      ? ref.putData(bytes, metadata)
      : ref.putData(bytes);
  await task;
  return await ref.getDownloadURL();
}

// Map a file extension to its MIME content type for Storage metadata.
String? _contentType(String ext) {
  switch (ext.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'mp3':
      return 'audio/mpeg';
    case 'aac':
      return 'audio/aac';
    case 'm4a':
      return 'audio/mp4';
    default:
      return null;
  }
}