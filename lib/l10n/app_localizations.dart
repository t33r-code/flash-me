import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @statusLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get statusLoading;

  /// No description provided for @labelError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get labelError;

  /// No description provided for @labelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get labelSuccess;

  /// No description provided for @labelCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get labelCancel;

  /// No description provided for @labelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get labelConfirm;

  /// No description provided for @labelDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get labelDelete;

  /// No description provided for @labelEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get labelEdit;

  /// No description provided for @labelSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get labelSave;

  /// No description provided for @labelClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get labelClose;

  /// No description provided for @titleWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Agora'**
  String get titleWelcome;

  /// No description provided for @actionSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get actionSignUp;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get actionSignIn;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get actionSignOut;

  /// No description provided for @actionSignUpWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign Up with Google'**
  String get actionSignUpWithGoogle;

  /// No description provided for @actionSignInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign In with Google'**
  String get actionSignInWithGoogle;

  /// No description provided for @labelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get labelEmail;

  /// No description provided for @labelPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get labelPassword;

  /// No description provided for @labelConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get labelConfirmPassword;

  /// No description provided for @actionForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get actionForgotPassword;

  /// No description provided for @titleMySets.
  ///
  /// In en, this message translates to:
  /// **'My Sets'**
  String get titleMySets;

  /// No description provided for @actionNewSet.
  ///
  /// In en, this message translates to:
  /// **'New Set'**
  String get actionNewSet;

  /// No description provided for @actionCreateSet.
  ///
  /// In en, this message translates to:
  /// **'Create Set'**
  String get actionCreateSet;

  /// No description provided for @labelSetName.
  ///
  /// In en, this message translates to:
  /// **'Set Name'**
  String get labelSetName;

  /// No description provided for @labelSetDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get labelSetDescription;

  /// No description provided for @messageNoSets.
  ///
  /// In en, this message translates to:
  /// **'No sets yet. Create one to get started!'**
  String get messageNoSets;

  /// No description provided for @labelCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get labelCards;

  /// No description provided for @actionNewCard.
  ///
  /// In en, this message translates to:
  /// **'New Card'**
  String get actionNewCard;

  /// No description provided for @actionCreateCard.
  ///
  /// In en, this message translates to:
  /// **'Create Card'**
  String get actionCreateCard;

  /// No description provided for @actionDeleteCard.
  ///
  /// In en, this message translates to:
  /// **'Delete Card'**
  String get actionDeleteCard;

  /// No description provided for @labelPrimaryWord.
  ///
  /// In en, this message translates to:
  /// **'Foreign Word'**
  String get labelPrimaryWord;

  /// No description provided for @labelTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get labelTranslation;

  /// No description provided for @messageNoCards.
  ///
  /// In en, this message translates to:
  /// **'No cards in this set'**
  String get messageNoCards;

  /// No description provided for @labelStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get labelStudy;

  /// No description provided for @actionStartStudy.
  ///
  /// In en, this message translates to:
  /// **'Start Study'**
  String get actionStartStudy;

  /// No description provided for @actionResumeSession.
  ///
  /// In en, this message translates to:
  /// **'Resume Session'**
  String get actionResumeSession;

  /// No description provided for @actionNewSession.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get actionNewSession;

  /// No description provided for @actionNextCard.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNextCard;

  /// No description provided for @actionPreviousCard.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get actionPreviousCard;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get actionReview;

  /// No description provided for @actionCheckAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check Answer'**
  String get actionCheckAnswer;

  /// No description provided for @actionShowAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show Answer'**
  String get actionShowAnswer;

  /// No description provided for @labelCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get labelCorrect;

  /// No description provided for @labelIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get labelIncorrect;

  /// No description provided for @actionEndSession.
  ///
  /// In en, this message translates to:
  /// **'End Session'**
  String get actionEndSession;

  /// No description provided for @messageErrorLoadingApp.
  ///
  /// In en, this message translates to:
  /// **'Error loading app. Please restart.'**
  String get messageErrorLoadingApp;

  /// No description provided for @titleResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get titleResetPassword;

  /// No description provided for @actionSendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Email'**
  String get actionSendResetEmail;

  /// No description provided for @messagePasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get messagePasswordResetSent;

  /// No description provided for @messageFailedSendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email. Please try again.'**
  String get messageFailedSendResetEmail;

  /// No description provided for @messageSignInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get messageSignInToContinue;

  /// No description provided for @messageCreateYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get messageCreateYourAccount;

  /// No description provided for @validatorConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get validatorConfirmPassword;

  /// No description provided for @validatorPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validatorPasswordsDoNotMatch;

  /// No description provided for @labelOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get labelOr;

  /// No description provided for @messageNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get messageNoAccount;

  /// No description provided for @messageHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get messageHaveAccount;

  /// No description provided for @errorInvalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get errorInvalidCredential;

  /// No description provided for @errorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get errorEmailInUse;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use at least 6 characters.'**
  String get errorWeakPassword;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errorInvalidEmail;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get errorTooManyRequests;

  /// No description provided for @errorNetworkFailed.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get errorNetworkFailed;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get errorUnexpected;

  /// No description provided for @errorGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get errorGoogleSignInFailed;

  /// No description provided for @navSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get navSets;

  /// No description provided for @navCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get navCards;

  /// No description provided for @navStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get navStudy;

  /// No description provided for @navTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get navTemplates;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @actionImportSets.
  ///
  /// In en, this message translates to:
  /// **'Import Sets'**
  String get actionImportSets;

  /// No description provided for @actionExportSets.
  ///
  /// In en, this message translates to:
  /// **'Export Sets'**
  String get actionExportSets;

  /// No description provided for @actionChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get actionChooseFile;

  /// No description provided for @labelSelectFormat.
  ///
  /// In en, this message translates to:
  /// **'Select Format'**
  String get labelSelectFormat;

  /// No description provided for @labelJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get labelJson;

  /// No description provided for @labelCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get labelCsv;

  /// No description provided for @titleProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get titleProfile;

  /// No description provided for @tooltipEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get tooltipEditProfile;

  /// No description provided for @errorFailedLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile.'**
  String get errorFailedLoadProfile;

  /// No description provided for @messageProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get messageProfileUpdated;

  /// No description provided for @messageFailedUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile. Please try again.'**
  String get messageFailedUpdateProfile;

  /// No description provided for @messageSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign out failed. Please try again.'**
  String get messageSignOutFailed;

  /// No description provided for @titleDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get titleDeleteAccount;

  /// No description provided for @messageDeleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete:\n• All your cards and card sets\n• All templates and study history\n• Your profile and account\n\nPublic sets you have published will be unpublished first. This cannot be undone.'**
  String get messageDeleteAccountConfirm;

  /// No description provided for @actionDeleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get actionDeleteMyAccount;

  /// No description provided for @actionDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get actionDeleteAccount;

  /// No description provided for @messageRecentLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign out and sign back in before deleting your account.'**
  String get messageRecentLoginRequired;

  /// No description provided for @messageFailedDeleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {errorMessage}'**
  String messageFailedDeleteAccountError(String errorMessage);

  /// No description provided for @messageFailedDeleteAccountGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again.'**
  String get messageFailedDeleteAccountGeneric;

  /// No description provided for @labelDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get labelDisplayName;

  /// No description provided for @labelNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get labelNotSet;

  /// No description provided for @labelImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import & Export'**
  String get labelImportExport;

  /// No description provided for @messageImportExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import or export card sets as ZIP files'**
  String get messageImportExportSubtitle;

  /// No description provided for @labelTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get labelTheme;

  /// No description provided for @labelThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get labelThemeSystem;

  /// No description provided for @labelThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get labelThemeLight;

  /// No description provided for @labelThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get labelThemeDark;

  /// No description provided for @tabMySets.
  ///
  /// In en, this message translates to:
  /// **'My Sets'**
  String get tabMySets;

  /// No description provided for @tabMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get tabMarket;

  /// No description provided for @tooltipSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get tooltipSortBy;

  /// No description provided for @labelSortLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get labelSortLastUpdated;

  /// No description provided for @labelSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labelSortName;

  /// No description provided for @labelSortCardCount.
  ///
  /// In en, this message translates to:
  /// **'Card count'**
  String get labelSortCardCount;

  /// No description provided for @tooltipCreateSet.
  ///
  /// In en, this message translates to:
  /// **'Create set'**
  String get tooltipCreateSet;

  /// No description provided for @hintSearchSets.
  ///
  /// In en, this message translates to:
  /// **'Search sets…'**
  String get hintSearchSets;

  /// No description provided for @hintSearchMarket.
  ///
  /// In en, this message translates to:
  /// **'Search market…'**
  String get hintSearchMarket;

  /// No description provided for @labelAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get labelAll;

  /// No description provided for @messageNoSetsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No sets match your search.'**
  String get messageNoSetsMatchSearch;

  /// No description provided for @errorFailedLoadSets.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sets.'**
  String get errorFailedLoadSets;

  /// No description provided for @errorFailedLoadMarket.
  ///
  /// In en, this message translates to:
  /// **'Failed to load market.'**
  String get errorFailedLoadMarket;

  /// No description provided for @titleNoSetsYet.
  ///
  /// In en, this message translates to:
  /// **'No sets yet'**
  String get titleNoSetsYet;

  /// No description provided for @messageNoSetsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first set.'**
  String get messageNoSetsHint;

  /// No description provided for @titleMarketEmpty.
  ///
  /// In en, this message translates to:
  /// **'Market is empty'**
  String get titleMarketEmpty;

  /// No description provided for @messageMarketEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sets have been published yet.\nPublish your own from a set\'s detail screen.'**
  String get messageMarketEmpty;

  /// No description provided for @tooltipOfferedInMarket.
  ///
  /// In en, this message translates to:
  /// **'Offered in Market'**
  String get tooltipOfferedInMarket;

  /// No description provided for @labelInMarket.
  ///
  /// In en, this message translates to:
  /// **'In Market'**
  String get labelInMarket;

  /// No description provided for @labelToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get labelToday;

  /// No description provided for @labelYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get labelYesterday;

  /// No description provided for @labelMonthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get labelMonthJan;

  /// No description provided for @labelMonthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get labelMonthFeb;

  /// No description provided for @labelMonthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get labelMonthMar;

  /// No description provided for @labelMonthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get labelMonthApr;

  /// No description provided for @labelMonthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get labelMonthMay;

  /// No description provided for @labelMonthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get labelMonthJun;

  /// No description provided for @labelMonthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get labelMonthJul;

  /// No description provided for @labelMonthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get labelMonthAug;

  /// No description provided for @labelMonthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get labelMonthSep;

  /// No description provided for @labelMonthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get labelMonthOct;

  /// No description provided for @labelMonthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get labelMonthNov;

  /// No description provided for @labelMonthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get labelMonthDec;

  /// No description provided for @labelAcquiredCloned.
  ///
  /// In en, this message translates to:
  /// **'Cloned {date}'**
  String labelAcquiredCloned(String date);

  /// No description provided for @labelAcquiredSubscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscribed {date}'**
  String labelAcquiredSubscribed(String date);

  /// No description provided for @labelCardCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card} other{{count} cards}}'**
  String labelCardCount(int count);

  /// No description provided for @labelQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question} other{{count} questions}}'**
  String labelQuestionCount(int count);

  /// No description provided for @titleNewSet.
  ///
  /// In en, this message translates to:
  /// **'New Set'**
  String get titleNewSet;

  /// No description provided for @titleEditSet.
  ///
  /// In en, this message translates to:
  /// **'Edit Set'**
  String get titleEditSet;

  /// No description provided for @labelSetNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Set name *'**
  String get labelSetNameRequired;

  /// No description provided for @hintSetNameExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Spanish Verbs'**
  String get hintSetNameExample;

  /// No description provided for @validatorSetNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get validatorSetNameRequired;

  /// No description provided for @labelDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get labelDescriptionOptional;

  /// No description provided for @titleLanguagesSection.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get titleLanguagesSection;

  /// No description provided for @labelTargetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target language (being studied)'**
  String get labelTargetLanguage;

  /// No description provided for @labelNativeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Native language'**
  String get labelNativeLanguage;

  /// No description provided for @titleColorSection.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get titleColorSection;

  /// No description provided for @titleTagsSection.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get titleTagsSection;

  /// No description provided for @errorFailedSaveSet.
  ///
  /// In en, this message translates to:
  /// **'Failed to save set. Please try again.'**
  String get errorFailedSaveSet;

  /// No description provided for @actionSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get actionSaveChanges;

  /// No description provided for @semanticsColorNone.
  ///
  /// In en, this message translates to:
  /// **'No colour'**
  String get semanticsColorNone;

  /// No description provided for @semanticsColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get semanticsColorRed;

  /// No description provided for @semanticsColorDeepOrange.
  ///
  /// In en, this message translates to:
  /// **'Deep orange'**
  String get semanticsColorDeepOrange;

  /// No description provided for @semanticsColorAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get semanticsColorAmber;

  /// No description provided for @semanticsColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get semanticsColorGreen;

  /// No description provided for @semanticsColorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get semanticsColorTeal;

  /// No description provided for @semanticsColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get semanticsColorBlue;

  /// No description provided for @semanticsColorIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get semanticsColorIndigo;

  /// No description provided for @semanticsColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get semanticsColorPurple;

  /// No description provided for @semanticsColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get semanticsColorPink;

  /// No description provided for @semanticsColorSelected.
  ///
  /// In en, this message translates to:
  /// **'{colorName}, selected'**
  String semanticsColorSelected(String colorName);

  /// No description provided for @titleDeleteSet.
  ///
  /// In en, this message translates to:
  /// **'Delete Set'**
  String get titleDeleteSet;

  /// No description provided for @messageDeleteSetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Cards are not deleted, only removed from this set.'**
  String messageDeleteSetConfirm(String name);

  /// No description provided for @errorFailedDeleteSet.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete set. Please try again.'**
  String get errorFailedDeleteSet;

  /// No description provided for @errorFailedRemoveCard.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove card.'**
  String get errorFailedRemoveCard;

  /// No description provided for @messagePreparingExport.
  ///
  /// In en, this message translates to:
  /// **'Preparing export…'**
  String get messagePreparingExport;

  /// No description provided for @messageSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String messageSavedTo(String path);

  /// No description provided for @errorExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Please try again.'**
  String get errorExportFailed;

  /// No description provided for @titleRemoveFromMarket.
  ///
  /// In en, this message translates to:
  /// **'Remove from Market'**
  String get titleRemoveFromMarket;

  /// No description provided for @messageRemoveFromMarketAcquired.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has been acquired by {count, plural, =1{1 user} other{{count} users}}. Removing it from the Market will not affect their copies — this set will simply stop appearing to new users.'**
  String messageRemoveFromMarketAcquired(String name, int count);

  /// No description provided for @messageRemoveFromMarketNoAcquisitions.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from the Market? It will no longer appear for other users.'**
  String messageRemoveFromMarketNoAcquisitions(String name);

  /// No description provided for @errorFailedPublish.
  ///
  /// In en, this message translates to:
  /// **'Failed to publish. Please try again.'**
  String get errorFailedPublish;

  /// No description provided for @errorFailedRemoveFromMarket.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove from Market. Please try again.'**
  String get errorFailedRemoveFromMarket;

  /// No description provided for @tooltipRemoveFromMarket.
  ///
  /// In en, this message translates to:
  /// **'Remove from Market'**
  String get tooltipRemoveFromMarket;

  /// No description provided for @tooltipOfferInMarket.
  ///
  /// In en, this message translates to:
  /// **'Offer in Market'**
  String get tooltipOfferInMarket;

  /// No description provided for @tooltipExportSet.
  ///
  /// In en, this message translates to:
  /// **'Export set'**
  String get tooltipExportSet;

  /// No description provided for @tooltipDeleteSet.
  ///
  /// In en, this message translates to:
  /// **'Delete set'**
  String get tooltipDeleteSet;

  /// No description provided for @tooltipEditSet.
  ///
  /// In en, this message translates to:
  /// **'Edit set'**
  String get tooltipEditSet;

  /// No description provided for @tooltipStudyThisSet.
  ///
  /// In en, this message translates to:
  /// **'Study this set'**
  String get tooltipStudyThisSet;

  /// No description provided for @tooltipAddCards.
  ///
  /// In en, this message translates to:
  /// **'Add cards'**
  String get tooltipAddCards;

  /// No description provided for @titleNoCardsYet.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get titleNoCardsYet;

  /// No description provided for @messageNoCardsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add cards to this set.'**
  String get messageNoCardsHint;

  /// No description provided for @actionAddCards.
  ///
  /// In en, this message translates to:
  /// **'Add Cards'**
  String get actionAddCards;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionAddCount.
  ///
  /// In en, this message translates to:
  /// **'Add ({count})'**
  String actionAddCount(int count);

  /// No description provided for @errorFailedLoadCards.
  ///
  /// In en, this message translates to:
  /// **'Failed to load cards.'**
  String get errorFailedLoadCards;

  /// No description provided for @messageNoCardsYetTab.
  ///
  /// In en, this message translates to:
  /// **'No cards yet. Create cards from the Cards tab.'**
  String get messageNoCardsYetTab;

  /// No description provided for @messageAllCardsInSet.
  ///
  /// In en, this message translates to:
  /// **'All your cards are already in this set.'**
  String get messageAllCardsInSet;

  /// No description provided for @labelSectionFlashCards.
  ///
  /// In en, this message translates to:
  /// **'Flash Cards'**
  String get labelSectionFlashCards;

  /// No description provided for @labelSectionWorkbookCards.
  ///
  /// In en, this message translates to:
  /// **'Workbook Cards'**
  String get labelSectionWorkbookCards;

  /// No description provided for @labelDuplicateWordInSet.
  ///
  /// In en, this message translates to:
  /// **'Duplicate word — already in set'**
  String get labelDuplicateWordInSet;

  /// No description provided for @labelAlreadyInSet.
  ///
  /// In en, this message translates to:
  /// **'Already in set'**
  String get labelAlreadyInSet;

  /// No description provided for @labelAllowClone.
  ///
  /// In en, this message translates to:
  /// **'Allow Clone'**
  String get labelAllowClone;

  /// No description provided for @messageAllowCloneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Users can copy this set into their own library.'**
  String get messageAllowCloneSubtitle;

  /// No description provided for @titleOfferInMarket.
  ///
  /// In en, this message translates to:
  /// **'Offer in Market'**
  String get titleOfferInMarket;

  /// No description provided for @messageOfferInMarketDescription.
  ///
  /// In en, this message translates to:
  /// **'Make \"{name}\" visible in the Market tab so other users can discover and acquire it.'**
  String messageOfferInMarketDescription(String name);

  /// No description provided for @titleOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get titleOptions;

  /// No description provided for @actionOfferInMarket.
  ///
  /// In en, this message translates to:
  /// **'Offer in Market'**
  String get actionOfferInMarket;

  /// No description provided for @titleCloneSet.
  ///
  /// In en, this message translates to:
  /// **'Clone Set'**
  String get titleCloneSet;

  /// No description provided for @infoCloneAddedToMySets.
  ///
  /// In en, this message translates to:
  /// **'A copy of this set is added to your My Sets.'**
  String get infoCloneAddedToMySets;

  /// No description provided for @infoCloneFullyEditable.
  ///
  /// In en, this message translates to:
  /// **'Your copy is fully editable and independent.'**
  String get infoCloneFullyEditable;

  /// No description provided for @infoCloneNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes to the original won\'t affect your copy.'**
  String get infoCloneNoChanges;

  /// No description provided for @actionCloneToMySets.
  ///
  /// In en, this message translates to:
  /// **'Clone to My Sets'**
  String get actionCloneToMySets;

  /// No description provided for @labelCloning.
  ///
  /// In en, this message translates to:
  /// **'Cloning…'**
  String get labelCloning;

  /// No description provided for @messageCloneSuccess.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" added to My Sets.'**
  String messageCloneSuccess(String name);

  /// No description provided for @errorFailedCloneSet.
  ///
  /// In en, this message translates to:
  /// **'Failed to clone set. Please try again.'**
  String get errorFailedCloneSet;

  /// No description provided for @titleAlreadyHaveSet.
  ///
  /// In en, this message translates to:
  /// **'You Already Have This Set'**
  String get titleAlreadyHaveSet;

  /// No description provided for @infoAlreadyHaveCopy.
  ///
  /// In en, this message translates to:
  /// **'You already have a copy of this set in My Sets.'**
  String get infoAlreadyHaveCopy;

  /// No description provided for @messageCheckingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get messageCheckingForUpdates;

  /// No description provided for @messageSetNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This set is no longer available — the creator\'s account has been deleted.'**
  String get messageSetNoLongerAvailable;

  /// No description provided for @messageCouldNotCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates. Please try again later.'**
  String get messageCouldNotCheckUpdates;

  /// No description provided for @labelOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get labelOk;

  /// No description provided for @messageNewCardsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new card added to the original since you cloned it.} other{{count} new cards added to the original since you cloned it.}}'**
  String messageNewCardsAdded(int count);

  /// No description provided for @messageCardsUpdatedSinceClone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card updated in the original since you cloned it.} other{{count} cards updated in the original since you cloned it.}}'**
  String messageCardsUpdatedSinceClone(int count);

  /// No description provided for @infoUpdateInPlace.
  ///
  /// In en, this message translates to:
  /// **'Your existing set will be updated in place. No new set will be created.'**
  String get infoUpdateInPlace;

  /// No description provided for @actionUpdateMyCopy.
  ///
  /// In en, this message translates to:
  /// **'Update My Copy'**
  String get actionUpdateMyCopy;

  /// No description provided for @labelUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get labelUpdating;

  /// No description provided for @messageUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" updated.'**
  String messageUpdateSuccess(String name);

  /// No description provided for @errorFailedUpdateSet.
  ///
  /// In en, this message translates to:
  /// **'Failed to update set. Please try again.'**
  String get errorFailedUpdateSet;

  /// No description provided for @infoUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Your copy is up to date.'**
  String get infoUpToDate;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
