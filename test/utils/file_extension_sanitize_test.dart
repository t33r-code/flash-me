// Tests for AppHelpers.sanitizeFileExtension - the guard that stops an
// untrusted ZIP entry's extension from reshaping a Firebase Storage object
// path on import (#300 F4).
import 'package:flash_me/utils/helpers.dart';
import 'package:test/test.dart';

void main() {
  String sanitize(String raw) => AppHelpers.sanitizeFileExtension(raw);

  group('accepts ordinary extensions', () {
    test('keeps the media types import actually supports', () {
      for (final ext in ['jpg', 'jpeg', 'png', 'webp', 'mp3', 'aac', 'm4a']) {
        expect(sanitize(ext), ext, reason: '\$ext should survive unchanged');
      }
    });

    test('lowercases so content-type lookup still matches', () {
      expect(sanitize('JPG'), 'jpg');
      expect(sanitize('PnG'), 'png');
    });

    test('allows digits', () {
      expect(sanitize('mp3'), 'mp3');
      expect(sanitize('3gp'), '3gp');
    });
  });

  group('rejects anything that could reshape the storage path', () {
    test('path separators', () {
      expect(sanitize('jpg/../../evil'), '');
      expect(sanitize(r'jpg\..\evil'), '');
      expect(sanitize('a/b'), '');
    });

    test('dots, which would otherwise nest or traverse', () {
      expect(sanitize('.'), '');
      expect(sanitize('..'), '');
      expect(sanitize('jpg.exe'), '');
    });

    test('whitespace and control characters', () {
      expect(sanitize('jpg '), '');
      expect(sanitize('j pg'), '');
      expect(sanitize('jpg\n'), '');
      expect(sanitize('jpg\t'), '');
      expect(sanitize('jpg\x00'), '');
    });

    test('punctuation and shell-ish characters', () {
      expect(sanitize('jp-g'), '');
      expect(sanitize('jp_g'), '');
      expect(sanitize(r'jpg$('), '');
      expect(sanitize('jpg?x=1'), '');
    });

    test('empty input', () {
      expect(sanitize(''), '');
    });

    test('over-long input is rejected rather than truncated', () {
      // Truncating would silently invent a different extension; refusing keeps
      // the caller on its extension-less path instead.
      expect(sanitize('a' * 11), '');
      expect(sanitize('a' * 10), 'a' * 10, reason: '10 is the boundary');
    });
  });
}
