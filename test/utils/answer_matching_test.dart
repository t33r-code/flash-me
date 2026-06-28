import 'package:flash_me/utils/helpers.dart';
import 'package:test/test.dart';

void main() {
  // Convenience wrapper — mirrors the AppHelpers.isAnswerCorrect signature.
  bool check(String input, List<String> accepted, {bool exact = false}) =>
      AppHelpers.isAnswerCorrect(input, accepted, exact: exact);

  group('isAnswerCorrect — basics', () {
    test('exact match always passes', () {
      expect(check('casa', ['casa']), isTrue);
    });

    test('case insensitivity always applied', () {
      expect(check('Casa', ['casa']), isTrue);
      expect(check('CASA', ['CASA']), isTrue);
    });

    test('leading/trailing whitespace stripped', () {
      expect(check('  casa  ', ['casa']), isTrue);
    });

    test('empty input never matches', () {
      expect(check('', ['casa']), isFalse);
      expect(check('   ', ['casa']), isFalse);
    });

    test('matches any entry in accepted list', () {
      expect(check('home', ['casa', 'home', 'house']), isTrue);
    });

    test('wrong answer fails', () {
      expect(check('perro', ['casa']), isFalse);
    });
  });

  group('isAnswerCorrect — diacritic forgiveness', () {
    test('missing umlaut accepted', () {
      expect(check('mude', ['müde']), isTrue);
    });

    test('missing acute accepted', () {
      expect(check('cafe', ['café']), isTrue);
    });

    test('missing tilde accepted', () {
      expect(check('manana', ['mañana']), isTrue);
    });

    test('missing cedilla accepted', () {
      expect(check('garcon', ['garçon']), isTrue);
    });

    test('correct diacritic also passes', () {
      expect(check('müde', ['müde']), isTrue);
      expect(check('café', ['café']), isTrue);
    });
  });

  group('isAnswerCorrect — typo tolerance (exact: false)', () {
    test('single-char substitution forgiven for longer word', () {
      // "hablo" → "habло" (typo in 5-char word): threshold is 1
      expect(check('hablos', ['hablo']), isTrue);  // 1 insertion
    });

    test('single-char deletion forgiven for mid-length word', () {
      expect(check('hblo', ['hablo']), isTrue);  // 1 deletion in 5-char word
    });

    test('no typo tolerance for 2-char words', () {
      expect(check('ab', ['ac']), isFalse);  // len 2, threshold 0
    });

    test('no typo tolerance for 1-char words', () {
      expect(check('a', ['e']), isFalse);
    });

    test('completely wrong long word fails even with tolerance', () {
      expect(check('perro', ['gato']), isFalse);  // distance 5, threshold 1
    });
  });

  group('isAnswerCorrect — exact: true', () {
    test('diacritic forgiveness still applied', () {
      // exactMatch gates typo tolerance only; diacritics always forgiven
      expect(check('cafe', ['café'], exact: true), isTrue);
    });

    test('case insensitivity still applied', () {
      expect(check('CASA', ['casa'], exact: true), isTrue);
    });

    test('single-char typo not forgiven', () {
      expect(check('hablos', ['hablo'], exact: true), isFalse);
    });
  });
}