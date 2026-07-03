import 'package:flash_me/utils/helpers.dart';
import 'package:test/test.dart';

// Tests for AppHelpers.parseDistractorCsv — the CSV distractor entry parser
// used by the fill-in-the-blanks and grid question editors (#209).
void main() {
  // Convenience wrapper — most tests don't exercise the questionWords overlap.
  List<String> parse(String csv,
          {List<String> existing = const [], Set<String> question = const {}}) =>
      AppHelpers.parseDistractorCsv(csv, existing, question);

  group('parseDistractorCsv — parsing', () {
    test('single word returns that word', () {
      expect(parse('perro'), ['perro']);
    });

    test('splits on commas and trims whitespace', () {
      expect(parse('perro, gato ,  pez'), ['perro', 'gato', 'pez']);
    });

    test('empty and whitespace-only entries are dropped', () {
      expect(parse('perro, , ,gato,   '), ['perro', 'gato']);
    });

    test('empty string yields nothing', () {
      expect(parse(''), isEmpty);
      expect(parse('   '), isEmpty);
      expect(parse(', ,'), isEmpty);
    });

    test('original casing is preserved for kept words', () {
      expect(parse('Perro, GATO'), ['Perro', 'GATO']);
    });
  });

  group('parseDistractorCsv — deduplication', () {
    test('duplicate entries within the CSV are deduped (first casing wins)', () {
      expect(parse('perro, gato, perro'), ['perro', 'gato']);
    });

    test('dedupe is case-insensitive', () {
      expect(parse('Perro, perro, PERRO'), ['Perro']);
    });

    test('words already in existing distractors are dropped', () {
      expect(parse('perro, gato', existing: ['perro']), ['gato']);
    });

    test('existing-distractor match is case-insensitive', () {
      expect(parse('PERRO, gato', existing: ['perro']), ['gato']);
    });
  });

  group('parseDistractorCsv — question overlap', () {
    test('words already in the question text are dropped', () {
      // questionWords must be supplied lowercased.
      expect(parse('perro, gato', question: {'gato'}), ['perro']);
    });

    test('overlap match is case-insensitive', () {
      expect(parse('Gato, Perro', question: {'gato'}), ['Perro']);
    });

    test('everything filtered out yields an empty list', () {
      expect(
        parse('perro, gato',
            existing: ['perro'], question: {'gato'}),
        isEmpty,
      );
    });

    test('combines all three filters in one pass', () {
      // casa=question, gato=existing, pez repeated in CSV → only perro, ave kept
      expect(
        parse('casa, gato, perro, pez, PEZ, ave',
            existing: ['gato'], question: {'casa'}),
        ['perro', 'pez', 'ave'],
      );
    });
  });
}