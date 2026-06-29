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

    test('Czech háček stripped (č š ž ř)', () {
      expect(check('rericha', ['řeřicha']), isTrue);
      expect(check('zlutoucky', ['žluťoučký']), isTrue);
    });

    test('Polish diacritics stripped (ł ą ż)', () {
      expect(check('zolw', ['żółw']), isTrue);
      expect(check('maka', ['mąka']), isTrue);
    });

    test('Romanian comma-below stripped (ș ț)', () {
      expect(check('si', ['și']), isTrue);
    });
  });

  group('isAnswerCorrect — typo tolerance (exact: false)', () {
    test('single vowel-for-vowel swap forgiven', () {
      // "hablo" → "habla": one vowel substituted, same length → accepted.
      expect(check('habla', ['hablo']), isTrue);
    });

    test('single consonant substitution NOT forgiven', () {
      // "hablo" → "hadlo": b→d is a consonant change → rejected.
      expect(check('hadlo', ['hablo']), isFalse);
    });

    test('insertion at the boundary NOT forgiven', () {
      // Length change at the tolerance edge is a real error now.
      expect(check('hablos', ['hablo']), isFalse);
    });

    test('deletion at the boundary NOT forgiven', () {
      expect(check('hblo', ['hablo']), isFalse);
    });

    test('two edits never forgiven', () {
      // "pracuju" → "pracu": distance 2 → rejected even for a long word.
      expect(check('praču', ['pracuju']), isFalse);
    });

    test('no typo tolerance for 2-char words', () {
      expect(check('ab', ['ac']), isFalse);  // len 2, threshold 0
    });

    test('no typo tolerance for 1-char words', () {
      expect(check('a', ['e']), isFalse);
    });

    test('completely wrong long word fails', () {
      expect(check('perro', ['gato']), isFalse);
    });
  });

  group('isAnswerCorrect — consonant-weighted matching (pračuju example)', () {
    // Real-world tuning case: expected answer "pračuju" (normalises to
    // "pracuju"). Vowel near-misses pass; consonant near-misses do not.
    test('exact answer passes', () {
      expect(check('pračuju', ['pračuju']), isTrue);
    });

    test('missing diacritic passes', () {
      expect(check('pracuju', ['pračuju']), isTrue);
    });

    test('final vowel swap passes', () {
      expect(check('pračuje', ['pračuju']), isTrue);
    });

    test('medial vowel swap passes', () {
      expect(check('pračeju', ['pračuju']), isTrue);
    });

    test('truncation (two deletions) fails', () {
      expect(check('praču', ['pračuju']), isFalse);
    });

    test('consonant substitution fails', () {
      expect(check('pračubu', ['pračuju']), isFalse);
    });

    test('vowel-for-consonant substitution fails', () {
      // "pračuuu": the u replaces the consonant j → consonant identity lost.
      expect(check('pračuuu', ['pračuju']), isFalse);
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