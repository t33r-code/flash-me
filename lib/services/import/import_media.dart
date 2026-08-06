part of '../import_service.dart';

// ---------------------------------------------------------------------------
// Media handling — upload files from the ZIP archive to Firebase Storage.
// ---------------------------------------------------------------------------

// Upload a media file from the archive to Firebase Storage.
// Returns the download URL, or null if [path] is null, the file is missing, or
// the entry cannot be uploaded (#330).
//
// Skipping rather than throwing is deliberate: analyze() has already reported
// these entries in the import preview, so the user has seen them. Failing here
// would abort execute() part-way, leaving sets and cards already written — the
// exact partial-import state this check exists to prevent. The card is
// imported without its media instead.
Future<String?> _uploadMedia(
  Archive archive,
  String? path,
  String userId,
) async {
  if (path == null) return null;
  final file = archive.findFile(path);
  if (file == null) return null;

  // Uses the entry's declared size, so an oversized file is rejected before
  // its content is inflated into memory.
  if (validateImportMedia(path: path, sizeBytes: file.size) != null) {
    return null;
  }

  // Non-null for anything that passed validation above.
  final contentType = mediaContentTypeForPath(path)!;
  final bytes = Uint8List.fromList(file.content as List<int>);
  final ext = AppHelpers.sanitizeFileExtension(path.split('.').last);
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
  final ref = FirebaseStorage.instance
      .ref()
      .child('users/$userId/cards/$fileName');

  await ref.putData(bytes, SettableMetadata(contentType: contentType));
  return await ref.getDownloadURL();
}
