import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_me/utils/constants.dart';

// ---------------------------------------------------------------------------
// SessionStats — aggregate numbers calculated at session end (or on demand).
// ---------------------------------------------------------------------------
class SessionStats {
  final double avgTimePerCard; // milliseconds
  final int totalTimeSpent; // milliseconds
  final int correctAnswers;
  final int incorrectAnswers;
  final int skipped;

  const SessionStats({
    this.avgTimePerCard = 0,
    this.totalTimeSpent = 0,
    this.correctAnswers = 0,
    this.incorrectAnswers = 0,
    this.skipped = 0,
  });

  factory SessionStats.fromJson(Map<String, dynamic> json) => SessionStats(
        avgTimePerCard: (json['avgTimePerCard'] as num?)?.toDouble() ?? 0,
        totalTimeSpent: json['totalTimeSpent'] as int? ?? 0,
        correctAnswers: json['correctAnswers'] as int? ?? 0,
        incorrectAnswers: json['incorrectAnswers'] as int? ?? 0,
        skipped: json['skipped'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'avgTimePerCard': avgTimePerCard,
        'totalTimeSpent': totalTimeSpent,
        'correctAnswers': correctAnswers,
        'incorrectAnswers': incorrectAnswers,
        'skipped': skipped,
      };

  SessionStats copyWith({
    double? avgTimePerCard,
    int? totalTimeSpent,
    int? correctAnswers,
    int? incorrectAnswers,
    int? skipped,
  }) =>
      SessionStats(
        avgTimePerCard: avgTimePerCard ?? this.avgTimePerCard,
        totalTimeSpent: totalTimeSpent ?? this.totalTimeSpent,
        correctAnswers: correctAnswers ?? this.correctAnswers,
        incorrectAnswers: incorrectAnswers ?? this.incorrectAnswers,
        skipped: skipped ?? this.skipped,
      );
}

// ---------------------------------------------------------------------------
// CardSessionData — per-card progress within one study session.
// Stored as a nested map inside the StudySession document.
//
// Intentionally minimal: per-question answer state (which answers were
// typed, which options were selected) is tracked in the questionResults
// subcollection, not duplicated here.
// ---------------------------------------------------------------------------
class CardSessionData {
  // One of AppConstants.cardStatus* — tracks where the user is with this card.
  final String status;
  final bool markedKnown;   // true = user tapped Skip for this card
  final bool markedUnknown; // true = user tapped Review for this card
  final int attempts;       // how many times the user has tried to answer this card
  // Self-evaluation of the primary word recall: AppConstants.primaryResult*
  // ('known' / 'unknown'), or null if the user advanced without self-evaluating.
  // Only meaningful for flashcards — workbook cards leave this null.
  final String? primaryResult;

  const CardSessionData({
    this.status = AppConstants.cardStatusNotStarted,
    this.markedKnown = false,
    this.markedUnknown = false,
    this.attempts = 0,
    this.primaryResult,
  });

  factory CardSessionData.fromJson(Map<String, dynamic> json) =>
      CardSessionData(
        status: json['status'] as String? ?? AppConstants.cardStatusNotStarted,
        markedKnown: json['markedKnown'] as bool? ?? false,
        markedUnknown: json['markedUnknown'] as bool? ?? false,
        attempts: json['attempts'] as int? ?? 0,
        primaryResult: json['primaryResult'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'markedKnown': markedKnown,
        'markedUnknown': markedUnknown,
        'attempts': attempts,
        'primaryResult': primaryResult,
      };

  CardSessionData copyWith({
    String? status,
    bool? markedKnown,
    bool? markedUnknown,
    int? attempts,
    String? primaryResult,
  }) =>
      CardSessionData(
        status: status ?? this.status,
        markedKnown: markedKnown ?? this.markedKnown,
        markedUnknown: markedUnknown ?? this.markedUnknown,
        attempts: attempts ?? this.attempts,
        primaryResult: primaryResult ?? this.primaryResult,
      );
}

// ---------------------------------------------------------------------------
// StudySession — one study run of a card set.
// Stored in users/{userId}/studySessions/{sessionId}.
// ---------------------------------------------------------------------------
class StudySession {
  final String id; // Firestore document ID
  final String setId; // which set is being studied
  final DateTime startTime;
  final DateTime lastAccessTime;
  // One of AppConstants.sessionStatus* (in_progress, completed, paused).
  final String status;
  // Map of cardId → per-card progress for this session.
  final Map<String, CardSessionData> cardProgress;
  // Ordered list of card IDs for this session (shuffled or original order).
  final List<String> cardSequence;
  final int currentCardIndex; // index into cardSequence
  final int totalCardsStudied;
  // Self-evaluation tallies for the flashcard recall portion (primaryResult).
  // cardsKnown = "Knew it", cardsUnknown = "Not yet". Workbook cards excluded.
  final int cardsKnown;
  final int cardsUnknown;
  // First-attempt question score across the session (flash + workbook questions).
  // Each distinct question counts once; retries via "Try Again" don't re-count.
  final int questionsCorrect;
  final int questionsTotal;
  final SessionStats sessionStats;
  // Whether the card sequence was shuffled when this session was created.
  // Used by the summary screen to re-apply the same setting on Study Again.
  final bool shuffled;
  // Maps each cardId in cardSequence to its type ('flashcard' | 'workbook').
  // Absent on old sessions — those are all flashcards (backward compatible).
  final Map<String, String> cardTypeMap;

