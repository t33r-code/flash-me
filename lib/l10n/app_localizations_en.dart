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
}
