import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/study_candidate.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_mark_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/question_result_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/utils/study_filters.dart';

// Card IDs the user has flagged with the Review mark — the Study Review pool.
// autoDispose closes the cardMarks listener when no screen is watching.
final studyReviewCardIdsProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(cardMarkRepositoryProvider)
      .watchMarks(uid)
      .map(reviewCardIds);
});

// Card IDs with a recent mistake — the Study Mistakes pool. See mistakeCardIds.
final studyMistakesCardIdsProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(questionResultRepositoryProvider)
      .watchResults(uid)
      .map(mistakeCardIds);
});

// Resolves a mode's candidate card IDs into full StudyCandidate objects by
// loading the actual cards (flash + workbook) so type and language are known.
// Both card types are loaded by ID; whichever collection a card lives in
// classifies its type. Cards that no longer exist (deleted but still marked)
// are naturally dropped.
final studyCandidatesProvider =
    FutureProvider.autoDispose.family<List<StudyCandidate>, StudyMode>(
        (ref, mode) async {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return const [];

  // Await the first emission of the mode's ID list.
  final ids = await (mode == StudyMode.review
      ? ref.watch(studyReviewCardIdsProvider.future)
      : ref.watch(studyMistakesCardIdsProvider.future));
  if (ids.isEmpty) return const [];

  // Load both card types by ID in parallel. getCardsByIds returns only the IDs
  // that exist in each collection, so the two results partition cleanly.
  final flashFuture = ref.read(cardRepositoryProvider).getCardsByIds(ids, uid);
  final workbookFuture =
      ref.read(workbookCardRepositoryProvider).getCardsByIds(ids, uid);
  final flash = await flashFuture;
  final workbook = await workbookFuture;

  return buildStudyCandidates(flashCards: flash, workbookCards: workbook);
});