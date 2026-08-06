import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/helpers.dart';

// ---------------------------------------------------------------------------
// Import media validation (#330).
//
// storage.rules refuses any upload that fails EITHER of:
//   request.resource.size < 10 * 1024 * 1024
//   request.resource.contentType.matches('image/.*|audio/.*')
//
// Media inside an import archive was previously uploaded without checking
// either, so an oversized or unsupported file was rejected by Storage part-way
// through execute() — after sets and cards had already been written, leaving a
// half-finished import behind an opaque error.
//
// This is the single source of truth for both the pre-flight check in
// analyze() and the content type declared at upload time. Keeping them on one
// allowlist is the point: if validation and upload disagreed about which types
// are acceptable, the same mid-import failure would return.
// ---------------------------------------------------------------------------

// Extensions import can upload, mapped to the content type Storage is told.
// Every value must satisfy the rules' `image/.*|audio/.*` clause.
const Map<String, String> supportedMediaContentTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'mp3': 'audio/mpeg',
  'aac': 'audio/aac',
  'm4a': 'audio/mp4',
};

// Content type for an archive entry path, or null when the extension is
// unsupported or nothing usable survives sanitizing. Takes the whole path
// rather than a pre-split extension so callers cannot derive it differently
// (the sanitizing step is what keeps an untrusted entry name from reshaping
// the Storage object path — see AppHelpers.sanitizeFileExtension, #300 F4).
String? mediaContentTypeForPath(String path) {
  if (!path.contains('.')) return null;
  final ext = AppHelpers.sanitizeFileExtension(path.split('.').last);
  if (ext.isEmpty) return null;
  return supportedMediaContentTypes[ext];
}

// Why a media entry cannot be uploaded.
enum MediaIssueKind {
  // Extension maps to no content type Storage would accept.
  unsupportedType,
  // Over AppConstants.maxMediaUploadBytes.
  tooLarge,
}

// One unusable media entry, reported in the import preview.
class MediaIssue {
  final String path;
  final MediaIssueKind kind;
  final int sizeBytes;

  const MediaIssue({
    required this.path,
    required this.kind,
    required this.sizeBytes,
  });
}

// Check one archive media entry against the Storage rules. Returns null when
// the entry is uploadable.
//
// [sizeBytes] is the entry's uncompressed size, available from ArchiveFile.size
// without reading (and inflating) its content.
MediaIssue? validateImportMedia({
  required String path,
  required int sizeBytes,
}) {
  // Type first: shrinking a .bmp would not make it uploadable, so an
  // unsupported type is the actionable problem to report.
  if (mediaContentTypeForPath(path) == null) {
    return MediaIssue(
      path: path,
      kind: MediaIssueKind.unsupportedType,
      sizeBytes: sizeBytes,
    );
  }
  // The rule is `size < limit`, so exactly the limit is refused.
  if (sizeBytes >= AppConstants.maxMediaUploadBytes) {
    return MediaIssue(
      path: path,
      kind: MediaIssueKind.tooLarge,
      sizeBytes: sizeBytes,
    );
  }
  return null;
}
