import 'package:flash_me/utils/constants.dart';

// The two filtered study modes that build a synthetic card set from the user's
// accumulated study signals rather than from a real set's membership.
enum StudyMode { review, mistakes }

// Maps a synthetic sentinel set ID back to its StudyMode, or null for a real
// set. Used by screens (e.g. the summary's "Study Again") that only hold a
// CardSet and need to re-enter the originating mode.
StudyMode? studyModeFromSetId(String setId) => switch (setId) {
      AppConstants.syntheticReviewSetId => StudyMode.review,
      AppConstants.syntheticMistakesSetId => StudyMode.mistakes,
      _ => null,
    };

// The sentinel set ID a given mode stores its sessions under.
String syntheticSetIdFor(StudyMode mode) => switch (mode) {
      StudyMode.review => AppConstants.syntheticReviewSetId,
      StudyMode.mistakes => AppConstants.syntheticMistakesSetId,
    };

// A single card eligible for a synthetic study set, with the metadata that
// filters operate on. Built by loading the actual card (flash or workbook) so
// its type and language are known. Language is carried for the language filter
// (#180); the core modes (#179) only need cardId + cardType.
class StudyCandidate {
  final String cardId;
  // AppConstants.cardTypeFlashcard | cardTypeWorkbook
  final String cardType;
  final String? targetLanguage; // ISO 639-1, may be null if unset on the card
  final String? nativeLanguage; // ISO 639-1, may be null if unset on the card

  const StudyCandidate({
    required this.cardId,
    required this.cardType,
    this.targetLanguage,
    this.nativeLanguage,
  });
}