  const StudySession({
    required this.id,
    required this.setId,
    required this.startTime,
    required this.lastAccessTime,
    required this.status,
    required this.cardProgress,
    required this.cardSequence,
    required this.currentCardIndex,
    required this.totalCardsStudied,
    required this.cardsKnown,
    required this.cardsUnknown,
    this.questionsCorrect = 0,
    this.questionsTotal = 0,
    required this.sessionStats,
    this.shuffled = false,
    this.cardTypeMap = const {},
  });

  factory StudySession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Deserialise the nested cardProgress map (cardId → CardSessionData).
    final rawProgress = data['cardProgress'] as Map<String, dynamic>? ?? {};
    final cardProgress = rawProgress.map(
      (key, value) =>
          MapEntry(key, CardSessionData.fromJson(value as Map<String, dynamic>)),
    );

    return StudySession(
      id: doc.id,
      setId: data['setId'] as String? ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      lastAccessTime: (data['lastAccessTime'] as Timestamp).toDate(),
      status: data['status'] as String? ?? AppConstants.sessionStatusInProgress,
      cardProgress: cardProgress,
      cardSequence: List<String>.from(data['cardSequence'] as List? ?? []),
      currentCardIndex: data['currentCardIndex'] as int? ?? 0,
      totalCardsStudied: data['totalCardsStudied'] as int? ?? 0,
      cardsKnown: data['cardsKnown'] as int? ?? 0,
      cardsUnknown: data['cardsUnknown'] as int? ?? 0,
      questionsCorrect: data['questionsCorrect'] as int? ?? 0,
      questionsTotal: data['questionsTotal'] as int? ?? 0,
      sessionStats: data['sessionStats'] != null
          ? SessionStats.fromJson(
              data['sessionStats'] as Map<String, dynamic>)
          : const SessionStats(),
      shuffled: data['shuffled'] as bool? ?? false,
      cardTypeMap: Map<String, String>.from(
          data['cardTypeMap'] as Map? ?? {}),
    );
  }

  // No user-entered fields — all values are managed by the study session engine.
  List<String> validate() => [];

  Map<String, dynamic> toFirestore() => {
        'setId': setId,
        'startTime': Timestamp.fromDate(startTime),
        'lastAccessTime': Timestamp.fromDate(lastAccessTime),
        'status': status,
        // Serialize each CardSessionData back to a map.
        'cardProgress':
            cardProgress.map((key, value) => MapEntry(key, value.toJson())),
        'cardSequence': cardSequence,
        'currentCardIndex': currentCardIndex,
        'totalCardsStudied': totalCardsStudied,
        'cardsKnown': cardsKnown,
        'cardsUnknown': cardsUnknown,
        'questionsCorrect': questionsCorrect,
        'questionsTotal': questionsTotal,
        'sessionStats': sessionStats.toJson(),
        'shuffled': shuffled,
        'cardTypeMap': cardTypeMap,
      };

  StudySession copyWith({
    String? id,
    String? setId,
    DateTime? startTime,
    DateTime? lastAccessTime,
    String? status,
    Map<String, CardSessionData>? cardProgress,
    List<String>? cardSequence,
    int? currentCardIndex,
    int? totalCardsStudied,
    int? cardsKnown,
    int? cardsUnknown,
    int? questionsCorrect,
    int? questionsTotal,
    SessionStats? sessionStats,
    bool? shuffled,
    Map<String, String>? cardTypeMap,
  }) =>
      StudySession(
        id: id ?? this.id,
        setId: setId ?? this.setId,
        startTime: startTime ?? this.startTime,
        lastAccessTime: lastAccessTime ?? this.lastAccessTime,
        status: status ?? this.status,
        cardProgress: cardProgress ?? this.cardProgress,
        cardSequence: cardSequence ?? this.cardSequence,
        currentCardIndex: currentCardIndex ?? this.currentCardIndex,
        totalCardsStudied: totalCardsStudied ?? this.totalCardsStudied,
        cardsKnown: cardsKnown ?? this.cardsKnown,
        cardsUnknown: cardsUnknown ?? this.cardsUnknown,
        questionsCorrect: questionsCorrect ?? this.questionsCorrect,
        questionsTotal: questionsTotal ?? this.questionsTotal,
        sessionStats: sessionStats ?? this.sessionStats,
        shuffled: shuffled ?? this.shuffled,
        cardTypeMap: cardTypeMap ?? this.cardTypeMap,
      );
}
