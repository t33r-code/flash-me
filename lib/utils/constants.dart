
class AppConstants {
  // App name and version
  static const String appName = 'Agora';
  static const String appVersion = '1.0.0';

  // Firestore collection names
  static const String usersCollection = 'users';
  static const String cardsCollection = 'cards';
  static const String setsCollection = 'sets';
  static const String setCardsCollection = 'setCards'; // many-to-many join: set ↔ card
  static const String templatesCollection = 'templates';
  static const String questionTemplatesCollection = 'questionTemplates';
  static const String tagsCollection = 'tags';
  static const String studySessionsSubcollection = 'studySessions';
  static const String cardMarksSubcollection = 'cardMarks'; // users/{uid}/cardMarks/{cardId}
  static const String questionResultsSubcollection = 'questionResults'; // users/{uid}/questionResults/{cardId}_{fieldId}

  // Card mark values — stored in cardMarks documents.
  static const String markSkip = 'skip';
  static const String markReview = 'review';

  // Question result values — stored in questionResults documents.
  static const String resultSuccess = 'success';
  static const String resultFail = 'fail';
  static const String resultUnseen = 'unseen';

  // Primary-field self-evaluation — stored in CardSessionData.primaryResult.
  // Captures whether the user recalled the flashcard word before revealing it.
  // Distinct from the Skip/Review marks (markedKnown/markedUnknown), which are
  // persistent per-card flags for future filtered study, not session scoring.
  static const String primaryResultKnown = 'known';
  static const String primaryResultUnknown = 'unknown';
  // Rolling window size for question results.
  static const int questionResultsWindowSize = 5;

  // Question types — shared by FlashCard.questions and WorkbookCard.questions.
  static const String fieldTypeTextInput = 'text_input';
  static const String fieldTypeMultipleChoice = 'multiple_choice';
  // word_order is not available on flash card questions yet (planned for Step 3 UI).
  static const String questionTypeWordOrder = 'word_order';
  // fill_in_blanks — sentence with one or more pill/text blanks (#170).
  static const String questionTypeFillInBlanks = 'fill_in_blanks';

  // Card type discriminator stored on setCards join documents.
  static const String cardTypeFlashcard = 'flashcard';
  static const String cardTypeWorkbook = 'workbook';

  // Sentinel set IDs for synthetic study sets (filtered modes — not real sets).
  // Sessions for these modes are stored under these reserved IDs so their
  // history groups separately from real sets. The leading/trailing underscores
  // ensure they can never collide with a generated Firestore document ID.
  static const String syntheticReviewSetId = '__review__';
  static const String syntheticMistakesSetId = '__mistakes__';

  // Firestore collection for workbook cards (parallel to cards/).
  static const String workbookCardsCollection = 'workbookCards';
  static const String setAcquisitionsCollection = 'setAcquisitions';
  static const String cardAcquisitionsCollection = 'cardAcquisitions';
  static const String feedbackCollection = 'feedback';

  // Session status
  static const String sessionStatusInProgress = 'in_progress';
  static const String sessionStatusCompleted = 'completed';
  static const String sessionStatusPaused = 'paused';

  // Card progress status
  static const String cardStatusNotStarted = 'not_started';
  static const String cardStatusRevealed = 'revealed';
  static const String cardStatusAnswered = 'answered';
  static const String cardStatusMarkedKnown = 'marked_known';
  static const String cardStatusMarkedUnknown = 'marked_unknown';

  // Pagination
  static const int pageSize = 20;

  // Timeouts
  static const Duration authTimeout = Duration(seconds: 30);
  static const Duration firebaseTimeout = Duration(seconds: 15);
}
