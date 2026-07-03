import 'package:flash_me/utils/question_reveal.dart';
import 'package:test/test.dart';

// Tests for progressive question reveal (#215) — the isQuestionExpanded rule
// that drives which questions on a multi-question card are shown vs collapsed.
void main() {
  group('isQuestionExpanded', () {
    test('first question is always expanded, even with nothing answered', () {
      expect(isQuestionExpanded(0, {}), isTrue);
    });

    test('a later question is collapsed until its predecessor is answered', () {
      expect(isQuestionExpanded(1, {}), isFalse); // Q0 not answered yet
      expect(isQuestionExpanded(1, {0}), isTrue); // Q0 answered → Q1 expands
    });

    test('expansion depends only on the immediate predecessor', () {
      // Q2 stays collapsed while only Q0 is answered...
      expect(isQuestionExpanded(2, {0}), isFalse);
      // ...and expands once Q1 (its predecessor) is answered.
      expect(isQuestionExpanded(2, {0, 1}), isTrue);
    });

    test('an answered question stays expanded (predecessor remains answered)',
        () {
      // Once Q0 is answered it is in the set forever this visit, so Q1 (and Q0)
      // remain expanded as the user progresses.
      final answered = {0, 1, 2};
      expect(isQuestionExpanded(0, answered), isTrue);
      expect(isQuestionExpanded(1, answered), isTrue);
      expect(isQuestionExpanded(2, answered), isTrue);
    });

    test('reveal walk: a 4-question card unfolds one at a time', () {
      final answered = <int>{};
      // Start: only Q0 visible.
      expect([for (var i = 0; i < 4; i++) isQuestionExpanded(i, answered)],
          [true, false, false, false]);

      // Answer Q0 → Q1 appears.
      answered.add(0);
      expect([for (var i = 0; i < 4; i++) isQuestionExpanded(i, answered)],
          [true, true, false, false]);

      // Answer Q1 → Q2 appears.
      answered.add(1);
      expect([for (var i = 0; i < 4; i++) isQuestionExpanded(i, answered)],
          [true, true, true, false]);

      // Answer Q2 → Q3 (last) appears.
      answered.add(2);
      expect([for (var i = 0; i < 4; i++) isQuestionExpanded(i, answered)],
          [true, true, true, true]);
    });

    test('answering out of order does not skip ahead', () {
      // If somehow Q2 were marked answered before Q1 (defensive), Q3 must still
      // wait on its own predecessor Q2, and Q2 waits on Q1.
      expect(isQuestionExpanded(2, {2}), isFalse); // Q1 not answered
      expect(isQuestionExpanded(3, {2}), isTrue); // Q2 answered → Q3 expands
    });
  });
}