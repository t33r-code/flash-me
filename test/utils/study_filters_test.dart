import 'package:flutter_test/flutter_test.dart';
import 'package:flash_me/models/card_mark.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/question_result.dart';
import 'package:flash_me/models/study_candidate.dart';
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

  StudyCandidate cand(String id, String? lang) => StudyCandidate(
        cardId: id,
        cardType: AppConstants.cardTypeFlashcard,
        targetLanguage: lang,
      );

  group('shouldShowLanguageFilter', () {
    test('hidden for a monolingual pool', () {
      expect(shouldShowLanguageFilter([cand('a', 'es'), cand('b', 'es')]),
          isFalse);
    });

    test('hidden when all cards are unspecified', () {
      expect(shouldShowLanguageFilter([cand('a', null), cand('b', null)]),
          isFalse);
    });

    test('shown for two distinct languages', () {
      expect(shouldShowLanguageFilter([cand('a', 'es'), cand('b', 'de')]),
          isTrue);
    });

    test('shown for one language plus unspecified', () {
      expect(shouldShowLanguageFilter([cand('a', 'es'), cand('b', null)]),
          isTrue);
    });
  });

  group('candidateMatchesLanguage', () {
    test('all matches everything', () {
      expect(candidateMatchesLanguage(cand('a', 'es'), langFilterAll), isTrue);
      expect(candidateMatchesLanguage(cand('a', null), langFilterAll), isTrue);
    });

    test('specific language matches only that language', () {
      expect(candidateMatchesLanguage(cand('a', 'es'), 'es'), isTrue);
      expect(candidateMatchesLanguage(cand('a', 'de'), 'es'), isFalse);
      expect(candidateMatchesLanguage(cand('a', null), 'es'), isFalse);
    });

    test('unspecified matches only language-less cards', () {
      expect(candidateMatchesLanguage(cand('a', null), langFilterUnspecified),
          isTrue);
      expect(candidateMatchesLanguage(cand('a', 'es'), langFilterUnspecified),
          isFalse);
    });
  });

  group('defaultLanguageSelection', () {
    test('uses last-used target when present in the pool', () {
      final pool = [cand('a', 'es'), cand('b', 'de'), cand('c', 'de')];
      expect(defaultLanguageSelection(pool, 'es'), 'es');
    });

    test('falls back to most-common language when last-used absent', () {
      final pool = [cand('a', 'es'), cand('b', 'de'), cand('c', 'de')];
      expect(defaultLanguageSelection(pool, 'fr'), 'de');
    });

    test('falls back to most-common when last-used is null', () {
      final pool = [cand('a', 'es'), cand('b', 'es'), cand('c', 'de')];
      expect(defaultLanguageSelection(pool, null), 'es');
    });

    test('never defaults to unspecified even if it is most common', () {
      final pool = [cand('a', null), cand('b', null), cand('c', 'de')];
      expect(defaultLanguageSelection(pool, null), 'de');
    });

    test('tie-breaks alphabetically by code', () {
      final pool = [cand('a', 'de'), cand('b', 'es')];
      expect(defaultLanguageSelection(pool, null), 'de');
    });
  });

  group('applyStudyFilters', () {
    test('keeps all when no filters', () {
      final pool = [cand('a', 'es'), cand('b', 'de')];
      expect(applyStudyFilters(pool, const []).length, 2);
    });

    test('applies the language predicate', () {
      final pool = [cand('a', 'es'), cand('b', 'de'), cand('c', null)];
      final out = applyStudyFilters(
          pool, [(c) => candidateMatchesLanguage(c, 'es')]);
      expect(out.map((c) => c.cardId), ['a']);
    });
  });
}