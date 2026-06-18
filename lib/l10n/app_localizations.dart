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

  /// No description provided for @titleMyCards.
  ///
  /// In en, this message translates to:
  /// **'My Cards'**
  String get titleMyCards;

  /// No description provided for @titleCreateCard.
  ///
  /// In en, this message translates to:
  /// **'Create a card'**
  String get titleCreateCard;

  /// No description provided for @labelFlashCard.
  ///
  /// In en, this message translates to:
  /// **'Flash Card'**
  String get labelFlashCard;

  /// No description provided for @messageFlashCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Word + translation with optional fields'**
  String get messageFlashCardSubtitle;

  /// No description provided for @labelWorkbookCard.
  ///
  /// In en, this message translates to:
  /// **'Workbook Card'**
  String get labelWorkbookCard;

  /// No description provided for @messageWorkbookCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt with text, multiple choice, or word order questions'**
  String get messageWorkbookCardSubtitle;

  /// No description provided for @hintSearchCards.
  ///
  /// In en, this message translates to:
  /// **'Search cards…'**
  String get hintSearchCards;

  /// No description provided for @messageNoCardsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No cards match your search.'**
  String get messageNoCardsMatchSearch;

  /// No description provided for @messageNoCardsYetCreate.
  ///
  /// In en, this message translates to:
  /// **'No cards yet. Tap + to create your first card.'**
  String get messageNoCardsYetCreate;

  /// No description provided for @tooltipCreateCard.
  ///
  /// In en, this message translates to:
  /// **'Create card'**
  String get tooltipCreateCard;

  /// No description provided for @titleNewCard.
  ///
  /// In en, this message translates to:
  /// **'New Card'**
  String get titleNewCard;

  /// No description provided for @titleEditCard.
  ///
  /// In en, this message translates to:
  /// **'Edit Card'**
  String get titleEditCard;

  /// No description provided for @titleDeleteCard.
  ///
  /// In en, this message translates to:
  /// **'Delete Card'**
  String get titleDeleteCard;

  /// No description provided for @messageDeleteCardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? It will be removed from all sets and cannot be undone.'**
  String messageDeleteCardConfirm(String name);

  /// No description provided for @errorFailedSaveCard.
  ///
  /// In en, this message translates to:
  /// **'Failed to save card. Please try again.'**
  String get errorFailedSaveCard;

  /// No description provided for @errorFailedDeleteCard.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete card. Please try again.'**
  String get errorFailedDeleteCard;

  /// No description provided for @tooltipDeleteCard.
  ///
  /// In en, this message translates to:
  /// **'Delete card'**
  String get tooltipDeleteCard;

  /// No description provided for @actionSaveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as Template'**
  String get actionSaveAsTemplate;

  /// No description provided for @titlePrimaryField.
  ///
  /// In en, this message translates to:
  /// **'Primary Field'**
  String get titlePrimaryField;

  /// No description provided for @labelForeignWordRequired.
  ///
  /// In en, this message translates to:
  /// **'Foreign word *'**
  String get labelForeignWordRequired;

  /// No description provided for @hintForeignWordExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. hablar'**
  String get hintForeignWordExample;

  /// No description provided for @validatorForeignWordRequired.
  ///
  /// In en, this message translates to:
  /// **'Foreign word is required'**
  String get validatorForeignWordRequired;

  /// No description provided for @labelTranslationRequired.
  ///
  /// In en, this message translates to:
  /// **'Translation *'**
  String get labelTranslationRequired;

  /// No description provided for @hintTranslationExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. to speak'**
  String get hintTranslationExample;

  /// No description provided for @validatorTranslationRequired.
  ///
  /// In en, this message translates to:
  /// **'Translation is required'**
  String get validatorTranslationRequired;

  /// No description provided for @labelHideHintWord.
  ///
  /// In en, this message translates to:
  /// **'Hide hint word during study'**
  String get labelHideHintWord;

  /// No description provided for @messageHideHintWordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show only the image/audio at first; reveal the text hint on demand'**
  String get messageHideHintWordSubtitle;

  /// No description provided for @titleMediaSection.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get titleMediaSection;

  /// No description provided for @messageMediaSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional image and audio for the primary field.'**
  String get messageMediaSectionSubtitle;

  /// No description provided for @actionReplaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get actionReplaceImage;

  /// No description provided for @actionAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get actionAddImage;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @labelNewAudioSelected.
  ///
  /// In en, this message translates to:
  /// **'New audio clip selected'**
  String get labelNewAudioSelected;

  /// No description provided for @labelAudioAttached.
  ///
  /// In en, this message translates to:
  /// **'Audio clip attached'**
  String get labelAudioAttached;

  /// No description provided for @labelNoAudio.
  ///
  /// In en, this message translates to:
  /// **'No audio clip'**
  String get labelNoAudio;

  /// No description provided for @actionReplaceAudio.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get actionReplaceAudio;

  /// No description provided for @actionAddAudio.
  ///
  /// In en, this message translates to:
  /// **'Add audio'**
  String get actionAddAudio;

  /// No description provided for @tooltipRemoveAudio.
  ///
  /// In en, this message translates to:
  /// **'Remove audio'**
  String get tooltipRemoveAudio;

  /// No description provided for @titleAdditionalQuestions.
  ///
  /// In en, this message translates to:
  /// **'Additional Questions'**
  String get titleAdditionalQuestions;

  /// No description provided for @actionUseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use Template'**
  String get actionUseTemplate;

  /// No description provided for @tabCardTemplates.
  ///
  /// In en, this message translates to:
  /// **'Card Templates'**
  String get tabCardTemplates;

  /// No description provided for @tabQuestionTemplates.
  ///
  /// In en, this message translates to:
  /// **'Question Templates'**
  String get tabQuestionTemplates;

  /// No description provided for @messageNoCardTemplatesYet.
  ///
  /// In en, this message translates to:
  /// **'No card templates yet.'**
  String get messageNoCardTemplatesYet;

  /// No description provided for @messageNoQuestionTemplatesYet.
  ///
  /// In en, this message translates to:
  /// **'No question templates yet.'**
  String get messageNoQuestionTemplatesYet;

  /// No description provided for @titleReplaceQuestions.
  ///
  /// In en, this message translates to:
  /// **'Replace questions?'**
  String get titleReplaceQuestions;

  /// No description provided for @messageReplaceQuestionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Apply \"{name}\"? Your current questions will be replaced.'**
  String messageReplaceQuestionsConfirm(String name);

  /// No description provided for @actionReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get actionReplace;

  /// No description provided for @labelCorrectAnswersRequired.
  ///
  /// In en, this message translates to:
  /// **'Correct answers * (comma-separated)'**
  String get labelCorrectAnswersRequired;

  /// No description provided for @hintCorrectAnswersExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. hablo, Hablo'**
  String get hintCorrectAnswersExample;

  /// No description provided for @validatorAtLeastOneAnswer.
  ///
  /// In en, this message translates to:
  /// **'At least one answer is required'**
  String get validatorAtLeastOneAnswer;

  /// No description provided for @labelHintOptional.
  ///
  /// In en, this message translates to:
  /// **'Hint (optional)'**
  String get labelHintOptional;

  /// No description provided for @labelExactMatch.
  ///
  /// In en, this message translates to:
  /// **'Exact match'**
  String get labelExactMatch;

  /// No description provided for @messageExactMatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Case-sensitive answer check'**
  String get messageExactMatchSubtitle;

  /// No description provided for @labelOptionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Options * (select the correct one)'**
  String get labelOptionsRequired;

  /// No description provided for @labelOptionNumber.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String labelOptionNumber(int number);

  /// No description provided for @validatorOptionTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Option text required'**
  String get validatorOptionTextRequired;

  /// No description provided for @actionAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get actionAddOption;

  /// No description provided for @labelQuestionLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get labelQuestionLabelOptional;

  /// No description provided for @hintQuestionLabelExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Gender, Conjugation'**
  String get hintQuestionLabelExample;

  /// No description provided for @tooltipRemoveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove question'**
  String get tooltipRemoveQuestion;

  /// No description provided for @labelQuestionType.
  ///
  /// In en, this message translates to:
  /// **'Question type'**
  String get labelQuestionType;

  /// No description provided for @labelQuestionTypeTextInput.
  ///
  /// In en, this message translates to:
  /// **'Text input'**
  String get labelQuestionTypeTextInput;

  /// No description provided for @labelQuestionTypeMultipleChoice.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get labelQuestionTypeMultipleChoice;

  /// No description provided for @labelQuestionTypeWordOrder.
  ///
  /// In en, this message translates to:
  /// **'Word order'**
  String get labelQuestionTypeWordOrder;

  /// No description provided for @actionAddQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add Question'**
  String get actionAddQuestion;

  /// No description provided for @messageSelectCorrectOptionLabeled.
  ///
  /// In en, this message translates to:
  /// **'Question \"{label}\": select the correct option.'**
  String messageSelectCorrectOptionLabeled(String label);

  /// No description provided for @messageSelectCorrectOptionNumber.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: select the correct option.'**
  String messageSelectCorrectOptionNumber(int number);

  /// No description provided for @titleNewWorkbookCard.
  ///
  /// In en, this message translates to:
  /// **'New Workbook Card'**
  String get titleNewWorkbookCard;

  /// No description provided for @titleEditWorkbookCard.
  ///
  /// In en, this message translates to:
  /// **'Edit Workbook Card'**
  String get titleEditWorkbookCard;

  /// No description provided for @titleDeleteWorkbookCard.
  ///
  /// In en, this message translates to:
  /// **'Delete Workbook Card'**
  String get titleDeleteWorkbookCard;

  /// No description provided for @messageDeleteWorkbookCardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this card? It will be removed from all sets and cannot be undone.'**
  String get messageDeleteWorkbookCardConfirm;

  /// No description provided for @labelDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display:'**
  String get labelDisplay;

  /// No description provided for @labelDisplayList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get labelDisplayList;

  /// No description provided for @labelDisplayChips.
  ///
  /// In en, this message translates to:
  /// **'Chips'**
  String get labelDisplayChips;

  /// No description provided for @labelExplanationOptional.
  ///
  /// In en, this message translates to:
  /// **'Explanation (optional)'**
  String get labelExplanationOptional;

  /// No description provided for @hintExplanationShownAfterAnswer.
  ///
  /// In en, this message translates to:
  /// **'Shown after the user answers'**
  String get hintExplanationShownAfterAnswer;

  /// No description provided for @labelWordBankRequired.
  ///
  /// In en, this message translates to:
  /// **'Word Bank *'**
  String get labelWordBankRequired;

  /// No description provided for @messageWordBankHelp.
  ///
  /// In en, this message translates to:
  /// **'Add all tiles — correct words plus any distractors'**
  String get messageWordBankHelp;

  /// No description provided for @hintAddWordTile.
  ///
  /// In en, this message translates to:
  /// **'Add a word tile'**
  String get hintAddWordTile;

  /// No description provided for @labelCorrectOrderRequired.
  ///
  /// In en, this message translates to:
  /// **'Correct Order *'**
  String get labelCorrectOrderRequired;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @messageCorrectOrderHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap tiles from the word bank to build the answer in order'**
  String get messageCorrectOrderHelp;

  /// No description provided for @messageAddTilesToWordBankFirst.
  ///
  /// In en, this message translates to:
  /// **'Add tiles to the word bank first'**
  String get messageAddTilesToWordBankFirst;

  /// No description provided for @messageTapTilesBelow.
  ///
  /// In en, this message translates to:
  /// **'Tap tiles below to set the answer order'**
  String get messageTapTilesBelow;

  /// No description provided for @labelAllTilesPlaced.
  ///
  /// In en, this message translates to:
  /// **'All tiles placed'**
  String get labelAllTilesPlaced;

  /// No description provided for @labelQuestionNumber.
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String labelQuestionNumber(int number);

  /// No description provided for @tooltipMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get tooltipMoveUp;

  /// No description provided for @tooltipMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get tooltipMoveDown;

  /// No description provided for @labelQuestionLabelFullOptional.
  ///
  /// In en, this message translates to:
  /// **'Question label (optional)'**
  String get labelQuestionLabelFullOptional;

  /// No description provided for @hintQuestionLabelWorkbookExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Choose the correct gender'**
  String get hintQuestionLabelWorkbookExample;

  /// No description provided for @titlePromptSection.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get titlePromptSection;

  /// No description provided for @messagePromptSectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Task description shown before questions are revealed'**
  String get messagePromptSectionHelp;

  /// No description provided for @labelPromptRequired.
  ///
  /// In en, this message translates to:
  /// **'Prompt *'**
  String get labelPromptRequired;

  /// No description provided for @hintPromptExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Read the sentence and answer below.'**
  String get hintPromptExample;

  /// No description provided for @validatorPromptRequired.
  ///
  /// In en, this message translates to:
  /// **'Prompt is required'**
  String get validatorPromptRequired;

  /// No description provided for @titleQuestionsSection.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get titleQuestionsSection;

  /// No description provided for @messageWordOrderNeedWordBank.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: add at least one tile to the word bank.'**
  String messageWordOrderNeedWordBank(int number);

  /// No description provided for @messageWordOrderNeedCorrectOrder.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: set the correct word order.'**
  String messageWordOrderNeedCorrectOrder(int number);

  /// No description provided for @messageWordOrderWordNotInBank.
  ///
  /// In en, this message translates to:
  /// **'Question {number}: \"{word}\" in correct order is not in the word bank.'**
  String messageWordOrderWordNotInBank(int number, String word);

  /// No description provided for @titleTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get titleTemplates;

  /// No description provided for @tooltipCreateCardTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create card template'**
  String get tooltipCreateCardTemplate;

  /// No description provided for @tooltipCreateQuestionTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create question template'**
  String get tooltipCreateQuestionTemplate;

  /// No description provided for @errorFailedLoadTemplates.
  ///
  /// In en, this message translates to:
  /// **'Failed to load templates.'**
  String get errorFailedLoadTemplates;

  /// No description provided for @errorFailedLoadQuestionTemplates.
  ///
  /// In en, this message translates to:
  /// **'Failed to load question templates.'**
  String get errorFailedLoadQuestionTemplates;

  /// No description provided for @messageNoCardTemplatesEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No card templates yet.\nTap + to create one, or use \"Save as Template\" from any card.'**
  String get messageNoCardTemplatesEmptyState;

  /// No description provided for @messageNoQuestionTemplatesEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No question templates yet.\nTap + to create a reusable question.'**
  String get messageNoQuestionTemplatesEmptyState;

  /// No description provided for @titleEditTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit Template'**
  String get titleEditTemplate;

  /// No description provided for @titleNewTemplate.
  ///
  /// In en, this message translates to:
  /// **'New Template'**
  String get titleNewTemplate;

  /// No description provided for @tooltipDeleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get tooltipDeleteTemplate;

  /// No description provided for @titleTemplateDetails.
  ///
  /// In en, this message translates to:
  /// **'Template Details'**
  String get titleTemplateDetails;

  /// No description provided for @labelTemplateNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Template name *'**
  String get labelTemplateNameRequired;

  /// No description provided for @hintTemplateNameExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Spanish Verb'**
  String get hintTemplateNameExample;

  /// No description provided for @hintTemplateNameQTExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Gender, Verb conjugation'**
  String get hintTemplateNameQTExample;

  /// No description provided for @validatorTemplateNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get validatorTemplateNameRequired;

  /// No description provided for @labelHideWordByDefault.
  ///
  /// In en, this message translates to:
  /// **'Hide primary word by default'**
  String get labelHideWordByDefault;

  /// No description provided for @messageHideWordByDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cards created from this template start with the word hidden'**
  String get messageHideWordByDefaultSubtitle;

  /// No description provided for @messageTemplateQuestionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Define the structure. Answers are filled in per card.'**
  String get messageTemplateQuestionsHelp;

  /// No description provided for @messageNoQuestionTemplatesSnackbar.
  ///
  /// In en, this message translates to:
  /// **'No question templates yet. Create one from the Question Templates tab.'**
  String get messageNoQuestionTemplatesSnackbar;

  /// No description provided for @titleChooseQuestionTemplate.
  ///
  /// In en, this message translates to:
  /// **'Choose a Question Template'**
  String get titleChooseQuestionTemplate;

  /// No description provided for @hintHintShownDuringStudy.
  ///
  /// In en, this message translates to:
  /// **'Shown to the user during study'**
  String get hintHintShownDuringStudy;

  /// No description provided for @labelOptionsPreFilled.
  ///
  /// In en, this message translates to:
  /// **'Options (pre-filled for all cards using this template)'**
  String get labelOptionsPreFilled;

  /// No description provided for @titleDeleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete Template'**
  String get titleDeleteTemplate;

  /// No description provided for @messageDeleteTemplateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Cards created from it keep their questions; this cannot be undone.'**
  String messageDeleteTemplateConfirm(String name);

  /// No description provided for @errorFailedSaveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Failed to save template. Please try again.'**
  String get errorFailedSaveTemplate;

  /// No description provided for @errorFailedDeleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete template. Please try again.'**
  String get errorFailedDeleteTemplate;

  /// No description provided for @actionCreateTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create Template'**
  String get actionCreateTemplate;

  /// No description provided for @titleEditQuestionTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit Question Template'**
  String get titleEditQuestionTemplate;

  /// No description provided for @titleNewQuestionTemplate.
  ///
  /// In en, this message translates to:
  /// **'New Question Template'**
  String get titleNewQuestionTemplate;

  /// No description provided for @titleDeleteQuestionTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete Question Template'**
  String get titleDeleteQuestionTemplate;

  /// No description provided for @messageDeleteQuestionTemplateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String messageDeleteQuestionTemplateConfirm(String name);

  /// No description provided for @titleQuestionSection.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get titleQuestionSection;

  /// No description provided for @labelImportIdOptional.
  ///
  /// In en, this message translates to:
  /// **'Import ID (optional)'**
  String get labelImportIdOptional;

  /// No description provided for @hintImportIdExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. gender'**
  String get hintImportIdExample;

  /// No description provided for @messageImportIdHelperText.
  ///
  /// In en, this message translates to:
  /// **'Reference this template in import files as ##gender'**
  String get messageImportIdHelperText;

  /// No description provided for @validatorImportIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Only letters, numbers, hyphens and underscores allowed'**
  String get validatorImportIdInvalid;

  /// No description provided for @messageImportIdConflict.
  ///
  /// In en, this message translates to:
  /// **'Import ID \"{id}\" is already used by another template.'**
  String messageImportIdConflict(String id);

  /// No description provided for @messageTplWordOrderNote.
  ///
  /// In en, this message translates to:
  /// **'Word bank entries are filled in per card.'**
  String get messageTplWordOrderNote;

  /// No description provided for @titleStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get titleStudy;

  /// No description provided for @titleStudyASet.
  ///
  /// In en, this message translates to:
  /// **'Study a Set'**
  String get titleStudyASet;

  /// No description provided for @messageStudyASetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Work through the cards in one of your sets.'**
  String get messageStudyASetSubtitle;

  /// No description provided for @titleStudyReview.
  ///
  /// In en, this message translates to:
  /// **'Study Review'**
  String get titleStudyReview;

  /// No description provided for @messageStudyReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Focus on cards you have flagged for review.'**
  String get messageStudyReviewSubtitle;

  /// No description provided for @titleStudyMistakes.
  ///
  /// In en, this message translates to:
  /// **'Study Mistakes'**
  String get titleStudyMistakes;

  /// No description provided for @messageStudyMistakesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drill questions you have answered incorrectly recently.'**
  String get messageStudyMistakesSubtitle;

  /// No description provided for @labelComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get labelComingSoon;

  /// No description provided for @messageNoSetsYetStudy.
  ///
  /// In en, this message translates to:
  /// **'No sets yet — create one in My Sets first.'**
  String get messageNoSetsYetStudy;

  /// No description provided for @titleChooseSet.
  ///
  /// In en, this message translates to:
  /// **'Choose a Set'**
  String get titleChooseSet;

  /// No description provided for @tooltipSessionHistory.
  ///
  /// In en, this message translates to:
  /// **'Session history'**
  String get tooltipSessionHistory;

  /// No description provided for @labelShuffleCards.
  ///
  /// In en, this message translates to:
  /// **'Shuffle cards'**
  String get labelShuffleCards;

  /// No description provided for @messageShuffleCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Randomise card order for this session'**
  String get messageShuffleCardsSubtitle;

  /// No description provided for @actionStartNewSession.
  ///
  /// In en, this message translates to:
  /// **'Start New Session'**
  String get actionStartNewSession;

  /// No description provided for @actionStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get actionStartSession;

  /// No description provided for @errorFailedStartSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to start session. Please try again.'**
  String get errorFailedStartSession;

  /// No description provided for @messageAddCardsBeforeStudying.
  ///
  /// In en, this message translates to:
  /// **'Add cards to this set before studying.'**
  String get messageAddCardsBeforeStudying;

  /// No description provided for @labelSessionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Session in progress'**
  String get labelSessionInProgress;

  /// No description provided for @messageCardsReviewed.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} cards reviewed'**
  String messageCardsReviewed(int done, int total);

  /// No description provided for @actionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get actionResume;

  /// No description provided for @titleSetHistory.
  ///
  /// In en, this message translates to:
  /// **'{name} — History'**
  String titleSetHistory(String name);

  /// No description provided for @errorFailedLoadHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history.'**
  String get errorFailedLoadHistory;

  /// No description provided for @messageNoSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet.\nStart studying to build your history.'**
  String get messageNoSessionsYet;

  /// No description provided for @labelCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get labelCompleted;

  /// No description provided for @labelInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get labelInProgress;

  /// No description provided for @labelStudiedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{studied} / {total} cards'**
  String labelStudiedOfTotal(int studied, int total);

  /// No description provided for @actionEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get actionEnd;

  /// No description provided for @messageCardNotFound.
  ///
  /// In en, this message translates to:
  /// **'Card not found.'**
  String get messageCardNotFound;

  /// No description provided for @messageSaveProgressFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving progress failed — check your connection.'**
  String get messageSaveProgressFailed;

  /// No description provided for @actionDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get actionDismiss;

  /// No description provided for @semanticsRevealForeignWord.
  ///
  /// In en, this message translates to:
  /// **'reveal foreign word'**
  String get semanticsRevealForeignWord;

  /// No description provided for @semanticsRevealTranslation.
  ///
  /// In en, this message translates to:
  /// **'reveal translation'**
  String get semanticsRevealTranslation;

  /// No description provided for @actionShowHint.
  ///
  /// In en, this message translates to:
  /// **'Show Hint'**
  String get actionShowHint;

  /// No description provided for @actionShowWord.
  ///
  /// In en, this message translates to:
  /// **'Show Word'**
  String get actionShowWord;

  /// No description provided for @labelTapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal'**
  String get labelTapToReveal;

  /// No description provided for @labelKnewIt.
  ///
  /// In en, this message translates to:
  /// **'Knew it'**
  String get labelKnewIt;

  /// No description provided for @labelNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get labelNotYet;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get actionMore;

  /// No description provided for @tooltipPreviousCard.
  ///
  /// In en, this message translates to:
  /// **'Previous card'**
  String get tooltipPreviousCard;

  /// No description provided for @semanticsCardOf.
  ///
  /// In en, this message translates to:
  /// **'Card {current} of {total}'**
  String semanticsCardOf(int current, int total);

  /// No description provided for @labelCardProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String labelCardProgress(int current, int total);

  /// No description provided for @tooltipFinishSession.
  ///
  /// In en, this message translates to:
  /// **'Finish session'**
  String get tooltipFinishSession;

  /// No description provided for @tooltipNextCard.
  ///
  /// In en, this message translates to:
  /// **'Next card'**
  String get tooltipNextCard;

  /// No description provided for @labelTapWordsToBuild.
  ///
  /// In en, this message translates to:
  /// **'Tap words below to build your answer'**
  String get labelTapWordsToBuild;

  /// No description provided for @tooltipTapToReturn.
  ///
  /// In en, this message translates to:
  /// **'Tap to return'**
  String get tooltipTapToReturn;

  /// No description provided for @labelYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer:'**
  String get labelYourAnswer;

  /// No description provided for @labelWordBank.
  ///
  /// In en, this message translates to:
  /// **'Word bank:'**
  String get labelWordBank;

  /// No description provided for @semanticsOptionCorrect.
  ///
  /// In en, this message translates to:
  /// **', correct'**
  String get semanticsOptionCorrect;

  /// No description provided for @semanticsOptionIncorrect.
  ///
  /// In en, this message translates to:
  /// **', incorrect'**
  String get semanticsOptionIncorrect;

  /// No description provided for @hintTypeYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Type your answer'**
  String get hintTypeYourAnswer;

  /// No description provided for @actionCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get actionCheck;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get actionTryAgain;

  /// No description provided for @messageAnswerReveal.
  ///
  /// In en, this message translates to:
  /// **'Answer: {answer}'**
  String messageAnswerReveal(String answer);

  /// No description provided for @titleSessionComplete.
  ///
  /// In en, this message translates to:
  /// **'Session Complete'**
  String get titleSessionComplete;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @labelCardsStudied.
  ///
  /// In en, this message translates to:
  /// **'Cards studied'**
  String get labelCardsStudied;

  /// No description provided for @labelSkippedStat.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get labelSkippedStat;

  /// No description provided for @labelQuestionsStat.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get labelQuestionsStat;

  /// No description provided for @labelTimeStat.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get labelTimeStat;

  /// No description provided for @actionStudyAgain.
  ///
  /// In en, this message translates to:
  /// **'Study Again'**
  String get actionStudyAgain;

  /// No description provided for @titleImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import & Export'**
  String get titleImportExport;

  /// No description provided for @titleImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get titleImport;

  /// No description provided for @messageImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Import a ZIP archive exported from Agora. New sets are created automatically; existing sets are matched by name.'**
  String get messageImportDescription;

  /// No description provided for @actionChooseZipFile.
  ///
  /// In en, this message translates to:
  /// **'Choose ZIP file…'**
  String get actionChooseZipFile;

  /// No description provided for @titleExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get titleExport;

  /// No description provided for @messageExportDescription.
  ///
  /// In en, this message translates to:
  /// **'Select sets to export as a ZIP archive. The archive can be re-imported into any Agora account.'**
  String get messageExportDescription;

  /// No description provided for @messageNoSetsYetExport.
  ///
  /// In en, this message translates to:
  /// **'No sets yet — create a set to export it.'**
  String get messageNoSetsYetExport;

  /// No description provided for @actionDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get actionDeselectAll;

  /// No description provided for @actionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get actionSelectAll;

  /// No description provided for @labelNoneSelected.
  ///
  /// In en, this message translates to:
  /// **'None selected'**
  String get labelNoneSelected;

  /// No description provided for @labelNOfMSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} selected'**
  String labelNOfMSelected(int count, int total);

  /// No description provided for @actionExportN.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Export} =1{Export 1 set} other{Export {count} sets}}'**
  String actionExportN(int count);

  /// No description provided for @messageExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get messageExporting;

  /// No description provided for @messageExportSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String messageExportSavedTo(String path);

  /// No description provided for @messageExportReady.
  ///
  /// In en, this message translates to:
  /// **'Export ready.'**
  String get messageExportReady;

  /// No description provided for @messageAnalysingArchive.
  ///
  /// In en, this message translates to:
  /// **'Analysing archive…'**
  String get messageAnalysingArchive;

  /// No description provided for @errorFailedReadArchive.
  ///
  /// In en, this message translates to:
  /// **'Failed to read the archive. Check the file format and try again.'**
  String get errorFailedReadArchive;

  /// No description provided for @titleImportPreview.
  ///
  /// In en, this message translates to:
  /// **'Import Preview'**
  String get titleImportPreview;

  /// No description provided for @labelSkipCardUpdates.
  ///
  /// In en, this message translates to:
  /// **'Skip card updates'**
  String get labelSkipCardUpdates;

  /// No description provided for @messageSkipCardUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only create new cards; leave existing cards unchanged.'**
  String get messageSkipCardUpdatesSubtitle;

  /// No description provided for @labelRemoveCardsNotInImport.
  ///
  /// In en, this message translates to:
  /// **'Remove cards not in import'**
  String get labelRemoveCardsNotInImport;

  /// No description provided for @messageRemoveCardsNotInImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cards absent from the file are removed from the set (not deleted from your library).'**
  String get messageRemoveCardsNotInImportSubtitle;

  /// No description provided for @actionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// No description provided for @labelNewSet.
  ///
  /// In en, this message translates to:
  /// **'New set'**
  String get labelNewSet;

  /// No description provided for @labelExistingSet.
  ///
  /// In en, this message translates to:
  /// **'Existing'**
  String get labelExistingSet;

  /// No description provided for @labelNNew.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String labelNNew(int count);

  /// No description provided for @labelNFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'{count} from library'**
  String labelNFromLibrary(int count);

  /// No description provided for @labelNUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count} updated'**
  String labelNUpdated(int count);

  /// No description provided for @labelNUpdatedSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} updated (skipped)'**
  String labelNUpdatedSkipped(int count);

  /// No description provided for @labelNToRemove.
  ///
  /// In en, this message translates to:
  /// **'{count} to remove'**
  String labelNToRemove(int count);

  /// No description provided for @labelNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get labelNoChanges;

  /// No description provided for @labelNNewCardTemplates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new card template} other{{count} new card templates}}'**
  String labelNNewCardTemplates(int count);

  /// No description provided for @labelNNewQuestionTemplates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new question template} other{{count} new question templates}}'**
  String labelNNewQuestionTemplates(int count);

  /// No description provided for @labelQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get labelQuestion;

  /// No description provided for @messageAlsoIn.
  ///
  /// In en, this message translates to:
  /// **'Also in: {sets}'**
  String messageAlsoIn(String sets);

  /// No description provided for @titleImportComplete.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get titleImportComplete;

  /// No description provided for @messageSetsProcessed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set processed} other{{count} sets processed}}'**
  String messageSetsProcessed(int count);

  /// No description provided for @labelNewCount.
  ///
  /// In en, this message translates to:
  /// **'({count} new)'**
  String labelNewCount(int count);

  /// No description provided for @messageNoChangesApplied.
  ///
  /// In en, this message translates to:
  /// **'No changes were applied'**
  String get messageNoChangesApplied;

  /// No description provided for @messageCardsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card added} other{{count} cards added}}'**
  String messageCardsAdded(int count);

  /// No description provided for @messageCardsLinked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card linked from library} other{{count} cards linked from library}}'**
  String messageCardsLinked(int count);

  /// No description provided for @messageCardsUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card updated} other{{count} cards updated}}'**
  String messageCardsUpdated(int count);

  /// No description provided for @messageCardsRemovedFromSets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card removed from sets} other{{count} cards removed from sets}}'**
  String messageCardsRemovedFromSets(int count);

  /// No description provided for @messageCardTemplatesCreated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card template created} other{{count} card templates created}}'**
  String messageCardTemplatesCreated(int count);

  /// No description provided for @messageQuestionTemplatesCreated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question template created} other{{count} question templates created}}'**
  String messageQuestionTemplatesCreated(int count);

  /// No description provided for @errorImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Please try again.'**
  String get errorImportFailed;

  /// No description provided for @titleSendReport.
  ///
  /// In en, this message translates to:
  /// **'Send Report'**
  String get titleSendReport;

  /// No description provided for @labelFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get labelFeedback;

  /// No description provided for @labelIssue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get labelIssue;

  /// No description provided for @labelSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get labelSubject;

  /// No description provided for @labelMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get labelMessage;

  /// No description provided for @labelIncludeAppLogs.
  ///
  /// In en, this message translates to:
  /// **'Include app logs'**
  String get labelIncludeAppLogs;

  /// No description provided for @messageIncludeAppLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Helps diagnose technical issues'**
  String get messageIncludeAppLogsSubtitle;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @messageReportSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you — your report has been sent.'**
  String get messageReportSent;

  /// No description provided for @errorCouldNotSendReport.
  ///
  /// In en, this message translates to:
  /// **'Could not send report. Please try again.'**
  String get errorCouldNotSendReport;
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
