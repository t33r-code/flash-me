import 'package:flash_me/utils/study_filters.dart';
import 'package:test/test.dart';

// Tests for the re-queue-missed-cards helpers (#214) in study_filters.dart.
void main() {
  group('requeueMissedCard', () {
    test('appends the current card when enabled and missed', () {
      final result = requeueMissedCard(['a', 'b', 'c'], 0,
          enabled: true, missed: true);
      expect(result, ['a', 'b', 'c', 'a']);
    });

    test('appends the card at currentIndex, not the last card', () {
      final result = requeueMissedCard(['a', 'b', 'c'], 1,
          enabled: true, missed: true);
      expect(result, ['a', 'b', 'c', 'b']);
    });

    test('returns the same list unchanged when not missed', () {
      final seq = ['a', 'b'];
      final result =
          requeueMissedCard(seq, 0, enabled: true, missed: false);
      expect(identical(result, seq), isTrue);
    });

    test('returns the same list unchanged when disabled', () {
      final seq = ['a', 'b'];
      final result =
          requeueMissedCard(seq, 0, enabled: false, missed: true);
      expect(identical(result, seq), isTrue);
    });

    test('appends at most once per call', () {
      final result = requeueMissedCard(['a', 'b'], 0,
          enabled: true, missed: true);
      expect(result.where((id) => id == 'a').length, 2);
    });

    test('out-of-range index is a no-op', () {
      final seq = ['a', 'b'];
      expect(
          identical(
              requeueMissedCard(seq, 5, enabled: true, missed: true), seq),
          isTrue);
      expect(
          identical(
              requeueMissedCard(seq, -1, enabled: true, missed: true), seq),
          isTrue);
    });
  });

  group('uniqueCardsStudied', () {
    test('counts every card once when there are no re-queues', () {
      expect(uniqueCardsStudied(['a', 'b', 'c'], 2), 3);
    });

    test('only counts visited positions (0..currentIndex)', () {
      expect(uniqueCardsStudied(['a', 'b', 'c'], 0), 1);
      expect(uniqueCardsStudied(['a', 'b', 'c'], 1), 2);
    });

    test('re-queued repetitions count once', () {
      // a was re-queued to the end; after visiting the repeat, still 2 unique.
      expect(uniqueCardsStudied(['a', 'b', 'a'], 2), 2);
    });

    test('empty sequence and negative index yield 0', () {
      expect(uniqueCardsStudied([], 0), 0);
      expect(uniqueCardsStudied(['a'], -1), 0);
    });

    test('currentIndex beyond the end is clamped', () {
      expect(uniqueCardsStudied(['a', 'b'], 10), 2);
    });
  });

  // Composition test: models the session engine calling requeueMissedCard once
  // per visit, to demonstrate the "keeps reappearing until all correct" AC.
  group('re-queue loop (composition)', () {
    // Walks the sequence, appending on each visit flagged missed, and returns
    // the full visit order. missedByVisit lists whether each successive visit
    // (in traversal order) was missed.
    List<String> walk(List<String> initial, List<bool> missedByVisit) {
      var seq = initial;
      var i = 0;
      var visit = 0;
      final order = <String>[];
      while (i < seq.length) {
        order.add(seq[i]);
        final missed = visit < missedByVisit.length && missedByVisit[visit];
        seq = requeueMissedCard(seq, i, enabled: true, missed: missed);
        i++;
        visit++;
      }
      return order;
    }

    test('a card missed once reappears once, then retires when correct', () {
      // [A, B]; A missed on visit 0, B fine, A correct on visit 2.
      final order = walk(['a', 'b'], [true, false, false]);
      expect(order, ['a', 'b', 'a']);
    });

    test('a card missed repeatedly keeps reappearing until correct', () {
      // A missed on visits 0 and 2, finally correct on visit 3.
      final order = walk(['a', 'b'], [true, false, true, false]);
      expect(order, ['a', 'b', 'a', 'a']);
    });

    test('nothing missed means a single clean pass', () {
      final order = walk(['a', 'b', 'c'], [false, false, false]);
      expect(order, ['a', 'b', 'c']);
    });
  });
}