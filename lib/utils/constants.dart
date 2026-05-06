
class AppConstants {
  // App name and version
  static const String appName = 'Flash Me';
  static const String appVersion = '1.0.0';

  // Firestore collection names
  static const String usersCollection = 'users';
  static const String cardsCollection = 'cards';
  static const String setsCollection = 'sets';
  static const String setCardsCollection = 'setCards'; // many-to-many join: set ↔ card
  static const String templatesCollection = 'templates';
  static const String studySessionsSubcollection = 'studySessions';

  // Field types
  static const String fieldTypeReveal = 'reveal';
  static const String fieldTypeTextInput = 'text_input';
  static const String fieldTypeMultipleChoice = 'multiple_choice';

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

class AppStrings {
  // Common
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String save = 'Save';
  static const String close = 'Close';

  // Auth
  static const String welcome = 'Welcome to Flash Me';
  static const String signUp = 'Sign Up';
  static const String signIn = 'Sign In';
  static const String signOut = 'Sign Out';
  static const String signUpWithGoogle = 'Sign Up with Google';
  static const String signInWithGoogle = 'Sign In with Google';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';

  // Sets
  static const String mySets = 'My Sets';
  static const String newSet = 'New Set';
  static const String createSet = 'Create Set';
  static const String setName = 'Set Name';
  static const String setDescription = 'Description';
  static const String noSets = 'No sets yet. Create one to get started!';

  // Cards
  static const String cards = 'Cards';
  static const String newCard = 'New Card';
  static const String createCard = 'Create Card';
  static const String deleteCard = 'Delete Card';
  static const String primaryWord = 'Foreign Word';
  static const String translation = 'Translation';
  static const String noCards = 'No cards in this set';

  // Study
  static const String study = 'Study';
  static const String startStudy = 'Start Study';
  static const String resumeSession = 'Resume Session';
  static const String newSession = 'New Session';
  static const String nextCard = 'Next';
  static const String previousCard = 'Previous';
  static const String know = 'Know';
  static const String dontKnow = "Don't Know";
  static const String checkAnswer = 'Check Answer';
  static const String showAnswer = 'Show Answer';
  static const String correct = 'Correct!';
  static const String incorrect = 'Incorrect';
  static const String endSession = 'End Session';

  // Import/Export
  static const String importSets = 'Import Sets';
  static const String exportSets = 'Export Sets';
  static const String chooseFile = 'Choose File';
  static const String selectFormat = 'Select Format';
  static const String json = 'JSON';
  static const String csv = 'CSV';
}
