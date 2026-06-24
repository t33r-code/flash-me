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