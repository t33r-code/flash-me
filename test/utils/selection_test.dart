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

  group('SelectionModel', () {
    test('starts out of selection mode and empty', () {
      final sel = SelectionModel();
      expect(sel.mode, isFalse);
      expect(sel.isEmpty, isTrue);
      expect(sel.anchor, isNull);
    });

    test('enterWith turns on mode and picks the one id as anchor', () {
      final sel = SelectionModel()..enterWith('b');
      expect(sel.mode, isTrue);
      expect(sel.selected, {'b'});
      expect(sel.anchor, 'b');
    });

    test('toggle adds, removes, and moves the anchor', () {
      final sel = SelectionModel()..enterWith('a');
      sel.toggle('c');
      expect(sel.selected, {'a', 'c'});
      expect(sel.anchor, 'c');
      sel.toggle('a');
      expect(sel.selected, {'c'});
    });

    test('emptying the selection stays in selection mode', () {
      final sel = SelectionModel()..enterWith('a');
      sel.toggle('a');
      expect(sel.isEmpty, isTrue);
      expect(sel.mode, isTrue, reason: 'only exit() leaves selection mode');
    });

    test('exit clears mode, selection and anchor', () {
      final sel = SelectionModel()..enterWith('a');
      sel.exit();
      expect(sel.mode, isFalse);
      expect(sel.isEmpty, isTrue);
      expect(sel.anchor, isNull);
    });

    test('extendTo unions the span without dropping earlier picks', () {
      final sel = SelectionModel()..enterWith('a');
      sel.toggle('c'); // anchor now c
      sel.extendTo('e', ordered);
      // 'a' survives even though it is outside the c→e span.
      expect(sel.selected, {'a', 'c', 'd', 'e'});
    });

    test('extendTo falls back to a toggle with no anchor', () {
      final sel = SelectionModel()
        ..mode = true
        ..selected = {'a'};
      sel.extendTo('c', ordered);
      expect(sel.selected, {'a', 'c'});
    });

    test('extendTo falls back to a toggle when the anchor is gone', () {
      final sel = SelectionModel()..enterWith('zz'); // not in `ordered`
      sel.extendTo('c', ordered);
      expect(sel.selected, {'zz', 'c'});
    });

    test('toggleSelectAll selects everything, then clears', () {
      final sel = SelectionModel()..mode = true;
      sel.toggleSelectAll(ordered);
      expect(sel.selected, ordered.toSet());
      sel.toggleSelectAll(ordered);
      expect(sel.isEmpty, isTrue);
    });

    test('toggleSelectAll on an empty list is a no-op', () {
      final sel = SelectionModel()..mode = true;
      sel.toggleSelectAll(const []);
      expect(sel.isEmpty, isTrue);
    });

    test('prune drops hidden ids and clears a stale anchor', () {
      final sel = SelectionModel()..enterWith('a');
      sel.toggle('b'); // anchor b
      sel.prune(['a']); // b filtered away
      expect(sel.selected, {'a'});
      expect(sel.anchor, isNull);
    });

    test('prune keeps a still-visible anchor', () {
      final sel = SelectionModel()..enterWith('a');
      sel.prune(['a', 'b']);
      expect(sel.anchor, 'a');
    });
  });
}
