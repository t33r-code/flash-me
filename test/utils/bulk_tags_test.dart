import 'package:flutter_test/flutter_test.dart';
import 'package:flash_me/utils/bulk_tags.dart';

void main() {
  group('tagPresence', () {
    test('a tag on every card is `all`', () {
      final presence = tagPresence([
        ['spanish'],
        ['spanish'],
      ]);
      expect(presence['spanish'], TagPresence.all);
    });

    test('a tag on only some cards is `some`', () {
      final presence = tagPresence([
        ['spanish', 'irregular'],
        ['spanish'],
      ]);
      expect(presence['spanish'], TagPresence.all);
      expect(presence['irregular'], TagPresence.some);
    });

    test('only reports tags that appear somewhere', () {
      final presence = tagPresence([
        ['a'],
        ['b'],
      ]);
      expect(presence.keys.toSet(), {'a', 'b'});
      expect(presence['zz'], isNull);
    });

    test('normalises tags so casing/spacing collapse together', () {
      final presence = tagPresence([
        ['Spanish Verbs'],
        ['spanish-verbs'],
      ]);
      expect(presence, {'spanish-verbs': TagPresence.all});
    });

    test('a single card makes all its tags `all`', () {
      final presence = tagPresence([
        ['a', 'b'],
      ]);
      expect(presence, {'a': TagPresence.all, 'b': TagPresence.all});
    });

    test('no cards yields no tags', () {
      expect(tagPresence(const []), isEmpty);
    });

    test('cards with no tags yield no tags', () {
      expect(
          tagPresence([
            <String>[],
            <String>[],
          ]),
          isEmpty);
    });

    test('blank tags are discarded', () {
      final presence = tagPresence([
        ['  ', 'a'],
      ]);
      expect(presence, {'a': TagPresence.all});
    });
  });

  group('applyTagDelta', () {
    test('adds a new tag at the end', () {
      expect(applyTagDelta(['a'], {'b'}, {}), ['a', 'b']);
    });

    test('removes a tag', () {
      expect(applyTagDelta(['a', 'b'], {}, {'a'}), ['b']);
    });

    test('adds and removes in one pass', () {
      expect(applyTagDelta(['a', 'b'], {'c'}, {'a'}), ['b', 'c']);
    });

    test('adding an existing tag does not duplicate it', () {
      expect(applyTagDelta(['a'], {'a'}, {}), ['a']);
    });

    test('normalises added tags', () {
      expect(applyTagDelta([], {'Spanish Verbs'}, {}), ['spanish-verbs']);
    });

    test('normalises removals so casing still matches', () {
      expect(applyTagDelta(['spanish-verbs'], {}, {'Spanish Verbs'}), isEmpty);
    });

    test('normalises pre-existing tags on the card', () {
      expect(applyTagDelta(['Spanish Verbs'], {}, {}), ['spanish-verbs']);
    });

    test('remove wins when a tag is both added and removed', () {
      expect(applyTagDelta(['a'], {'a'}, {'a'}), isEmpty);
    });

    test('drops blank tags', () {
      expect(applyTagDelta(['  ', 'a'], {}, {}), ['a']);
    });

    test('existing duplicates collapse', () {
      expect(applyTagDelta(['a', 'A'], {}, {}), ['a']);
    });

    test('no delta leaves the list as-is', () {
      expect(applyTagDelta(['a', 'b'], {}, {}), ['a', 'b']);
    });
  });
}
