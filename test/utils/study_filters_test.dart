import 'package:flutter_test/flutter_test.dart';
import 'package:flash_me/models/card_mark.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/question_result.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/study_filters.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  CardMark mark(String cardId, String m) =>
      CardMark(cardId: cardId, mark: m, markedAt: now, updatedAt: now);

  QuestionResult result(String cardId, String fieldId, List<String> results) =>
      QuestionResult(
        cardId: cardId,
        fieldId: fieldId,
        fieldName: 'Field',
        fieldType: AppConstants.fieldTypeTextInput,
        results: results,
        updatedAt: now,
      );

  FlashCard flash(String id, {String? target}) => FlashCard(
        id: id,
        primaryWord: 'w',
        translation: 't',
        questions: const [],
        targetLanguage: target,
        createdAt: now,
        updatedAt: now,
        createdBy: 'u',
      );

  WorkbookCard workbook(String id, {String? target}) => WorkbookCard(
        id: id,
        prompt: 'p',
        questions: const [],
        targetLanguage: target,
        createdAt: now,
        updatedAt: now,
        createdBy: 'u',
      );

  group('reviewCardIds', () {
    test('returns only cards marked review (not skip)', () {
      final ids = reviewCardIds([
        mark('a', AppConstants.markReview),
        mark('b', AppConstants.markSkip),
        mark('c', AppConstants.markReview),
      ]);
      expect(ids, ['a', 'c']);
    });

    test('empty when no review marks', () {
      expect(reviewCardIds([mark('a', AppConstants.markSkip)]), isEmpty);
    });
  });

  group('mistakeCardIds', () {
    test('includes a card whose window contains a fail', () {
      final ids = mistakeCardIds([
        result('a', 'a_q1', [AppConstants.resultFail, AppConstants.resultSuccess]),
      ]);
      expect(ids, ['a']);
    });

    test('excludes a card with no fail in its window', () {
      final ids = mistakeCardIds([
        result('a', 'a_q1',
            [AppConstants.resultSuccess, AppConstants.resultUnseen]),
      ]);
      expect(ids, isEmpty);
    });

    test('dedupes a card with multiple failed fields', () {
      final ids = mistakeCardIds([
        result('a', 'a_q1', [AppConstants.resultFail]),
        result('a', 'a_q2', [AppConstants.resultFail]),
        result('b', 'b_q1', [AppConstants.resultSuccess]),
      ]);
      expect(ids, ['a']);
    });
  });

  group('buildStudyCandidates', () {
    test('classifies type by source collection and carries language', () {
      final candidates = buildStudyCandidates(
        flashCards: [flash('f1', target: 'es')],
        workbookCards: [workbook('w1', target: 'de')],
      );
      expect(candidates.length, 2);

      final f = candidates.firstWhere((c) => c.cardId == 'f1');
      expect(f.cardType, AppConstants.cardTypeFlashcard);
      expect(f.targetLanguage, 'es');

      final w = candidates.firstWhere((c) => c.cardId == 'w1');
      expect(w.cardType, AppConstants.cardTypeWorkbook);
      expect(w.targetLanguage, 'de');
    });

    test('preserves null language', () {
      final candidates =
          buildStudyCandidates(flashCards: [flash('f1')], workbookCards: []);
      expect(candidates.single.targetLanguage, isNull);
    });
  });
}