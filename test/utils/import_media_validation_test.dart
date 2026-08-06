// Tests for import media validation (#330) — the pre-flight check that stops an
// imported archive from attempting a Storage write the rules will refuse.
//
// storage.rules requires BOTH of:
//   request.resource.size < 10 * 1024 * 1024
//   request.resource.contentType.matches('image/.*|audio/.*')
// so anything failing either check is guaranteed to be rejected mid-import.
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/import_media_validation.dart';
import 'package:test/test.dart';

void main() {
  const max = AppConstants.maxMediaUploadBytes;

  group('mediaContentTypeForPath', () {
    test('maps every supported extension to its MIME type', () {
      const expected = {
        'media/a.jpg': 'image/jpeg',
        'media/a.jpeg': 'image/jpeg',
        'media/a.png': 'image/png',
        'media/a.webp': 'image/webp',
        'media/a.mp3': 'audio/mpeg',
        'media/a.aac': 'audio/aac',
        'media/a.m4a': 'audio/mp4',
      };
      expected.forEach((path, mime) {
        expect(mediaContentTypeForPath(path), mime, reason: 'for $path');
      });
    });

    test('is case-insensitive', () {
      expect(mediaContentTypeForPath('media/A.JPG'), 'image/jpeg');
      expect(mediaContentTypeForPath('media/b.PnG'), 'image/png');
    });

    test('returns null for a supported-looking but unlisted type', () {
      expect(mediaContentTypeForPath('media/a.bmp'), isNull);
      expect(mediaContentTypeForPath('media/a.svg'), isNull);
      expect(mediaContentTypeForPath('media/a.wav'), isNull);
    });

    test('returns null when no usable extension survives sanitizing', () {
      expect(mediaContentTypeForPath('media/noextension'), isNull);
      expect(mediaContentTypeForPath('media/a.jpg/../../evil'), isNull);
      expect(mediaContentTypeForPath('media/a.'), isNull);
      expect(mediaContentTypeForPath(''), isNull);
    });
  });

  group('supportedMediaContentTypes', () {
    // Encodes the storage.rules contentType clause directly: if a type were
    // ever added here that the rules refuse, import would fail mid-write again.
    test('every declared type satisfies the storage.rules contentType clause',
        () {
      for (final mime in supportedMediaContentTypes.values) {
        expect(
          mime.startsWith('image/') || mime.startsWith('audio/'),
          isTrue,
          reason: '$mime is neither image/* nor audio/*, so storage.rules '
              'would reject it',
        );
      }
    });
  });

  group('validateImportMedia', () {
    test('accepts a supported type within the size limit', () {
      expect(
        validateImportMedia(path: 'media/a.jpg', sizeBytes: 1024),
        isNull,
      );
    });

    test('flags an unsupported type', () {
      final issue = validateImportMedia(path: 'media/a.bmp', sizeBytes: 1024);
      expect(issue, isNotNull);
      expect(issue!.kind, MediaIssueKind.unsupportedType);
      expect(issue.path, 'media/a.bmp');
    });

    test('flags a supported type that exceeds the size limit', () {
      final issue =
          validateImportMedia(path: 'media/a.jpg', sizeBytes: max + 1);
      expect(issue, isNotNull);
      expect(issue!.kind, MediaIssueKind.tooLarge);
      expect(issue.sizeBytes, max + 1);
    });

    test('reports unsupported type ahead of size when both are wrong', () {
      // Shrinking the file would not make a .bmp uploadable, so the type is
      // the actionable problem to surface first.
      final issue =
          validateImportMedia(path: 'media/a.bmp', sizeBytes: max + 1);
      expect(issue!.kind, MediaIssueKind.unsupportedType);
    });

    test('treats the limit as exclusive, matching storage.rules', () {
      // The rule is `size < 10MB`, so exactly the limit must be rejected.
      expect(
        validateImportMedia(path: 'media/a.jpg', sizeBytes: max - 1),
        isNull,
        reason: 'one byte under the cap is fine',
      );
      expect(
        validateImportMedia(path: 'media/a.jpg', sizeBytes: max)?.kind,
        MediaIssueKind.tooLarge,
        reason: 'rules use `<`, so exactly the cap is refused',
      );
    });

    test('accepts a zero-byte file of a supported type', () {
      // Odd but not a rules violation — it should not be reported as an issue.
      expect(validateImportMedia(path: 'media/a.mp3', sizeBytes: 0), isNull);
    });
  });
}
