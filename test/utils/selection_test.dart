import 'package:flutter_test/flutter_test.dart';
import 'package:flash_me/utils/selection.dart';

void main() {
  const ordered = ['a', 'b', 'c', 'd', 'e'];

  group('idsInRange', () {
    test('anchor before target selects the inclusive span', () {
      expect(idsInRange(ordered, 'b', 'd'), {'b', 'c', 'd'});
    });

    test('anchor after target selects the same span (direction-agnostic)', () {
      expect(idsInRange(ordered, 'd', 'b'), {'b', 'c', 'd'});
    });

    test('anchor equal to target selects just that id', () {
      expect(idsInRange(ordered, 'c', 'c'), {'c'});
    });

    test('spanning the whole list selects everything', () {
      expect(idsInRange(ordered, 'a', 'e'), ordered.toSet());
    });

    test('missing anchor returns empty so the caller can fall back', () {
      expect(idsInRange(ordered, 'zz', 'c'), isEmpty);
    });

    test('missing target returns empty', () {
      expect(idsInRange(ordered, 'a', 'zz'), isEmpty);
    });

    test('empty list returns empty', () {
      expect(idsInRange(const [], 'a', 'b'), isEmpty);
    });
  });

  group('toggleId', () {
    test('adds an absent id', () {
      expect(toggleId({'a'}, 'b'), {'a', 'b'});
    });

    test('removes a present id', () {
      expect(toggleId({'a', 'b'}, 'b'), {'a'});
    });

    test('does not mutate the input', () {
      final original = {'a'};
      toggleId(original, 'b');
      expect(original, {'a'});
    });
  });

  group('pruneSelection', () {
    test('drops ids no longer visible', () {
      expect(pruneSelection({'a', 'b', 'c'}, ['a', 'c']), {'a', 'c'});
    });

    test('keeps everything when all are visible', () {
      expect(pruneSelection({'a', 'b'}, ordered), {'a', 'b'});
    });

    test('empty when nothing is visible', () {
      expect(pruneSelection({'a', 'b'}, const []), isEmpty);
    });
  });
}
