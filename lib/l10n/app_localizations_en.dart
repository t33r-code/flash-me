// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get statusLoading => 'Loading...';

  @override
  String get labelError => 'Error';

  @override
  String get labelSuccess => 'Success';

  @override
  String get labelCancel => 'Cancel';

  @override
  String get labelConfirm => 'Confirm';

  @override
  String get labelDelete => 'Delete';

  @override
  String get labelEdit => 'Edit';

  @override
  String get labelSave => 'Save';

  @override
  String get labelClose => 'Close';

  @override
  String get titleWelcome => 'Welcome to Agora';

  @override
  String get actionSignUp => 'Sign Up';

  @override
  String get actionSignIn => 'Sign In';

  @override
  String get actionSignOut => 'Sign Out';

  @override
  String get actionSignUpWithGoogle => 'Sign Up with Google';

  @override
  String get actionSignInWithGoogle => 'Sign In with Google';

  @override
  String get labelEmail => 'Email';

  @override
  String get labelPassword => 'Password';

  @override
  String get labelConfirmPassword => 'Confirm Password';

  @override
  String get actionForgotPassword => 'Forgot Password?';

  @override
  String get titleMySets => 'My Sets';

  @override
  String get actionNewSet => 'New Set';

  @override
  String get actionCreateSet => 'Create Set';

  @override
  String get labelSetName => 'Set Name';

  @override
  String get labelSetDescription => 'Description';

  @override
  String get messageNoSets => 'No sets yet. Create one to get started!';

  @override
  String get labelCards => 'Cards';

  @override
  String get actionNewCard => 'New Card';

  @override
  String get actionCreateCard => 'Create Card';

  @override
  String get actionDeleteCard => 'Delete Card';

  @override
  String get labelPrimaryWord => 'Foreign Word';

  @override
  String get labelTranslation => 'Translation';

  @override
  String get messageNoCards => 'No cards in this set';

  @override
  String get labelStudy => 'Study';

  @override
  String get actionStartStudy => 'Start Study';

  @override
  String get actionResumeSession => 'Resume Session';

  @override
  String get actionNewSession => 'New Session';

  @override
  String get actionNextCard => 'Next';

  @override
  String get actionPreviousCard => 'Previous';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionReview => 'Review';

  @override
  String get actionCheckAnswer => 'Check Answer';

  @override
  String get actionShowAnswer => 'Show Answer';

  @override
  String get labelCorrect => 'Correct!';

  @override
  String get labelIncorrect => 'Incorrect';

  @override
  String get actionEndSession => 'End Session';

  @override
  String get messageErrorLoadingApp => 'Error loading app. Please restart.';

  @override
  String get titleResetPassword => 'Reset Password';

  @override
  String get actionSendResetEmail => 'Send Reset Email';

  @override
  String get messagePasswordResetSent =>
      'Password reset email sent. Check your inbox.';

  @override
  String get messageFailedSendResetEmail =>
      'Failed to send reset email. Please try again.';

  @override
  String get messageSignInToContinue => 'Sign in to continue';

  @override
  String get messageCreateYourAccount => 'Create your account';

  @override
  String get validatorConfirmPassword => 'Please confirm your password';

  @override
  String get validatorPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get labelOr => 'or';

  @override
  String get messageNoAccount => 'Don\'t have an account? ';

  @override
  String get messageHaveAccount => 'Already have an account? ';

  @override
  String get errorInvalidCredential => 'Invalid email or password.';

  @override
  String get errorEmailInUse => 'An account with this email already exists.';

  @override
  String get errorWeakPassword =>
      'Password is too weak. Use at least 6 characters.';

  @override
  String get errorInvalidEmail => 'Please enter a valid email address.';

  @override
  String get errorTooManyRequests =>
      'Too many attempts. Please try again later.';

  @override
  String get errorNetworkFailed => 'Network error. Check your connection.';

  @override
  String get errorUnexpected => 'An unexpected error occurred.';

  @override
  String get errorGoogleSignInFailed =>
      'Google sign-in failed. Please try again.';

  @override
  String get navSets => 'Sets';

  @override
  String get navCards => 'Cards';

  @override
  String get navStudy => 'Study';

  @override
  String get navTemplates => 'Templates';

  @override
  String get navProfile => 'Profile';

  @override
  String get actionImportSets => 'Import Sets';

  @override
  String get actionExportSets => 'Export Sets';

  @override
  String get actionChooseFile => 'Choose File';

  @override
  String get labelSelectFormat => 'Select Format';

  @override
  String get labelJson => 'JSON';

  @override
  String get labelCsv => 'CSV';

  @override
  String get titleProfile => 'Profile';

  @override
  String get tooltipEditProfile => 'Edit profile';

  @override
  String get errorFailedLoadProfile => 'Failed to load profile.';

  @override
  String get messageProfileUpdated => 'Profile updated.';

  @override
  String get messageFailedUpdateProfile =>
      'Failed to update profile. Please try again.';

  @override
  String get messageSignOutFailed => 'Sign out failed. Please try again.';

  @override
  String get titleDeleteAccount => 'Delete account?';

  @override
  String get messageDeleteAccountConfirm =>
      'This will permanently delete:\n• All your cards and card sets\n• All templates and study history\n• Your profile and account\n\nPublic sets you have published will be unpublished first. This cannot be undone.';

  @override
  String get actionDeleteMyAccount => 'Delete my account';

  @override
  String get actionDeleteAccount => 'Delete Account';

  @override
  String get messageRecentLoginRequired =>
      'Please sign out and sign back in before deleting your account.';

  @override
  String messageFailedDeleteAccountError(String errorMessage) {
    return 'Failed to delete account: $errorMessage';
  }

  @override
  String get messageFailedDeleteAccountGeneric =>
      'Failed to delete account. Please try again.';

  @override
  String get labelDisplayName => 'Display Name';

  @override
  String get labelNotSet => 'Not set';

  @override
  String get labelImportExport => 'Import & Export';

  @override
  String get messageImportExportSubtitle =>
      'Import or export card sets as ZIP files';

  @override
  String get labelTheme => 'Theme';

  @override
  String get labelThemeSystem => 'System';

  @override
  String get labelThemeLight => 'Light';

  @override
  String get labelThemeDark => 'Dark';

  @override
  String get tabMySets => 'My Sets';

  @override
  String get tabMarket => 'Market';

  @override
  String get tooltipSortBy => 'Sort by';

  @override
  String get labelSortLastUpdated => 'Last updated';

  @override
  String get labelSortName => 'Name';

  @override
  String get labelSortCardCount => 'Card count';

  @override
  String get tooltipCreateSet => 'Create set';

  @override
  String get hintSearchSets => 'Search sets…';

  @override
  String get hintSearchMarket => 'Search market…';

  @override
  String get labelAll => 'All';

  @override
  String get messageNoSetsMatchSearch => 'No sets match your search.';

  @override
  String get errorFailedLoadSets => 'Failed to load sets.';

  @override
  String get errorFailedLoadMarket => 'Failed to load market.';

  @override
  String get titleNoSetsYet => 'No sets yet';

  @override
  String get messageNoSetsHint => 'Tap + to create your first set.';

  @override
  String get titleMarketEmpty => 'Market is empty';

  @override
  String get messageMarketEmpty =>
      'No sets have been published yet.\nPublish your own from a set\'s detail screen.';

  @override
  String get tooltipOfferedInMarket => 'Offered in Market';

  @override
  String get labelInMarket => 'In Market';

  @override
  String get labelToday => 'Today';

  @override
  String get labelYesterday => 'Yesterday';

  @override
  String get labelMonthJan => 'Jan';

  @override
  String get labelMonthFeb => 'Feb';

  @override
  String get labelMonthMar => 'Mar';

  @override
  String get labelMonthApr => 'Apr';

  @override
  String get labelMonthMay => 'May';

  @override
  String get labelMonthJun => 'Jun';

  @override
  String get labelMonthJul => 'Jul';

  @override
  String get labelMonthAug => 'Aug';

  @override
  String get labelMonthSep => 'Sep';

  @override
  String get labelMonthOct => 'Oct';

  @override
  String get labelMonthNov => 'Nov';

  @override
  String get labelMonthDec => 'Dec';

  @override
  String labelAcquiredCloned(String date) {
    return 'Cloned $date';
  }

  @override
  String labelAcquiredSubscribed(String date) {
    return 'Subscribed $date';
  }

  @override
  String labelCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String labelQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String get titleNewSet => 'New Set';

  @override
  String get titleEditSet => 'Edit Set';

  @override
  String get labelSetNameRequired => 'Set name *';

  @override
  String get hintSetNameExample => 'e.g. Spanish Verbs';

  @override
  String get validatorSetNameRequired => 'Name is required';

  @override
  String get labelDescriptionOptional => 'Description (optional)';

  @override
  String get titleLanguagesSection => 'Languages';

  @override
  String get labelTargetLanguage => 'Target language (being studied)';

  @override
  String get labelNativeLanguage => 'Native language';

  @override
  String get titleColorSection => 'Colour';

  @override
  String get titleTagsSection => 'Tags';

  @override
  String get errorFailedSaveSet => 'Failed to save set. Please try again.';

  @override
  String get actionSaveChanges => 'Save Changes';

  @override
  String get semanticsColorNone => 'No colour';

  @override
  String get semanticsColorRed => 'Red';

  @override
  String get semanticsColorDeepOrange => 'Deep orange';

  @override
  String get semanticsColorAmber => 'Amber';

  @override
  String get semanticsColorGreen => 'Green';

  @override
  String get semanticsColorTeal => 'Teal';

  @override
  String get semanticsColorBlue => 'Blue';

  @override
  String get semanticsColorIndigo => 'Indigo';

  @override
  String get semanticsColorPurple => 'Purple';

  @override
  String get semanticsColorPink => 'Pink';

  @override
  String semanticsColorSelected(String colorName) {
    return '$colorName, selected';
  }

  @override
  String get titleDeleteSet => 'Delete Set';

  @override
  String messageDeleteSetConfirm(String name) {
    return 'Delete \"$name\"? Cards are not deleted, only removed from this set.';
  }

  @override
  String get errorFailedDeleteSet => 'Failed to delete set. Please try again.';

  @override
  String get errorFailedRemoveCard => 'Failed to remove card.';

  @override
  String get messagePreparingExport => 'Preparing export…';

  @override
  String messageSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get errorExportFailed => 'Export failed. Please try again.';

  @override
  String get titleRemoveFromMarket => 'Remove from Market';

  @override
  String messageRemoveFromMarketAcquired(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count users',
      one: '1 user',
    );
    return '\"$name\" has been acquired by $_temp0. Removing it from the Market will not affect their copies — this set will simply stop appearing to new users.';
  }

  @override
  String messageRemoveFromMarketNoAcquisitions(String name) {
    return 'Remove \"$name\" from the Market? It will no longer appear for other users.';
  }

  @override
  String get errorFailedPublish => 'Failed to publish. Please try again.';

  @override
  String get errorFailedRemoveFromMarket =>
      'Failed to remove from Market. Please try again.';

  @override
  String get tooltipRemoveFromMarket => 'Remove from Market';

  @override
  String get tooltipOfferInMarket => 'Offer in Market';

  @override
  String get tooltipExportSet => 'Export set';

  @override
  String get tooltipDeleteSet => 'Delete set';

  @override
  String get tooltipEditSet => 'Edit set';

  @override
  String get tooltipStudyThisSet => 'Study this set';

  @override
  String get tooltipAddCards => 'Add cards';

  @override
  String get titleNoCardsYet => 'No cards yet';

  @override
  String get messageNoCardsHint => 'Tap + to add cards to this set.';

  @override
  String get actionAddCards => 'Add Cards';

  @override
  String get actionAdd => 'Add';

  @override
  String actionAddCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get errorFailedLoadCards => 'Failed to load cards.';

  @override
  String get messageNoCardsYetTab =>
      'No cards yet. Create cards from the Cards tab.';

  @override
  String get messageAllCardsInSet => 'All your cards are already in this set.';

  @override
  String get labelSectionFlashCards => 'Flash Cards';

  @override
  String get labelSectionWorkbookCards => 'Workbook Cards';

  @override
  String get labelDuplicateWordInSet => 'Duplicate word — already in set';

  @override
  String get labelAlreadyInSet => 'Already in set';

  @override
  String get labelAllowClone => 'Allow Clone';

  @override
  String get messageAllowCloneSubtitle =>
      'Users can copy this set into their own library.';

  @override
  String get titleOfferInMarket => 'Offer in Market';

  @override
  String messageOfferInMarketDescription(String name) {
    return 'Make \"$name\" visible in the Market tab so other users can discover and acquire it.';
  }

  @override
  String get titleOptions => 'Options';

  @override
  String get actionOfferInMarket => 'Offer in Market';

  @override
  String get titleCloneSet => 'Clone Set';

  @override
  String get infoCloneAddedToMySets =>
      'A copy of this set is added to your My Sets.';

  @override
  String get infoCloneFullyEditable =>
      'Your copy is fully editable and independent.';

  @override
  String get infoCloneNoChanges =>
      'Changes to the original won\'t affect your copy.';

  @override
  String get actionCloneToMySets => 'Clone to My Sets';

  @override
  String get labelCloning => 'Cloning…';

  @override
  String messageCloneSuccess(String name) {
    return '\"$name\" added to My Sets.';
  }

  @override
  String get errorFailedCloneSet => 'Failed to clone set. Please try again.';

  @override
  String get titleAlreadyHaveSet => 'You Already Have This Set';

  @override
  String get infoAlreadyHaveCopy =>
      'You already have a copy of this set in My Sets.';

  @override
  String get messageCheckingForUpdates => 'Checking for updates…';

  @override
  String get messageSetNoLongerAvailable =>
      'This set is no longer available — the creator\'s account has been deleted.';

  @override
  String get messageCouldNotCheckUpdates =>
      'Could not check for updates. Please try again later.';

  @override
  String get labelOk => 'OK';

  @override
  String messageNewCardsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new cards added to the original since you cloned it.',
      one: '1 new card added to the original since you cloned it.',
    );
    return '$_temp0';
  }

  @override
  String messageCardsUpdatedSinceClone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards updated in the original since you cloned it.',
      one: '1 card updated in the original since you cloned it.',
    );
    return '$_temp0';
  }

  @override
  String get infoUpdateInPlace =>
      'Your existing set will be updated in place. No new set will be created.';

  @override
  String get actionUpdateMyCopy => 'Update My Copy';

  @override
  String get labelUpdating => 'Updating…';

  @override
  String messageUpdateSuccess(String name) {
    return '\"$name\" updated.';
  }

  @override
  String get errorFailedUpdateSet => 'Failed to update set. Please try again.';

  @override
  String get infoUpToDate => 'Your copy is up to date.';

  @override
  String get titleMyCards => 'My Cards';

  @override
  String get titleCreateCard => 'Create a card';

  @override
  String get labelFlashCard => 'Flash Card';

  @override
  String get messageFlashCardSubtitle =>
      'Word + translation with optional fields';

  @override
  String get labelWorkbookCard => 'Workbook Card';

  @override
  String get messageWorkbookCardSubtitle =>
      'Prompt with text, multiple choice, or word order questions';

  @override
  String get hintSearchCards => 'Search cards…';

  @override
  String get messageNoCardsMatchSearch => 'No cards match your search.';

  @override
  String get messageNoCardsYetCreate =>
      'No cards yet. Tap + to create your first card.';

  @override
  String get tooltipCreateCard => 'Create card';

  @override
  String get titleNewCard => 'New Card';

  @override
  String get titleEditCard => 'Edit Card';

  @override
  String get titleDeleteCard => 'Delete Card';

  @override
  String messageDeleteCardConfirm(String name) {
    return 'Delete \"$name\"? It will be removed from all sets and cannot be undone.';
  }

  @override
  String get errorFailedSaveCard => 'Failed to save card. Please try again.';

  @override
  String get errorFailedDeleteCard =>
      'Failed to delete card. Please try again.';

  @override
  String get tooltipDeleteCard => 'Delete card';

  @override
  String get actionSaveAsTemplate => 'Save as Template';

  @override
  String get titlePrimaryField => 'Primary Field';

  @override
  String get labelForeignWordRequired => 'Foreign word *';

  @override
  String get hintForeignWordExample => 'e.g. hablar';

  @override
  String get validatorForeignWordRequired => 'Foreign word is required';

  @override
  String get labelTranslationRequired => 'Translation *';

  @override
  String get hintTranslationExample => 'e.g. to speak';

  @override
  String get validatorTranslationRequired => 'Translation is required';

  @override
  String get labelHideHintWord => 'Hide hint word during study';

  @override
  String get messageHideHintWordSubtitle =>
      'Show only the image/audio at first; reveal the text hint on demand';

  @override
  String get titleMediaSection => 'Media';

  @override
  String get messageMediaSectionSubtitle =>
      'Optional image and audio for the primary field.';

  @override
  String get actionReplaceImage => 'Replace image';

  @override
  String get actionAddImage => 'Add image';

  @override
  String get actionRemove => 'Remove';

  @override
  String get labelNewAudioSelected => 'New audio clip selected';

  @override
  String get labelAudioAttached => 'Audio clip attached';

  @override
  String get labelNoAudio => 'No audio clip';

  @override
  String get actionReplaceAudio => 'Replace';

  @override
  String get actionAddAudio => 'Add audio';

  @override
  String get tooltipRemoveAudio => 'Remove audio';

  @override
  String get titleAdditionalQuestions => 'Additional Questions';

  @override
  String get actionUseTemplate => 'Use Template';

  @override
  String get tabCardTemplates => 'Card Templates';

  @override
  String get tabQuestionTemplates => 'Question Templates';

  @override
  String get messageNoCardTemplatesYet => 'No card templates yet.';

  @override
  String get messageNoQuestionTemplatesYet => 'No question templates yet.';

  @override
  String get titleReplaceQuestions => 'Replace questions?';

  @override
  String messageReplaceQuestionsConfirm(String name) {
    return 'Apply \"$name\"? Your current questions will be replaced.';
  }

  @override
  String get actionReplace => 'Replace';

  @override
  String get labelCorrectAnswersRequired =>
      'Correct answers * (comma-separated)';

  @override
  String get hintCorrectAnswersExample => 'e.g. hablo, Hablo';

  @override
  String get validatorAtLeastOneAnswer => 'At least one answer is required';

  @override
  String get labelHintOptional => 'Hint (optional)';

  @override
  String get labelExactMatch => 'Exact match';

  @override
  String get messageExactMatchSubtitle => 'Case-sensitive answer check';

  @override
  String get labelOptionsRequired => 'Options * (select the correct one)';

  @override
  String labelOptionNumber(int number) {
    return 'Option $number';
  }

  @override
  String get validatorOptionTextRequired => 'Option text required';

  @override
  String get actionAddOption => 'Add option';

  @override
  String get labelQuestionLabelOptional => 'Label (optional)';

  @override
  String get hintQuestionLabelExample => 'e.g. Gender, Conjugation';

  @override
  String get tooltipRemoveQuestion => 'Remove question';

  @override
  String get labelQuestionType => 'Question type';

  @override
  String get labelQuestionTypeTextInput => 'Text input';

  @override
  String get labelQuestionTypeMultipleChoice => 'Multiple choice';

  @override
  String get labelQuestionTypeWordOrder => 'Word order';

  @override
  String get actionAddQuestion => 'Add Question';

  @override
  String messageSelectCorrectOptionLabeled(String label) {
    return 'Question \"$label\": select the correct option.';
  }

  @override
  String messageSelectCorrectOptionNumber(int number) {
    return 'Question $number: select the correct option.';
  }

  @override
  String get titleNewWorkbookCard => 'New Workbook Card';

  @override
  String get titleEditWorkbookCard => 'Edit Workbook Card';

  @override
  String get titleDeleteWorkbookCard => 'Delete Workbook Card';

  @override
  String get messageDeleteWorkbookCardConfirm =>
      'Delete this card? It will be removed from all sets and cannot be undone.';

  @override
  String get labelDisplay => 'Display:';

  @override
  String get labelDisplayList => 'List';

  @override
  String get labelDisplayChips => 'Chips';

  @override
  String get labelExplanationOptional => 'Explanation (optional)';

  @override
  String get hintExplanationShownAfterAnswer => 'Shown after the user answers';

  @override
  String get labelWordBankRequired => 'Word Bank *';

  @override
  String get messageWordBankHelp =>
      'Add all tiles — correct words plus any distractors';

  @override
  String get hintAddWordTile => 'Add a word tile';

  @override
  String get labelCorrectOrderRequired => 'Correct Order *';

  @override
  String get actionClear => 'Clear';

  @override
  String get messageCorrectOrderHelp =>
      'Tap tiles from the word bank to build the answer in order';

  @override
  String get messageAddTilesToWordBankFirst =>
      'Add tiles to the word bank first';

  @override
  String get messageTapTilesBelow => 'Tap tiles below to set the answer order';

  @override
  String get labelAllTilesPlaced => 'All tiles placed';

  @override
  String labelQuestionNumber(int number) {
    return 'Question $number';
  }

  @override
  String get tooltipMoveUp => 'Move up';

  @override
  String get tooltipMoveDown => 'Move down';

  @override
  String get labelQuestionLabelFullOptional => 'Question label (optional)';

  @override
  String get hintQuestionLabelWorkbookExample =>
      'e.g. Choose the correct gender';

  @override
  String get titlePromptSection => 'Prompt';

  @override
  String get messagePromptSectionHelp =>
      'Task description shown before questions are revealed';

  @override
  String get labelPromptRequired => 'Prompt *';

  @override
  String get hintPromptExample => 'e.g. Read the sentence and answer below.';

  @override
  String get validatorPromptRequired => 'Prompt is required';

  @override
  String get titleQuestionsSection => 'Questions';

  @override
  String messageWordOrderNeedWordBank(int number) {
    return 'Question $number: add at least one tile to the word bank.';
  }

  @override
  String messageWordOrderNeedCorrectOrder(int number) {
    return 'Question $number: set the correct word order.';
  }

  @override
  String messageWordOrderWordNotInBank(int number, String word) {
    return 'Question $number: \"$word\" in correct order is not in the word bank.';
  }

  @override
  String get titleTemplates => 'Templates';

  @override
  String get tooltipCreateCardTemplate => 'Create card template';

  @override
  String get tooltipCreateQuestionTemplate => 'Create question template';

  @override
  String get errorFailedLoadTemplates => 'Failed to load templates.';

  @override
  String get errorFailedLoadQuestionTemplates =>
      'Failed to load question templates.';

  @override
  String get messageNoCardTemplatesEmptyState =>
      'No card templates yet.\nTap + to create one, or use \"Save as Template\" from any card.';

  @override
  String get messageNoQuestionTemplatesEmptyState =>
      'No question templates yet.\nTap + to create a reusable question.';

  @override
  String get titleEditTemplate => 'Edit Template';

  @override
  String get titleNewTemplate => 'New Template';

  @override
  String get tooltipDeleteTemplate => 'Delete template';

  @override
  String get titleTemplateDetails => 'Template Details';

  @override
  String get labelTemplateNameRequired => 'Template name *';

  @override
  String get hintTemplateNameExample => 'e.g. Spanish Verb';

  @override
  String get hintTemplateNameQTExample => 'e.g. Gender, Verb conjugation';

  @override
  String get validatorTemplateNameRequired => 'Name is required';

  @override
  String get labelHideWordByDefault => 'Hide primary word by default';

  @override
  String get messageHideWordByDefaultSubtitle =>
      'Cards created from this template start with the word hidden';

  @override
  String get messageTemplateQuestionsHelp =>
      'Define the structure. Answers are filled in per card.';

  @override
  String get messageNoQuestionTemplatesSnackbar =>
      'No question templates yet. Create one from the Question Templates tab.';

  @override
  String get titleChooseQuestionTemplate => 'Choose a Question Template';

  @override
  String get hintHintShownDuringStudy => 'Shown to the user during study';

  @override
  String get labelOptionsPreFilled =>
      'Options (pre-filled for all cards using this template)';

  @override
  String get titleDeleteTemplate => 'Delete Template';

  @override
  String messageDeleteTemplateConfirm(String name) {
    return 'Delete \"$name\"? Cards created from it keep their questions; this cannot be undone.';
  }

  @override
  String get errorFailedSaveTemplate =>
      'Failed to save template. Please try again.';

  @override
  String get errorFailedDeleteTemplate =>
      'Failed to delete template. Please try again.';

  @override
  String get actionCreateTemplate => 'Create Template';

  @override
  String get titleEditQuestionTemplate => 'Edit Question Template';

  @override
  String get titleNewQuestionTemplate => 'New Question Template';

  @override
  String get titleDeleteQuestionTemplate => 'Delete Question Template';

  @override
  String messageDeleteQuestionTemplateConfirm(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get titleQuestionSection => 'Question';

  @override
  String get labelImportIdOptional => 'Import ID (optional)';

  @override
  String get hintImportIdExample => 'e.g. gender';

  @override
  String get messageImportIdHelperText =>
      'Reference this template in import files as ##gender';

  @override
  String get validatorImportIdInvalid =>
      'Only letters, numbers, hyphens and underscores allowed';

  @override
  String messageImportIdConflict(String id) {
    return 'Import ID \"$id\" is already used by another template.';
  }

  @override
  String get messageTplWordOrderNote =>
      'Word bank entries are filled in per card.';

  @override
  String get titleStudy => 'Study';

  @override
  String get titleStudyASet => 'Study a Set';

  @override
  String get messageStudyASetSubtitle =>
      'Work through the cards in one of your sets.';

  @override
  String get titleStudyReview => 'Study Review';

  @override
  String get messageStudyReviewSubtitle =>
      'Focus on cards you have flagged for review.';

  @override
  String get titleStudyMistakes => 'Study Mistakes';

  @override
  String get messageStudyMistakesSubtitle =>
      'Drill questions you have answered incorrectly recently.';

  @override
  String get labelComingSoon => 'Soon';

  @override
  String get messageNoSetsYetStudy =>
      'No sets yet — create one in My Sets first.';

  @override
  String get titleChooseSet => 'Choose a Set';

  @override
  String get tooltipSessionHistory => 'Session history';

  @override
  String get labelShuffleCards => 'Shuffle cards';

  @override
  String get messageShuffleCardsSubtitle =>
      'Randomise card order for this session';

  @override
  String get actionStartNewSession => 'Start New Session';

  @override
  String get actionStartSession => 'Start Session';

  @override
  String get errorFailedStartSession =>
      'Failed to start session. Please try again.';

  @override
  String get messageAddCardsBeforeStudying =>
      'Add cards to this set before studying.';

  @override
  String get labelSessionInProgress => 'Session in progress';

  @override
  String messageCardsReviewed(int done, int total) {
    return '$done of $total cards reviewed';
  }

  @override
  String get actionResume => 'Resume';

  @override
  String titleSetHistory(String name) {
    return '$name — History';
  }

  @override
  String get errorFailedLoadHistory => 'Failed to load history.';

  @override
  String get messageNoSessionsYet =>
      'No sessions yet.\nStart studying to build your history.';

  @override
  String get labelCompleted => 'Completed';

  @override
  String get labelInProgress => 'In Progress';

  @override
  String labelStudiedOfTotal(int studied, int total) {
    return '$studied / $total cards';
  }

  @override
  String get actionEnd => 'End';

  @override
  String get messageCardNotFound => 'Card not found.';

  @override
  String get messageSaveProgressFailed =>
      'Saving progress failed — check your connection.';

  @override
  String get actionDismiss => 'Dismiss';

  @override
  String get semanticsRevealForeignWord => 'reveal foreign word';

  @override
  String get semanticsRevealTranslation => 'reveal translation';

  @override
  String get actionShowHint => 'Show Hint';

  @override
  String get actionShowWord => 'Show Word';

  @override
  String get labelTapToReveal => 'Tap to reveal';

  @override
  String get labelKnewIt => 'Knew it';

  @override
  String get labelNotYet => 'Not yet';

  @override
  String get actionMore => 'More';

  @override
  String get tooltipPreviousCard => 'Previous card';

  @override
  String semanticsCardOf(int current, int total) {
    return 'Card $current of $total';
  }

  @override
  String labelCardProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get tooltipFinishSession => 'Finish session';

  @override
  String get tooltipNextCard => 'Next card';

  @override
  String get labelTapWordsToBuild => 'Tap words below to build your answer';

  @override
  String get tooltipTapToReturn => 'Tap to return';

  @override
  String get labelYourAnswer => 'Your answer:';

  @override
  String get labelWordBank => 'Word bank:';

  @override
  String get semanticsOptionCorrect => ', correct';

  @override
  String get semanticsOptionIncorrect => ', incorrect';

  @override
  String get hintTypeYourAnswer => 'Type your answer';

  @override
  String get actionCheck => 'Check';

  @override
  String get actionTryAgain => 'Try Again';

  @override
  String messageAnswerReveal(String answer) {
    return 'Answer: $answer';
  }

  @override
  String get titleSessionComplete => 'Session Complete';

  @override
  String get actionDone => 'Done';

  @override
  String get labelCardsStudied => 'Cards studied';

  @override
  String get labelSkippedStat => 'Skipped';

  @override
  String get labelQuestionsStat => 'Questions';

  @override
  String get labelTimeStat => 'Time';

  @override
  String get actionStudyAgain => 'Study Again';

  @override
  String get titleImportExport => 'Import & Export';

  @override
  String get titleImport => 'Import';

  @override
  String get messageImportDescription =>
      'Import a ZIP archive exported from Agora. New sets are created automatically; existing sets are matched by name.';

  @override
  String get actionChooseZipFile => 'Choose ZIP file…';

  @override
  String get titleExport => 'Export';

  @override
  String get messageExportDescription =>
      'Select sets to export as a ZIP archive. The archive can be re-imported into any Agora account.';

  @override
  String get messageNoSetsYetExport =>
      'No sets yet — create a set to export it.';

  @override
  String get actionDeselectAll => 'Deselect all';

  @override
  String get actionSelectAll => 'Select all';

  @override
  String get labelNoneSelected => 'None selected';

  @override
  String labelNOfMSelected(int count, int total) {
    return '$count of $total selected';
  }

  @override
  String actionExportN(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Export $count sets',
      one: 'Export 1 set',
      zero: 'Export',
    );
    return '$_temp0';
  }

  @override
  String get messageExporting => 'Exporting…';

  @override
  String messageExportSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get messageExportReady => 'Export ready.';

  @override
  String get messageAnalysingArchive => 'Analysing archive…';

  @override
  String get errorFailedReadArchive =>
      'Failed to read the archive. Check the file format and try again.';

  @override
  String get titleImportPreview => 'Import Preview';

  @override
  String get labelSkipCardUpdates => 'Skip card updates';

  @override
  String get messageSkipCardUpdatesSubtitle =>
      'Only create new cards; leave existing cards unchanged.';

  @override
  String get labelRemoveCardsNotInImport => 'Remove cards not in import';

  @override
  String get messageRemoveCardsNotInImportSubtitle =>
      'Cards absent from the file are removed from the set (not deleted from your library).';

  @override
  String get actionImport => 'Import';

  @override
  String get labelNewSet => 'New set';

  @override
  String get labelExistingSet => 'Existing';

  @override
  String labelNNew(int count) {
    return '$count new';
  }

  @override
  String labelNFromLibrary(int count) {
    return '$count from library';
  }

  @override
  String labelNUpdated(int count) {
    return '$count updated';
  }

  @override
  String labelNUpdatedSkipped(int count) {
    return '$count updated (skipped)';
  }

  @override
  String labelNToRemove(int count) {
    return '$count to remove';
  }

  @override
  String get labelNoChanges => 'No changes';

  @override
  String labelNNewCardTemplates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new card templates',
      one: '1 new card template',
    );
    return '$_temp0';
  }

  @override
  String labelNNewQuestionTemplates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new question templates',
      one: '1 new question template',
    );
    return '$_temp0';
  }

  @override
  String get labelQuestion => 'Question';

  @override
  String messageAlsoIn(String sets) {
    return 'Also in: $sets';
  }

  @override
  String get titleImportComplete => 'Import Complete';

  @override
  String messageSetsProcessed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets processed',
      one: '1 set processed',
    );
    return '$_temp0';
  }

  @override
  String labelNewCount(int count) {
    return '($count new)';
  }

  @override
  String get messageNoChangesApplied => 'No changes were applied';

  @override
  String messageCardsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards added',
      one: '1 card added',
    );
    return '$_temp0';
  }

  @override
  String messageCardsLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards linked from library',
      one: '1 card linked from library',
    );
    return '$_temp0';
  }

  @override
  String messageCardsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards updated',
      one: '1 card updated',
    );
    return '$_temp0';
  }

  @override
  String messageCardsRemovedFromSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards removed from sets',
      one: '1 card removed from sets',
    );
    return '$_temp0';
  }

  @override
  String messageCardTemplatesCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count card templates created',
      one: '1 card template created',
    );
    return '$_temp0';
  }

  @override
  String messageQuestionTemplatesCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count question templates created',
      one: '1 question template created',
    );
    return '$_temp0';
  }

  @override
  String get errorImportFailed => 'Import failed. Please try again.';
}
