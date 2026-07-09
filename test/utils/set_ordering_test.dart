import 'package:flash_me/models/set_card.dart';
import 'package:flash_me/utils/set_ordering.dart';
import 'package:test/test.dart';

void main() {
  // Builds a SetCard whose cardId doubles as an identity marker.
  // addedAt is spaced by index only to look realistic; the sort ignores its
  // value and relies on the list already being in addedAt order.
  SetCard sc(String cardId, {int? position, int index = 0}) => SetCard(
        id: 'link-$cardId',
        setId: 'set-1',
        cardId: cardId,
        userId: 'user-1',
        addedAt: DateTime(2024, 1, 1).add(Duration(minutes: index)),
        position: position,
      );

  List<String> ids(List<SetCard> cards) => cards.map((c) => c.cardId).toList();

  group('sortSetCardsByPosition', () {
    test('empty list returns empty', () {
      expect(sortSetCardsByPosition([]), isEmpty);
    });

    test('all legacy (null positions) preserves addedAt order', () {
      final input = [
        sc('a', index: 0),
        sc('b', index: 1),
        sc('c', index: 2),
      ];
      expect(ids(sortSetCardsByPosition(input)), ['a', 'b', 'c']);
    });

    test('fully positioned links sort by position', () {
      // Given out of addedAt order to prove position wins.
      final input = [
        sc('a', position: 2, index: 0),
        sc('b', position: 0, index: 1),
        sc('c', position: 1, index: 2),
      ];
      expect(ids(sortSetCardsByPosition(input)), ['b', 'c', 'a']);
    });

    test('legacy links then newly-appended positioned links keep intuitive order', () {
      // 3 legacy (null) added first, then a new card stamped position = 3.
      final input = [
        sc('a', index: 0),
        sc('b', index: 1),
        sc('c', index: 2),
        sc('d', position: 3, index: 3),
      ];
      expect(ids(sortSetCardsByPosition(input)), ['a', 'b', 'c', 'd']);
    });

    test('reordered set (all positioned) reflects the new order', () {
      // Author moved 'd' to the front: positions rewritten 0..3.
      final input = [
        sc('a', position: 1, index: 0),
        sc('b', position: 2, index: 1),
        sc('c', position: 3, index: 2),
        sc('d', position: 0, index: 3),
      ];
      expect(ids(sortSetCardsByPosition(input)), ['d', 'a', 'b', 'c']);
    });

    test('does not mutate the input list', () {
      final input = [
        sc('a', position: 1, index: 0),
        sc('b', position: 0, index: 1),
      ];
      sortSetCardsByPosition(input);
      expect(ids(input), ['a', 'b']);
    });

    test('ties fall back to addedAt order deterministically', () {
      // A legacy card whose fallback index (1) collides with a positioned card.
      final input = [
        sc('a', position: 0, index: 0),
        sc('b', index: 1), // fallback key = 1
        sc('c', position: 1, index: 2), // key = 1, ties with b
      ];
      // b comes before c because its addedAt index (1) is lower.
      expect(ids(sortSetCardsByPosition(input)), ['a', 'b', 'c']);
    });
  });

  group('reorderedIds (ReorderableListView semantics)', () {
    final base = ['a', 'b', 'c', 'd'];

    test('move an item down (framework passes an insertion slot past oldIndex)', () {
      // Drag 'a' (0) to drop after 'b' → onReorder(0, 2).
      expect(reorderedIds(base, 0, 2), ['b', 'a', 'c', 'd']);
    });

    test('move an item to the very end', () {
      expect(reorderedIds(base, 0, 4), ['b', 'c', 'd', 'a']);
    });

    test('move an item up to the front', () {
      expect(reorderedIds(base, 3, 0), ['d', 'a', 'b', 'c']);
    });

    test('dropping in place is a no-op', () {
      expect(reorderedIds(base, 1, 1), base);
      expect(reorderedIds(base, 1, 2), base); // slot just after itself
    });

    test('does not mutate the input list', () {
      reorderedIds(base, 0, 3);
      expect(base, ['a', 'b', 'c', 'd']);
    });
  });
}
