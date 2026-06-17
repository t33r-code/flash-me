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
