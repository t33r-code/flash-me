import 'package:flash_me/models/card_mark.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/question_result.dart';
import 'package:flash_me/models/study_candidate.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/utils/constants.dart';

// Pure selection logic for the synthetic study modes, kept separate from the
// Riverpod providers so it can be unit-tested without mocks or a container.

// Card IDs flagged with the Review mark — the Study Review pool.
List<String> reviewCardIds(List<CardMark> marks) => marks
    .where((m) => m.mark == AppConstants.markReview)
    .map((m) => m.cardId)
    .toList();

// Distinct card IDs with a recent mistake — the Study Mistakes pool. A card
// qualifies if any of its question fields has a 'fail' anywhere in its rolling
// window (the window already holds only the last N outcomes, i.e. "recent").
List<String> mistakeCardIds(List<QuestionResult> results) {
  final ids = <String>{};
  for (final r in results) {
    if (r.results.contains(AppConstants.resultFail)) ids.add(r.cardId);
  }
  return ids.toList();
}

// Builds StudyCandidates from the loaded cards of each type. Whichever
// collection a card came from determines its type; language is carried through
// for the language filter (#180).
List<StudyCandidate> buildStudyCandidates({
  required List<FlashCard> flashCards,
  required List<WorkbookCard> workbookCards,
}) =>
    [
      for (final c in flashCards)
        StudyCandidate(
          cardId: c.id,
          cardType: AppConstants.cardTypeFlashcard,
          targetLanguage: c.targetLanguage,
          nativeLanguage: c.nativeLanguage,
        ),
      for (final c in workbookCards)
        StudyCandidate(
          cardId: c.id,
          cardType: AppConstants.cardTypeWorkbook,
          targetLanguage: c.targetLanguage,
          nativeLanguage: c.nativeLanguage,
        ),
    ];

// ---------------------------------------------------------------------------
// Study filters — an extensible predicate seam over candidates. The language
// filter below is the first concrete filter; future filters (subject/topic,
// field type, mark age, …) are just more predicates, applied the same way.
// ---------------------------------------------------------------------------

typedef StudyFilter = bool Function(StudyCandidate);

// Keeps only candidates that satisfy every active filter (empty list = keep all).
List<StudyCandidate> applyStudyFilters(
        List<StudyCandidate> candidates, List<StudyFilter> filters) =>
    candidates.where((c) => filters.every((f) => f(c))).toList();

// Sentinel selection keys for the language filter (distinct from any ISO code).
const String langFilterAll = '*all*';
const String langFilterUnspecified = '*unspecified*';

// Count of candidates per target language; a null key is the "unspecified"
// bucket (cards with no target language set).
Map<String?, int> targetLanguageCounts(List<StudyCandidate> candidates) {
  final counts = <String?, int>{};
  for (final c in candidates) {
    counts[c.targetLanguage] = (counts[c.targetLanguage] ?? 0) + 1;
  }
  return counts;
}

// Show the language selector only when the pool spans more than one bucket
// (distinct target languages, counting "unspecified" as a bucket). A
// monolingual or all-unspecified pool has nothing to filter.
bool shouldShowLanguageFilter(List<StudyCandidate> candidates) =>
    targetLanguageCounts(candidates).length > 1;

// Whether a candidate matches the current language selection.
bool candidateMatchesLanguage(StudyCandidate c, String selection) {
  if (selection == langFilterAll) return true;
  if (selection == langFilterUnspecified) return c.targetLanguage == null;
  return c.targetLanguage == selection;
}

// Default selection: the last-used target language if it's a present non-null
// bucket, otherwise the non-null language with the most candidates (alphabetical
// tie-break). Never defaults to "all" or "unspecified" — those are explicit
// opt-ins. Falls back to "all" only if the pool has no non-null languages.
String defaultLanguageSelection(
    List<StudyCandidate> candidates, String? lastUsedTarget) {
  final nonNull = <String, int>{
    for (final e in targetLanguageCounts(candidates).entries)
      if (e.key != null) e.key!: e.value,
  };
  if (nonNull.isEmpty) return langFilterAll;
  if (lastUsedTarget != null && nonNull.containsKey(lastUsedTarget)) {
    return lastUsedTarget;
  }
  final sorted = nonNull.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return sorted.first.key;
}