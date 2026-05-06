import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/exceptions.dart';

class StudySessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Convenience: returns the subcollection reference for a user's sessions.
  CollectionReference<Map<String, dynamic>> _sessionsRef(String userId) =>
      _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.studySessionsSubcollection);

  // --- Write operations -------------------------------------------------------

  // Persist a brand-new study session document and return it with its ID.
  Future<StudySession> createSession(
    StudySession session,
    String userId,
  ) async {
    try {
      final docRef = _sessionsRef(userId).doc();
      final now = DateTime.now();
      final newSession = session.copyWith(
        id: docRef.id,
        startTime: now,
        lastAccessTime: now,
      );
      await docRef.set(newSession.toFirestore());
      _logger.i('Created study session ${docRef.id} for user $userId');
      return newSession;
    } catch (e) {
      _logger.e('Failed to create study session: $e');
      throw AppException('Failed to start session', code: 'create-session-failed');
    }
  }

  // Save current session state (card progress, index, stats, etc.).
  // Called after each significant user action; the caller is responsible for
  // debouncing to avoid excessive Firestore writes.
  Future<void> saveSession(StudySession session, String userId) async {
    try {
      final updated = session.copyWith(lastAccessTime: DateTime.now());
      await _sessionsRef(userId)
          .doc(session.id)
          .update(updated.toFirestore());
    } catch (e) {
      _logger.e('Failed to save session ${session.id}: $e');
      throw AppException('Failed to save session progress',
          code: 'save-session-failed');
    }
  }

  // Mark a session as completed and write the final stats.
  Future<void> completeSession(StudySession session, String userId) async {
    try {
      final completed = session.copyWith(
        status: AppConstants.sessionStatusCompleted,
        lastAccessTime: DateTime.now(),
      );
      await _sessionsRef(userId)
          .doc(session.id)
          .update(completed.toFirestore());
      _logger.i('Completed session ${session.id}');
    } catch (e) {
      _logger.e('Failed to complete session ${session.id}: $e');
      throw AppException('Failed to complete session',
          code: 'complete-session-failed');
    }
  }

  // --- Read operations --------------------------------------------------------

  // Find the most recent in-progress session for a given set, or null if none.
  // Used to offer "Resume" when the user returns to a set they were studying.
  Future<StudySession?> getActiveSession(String setId, String userId) async {
    try {
      final snapshot = await _sessionsRef(userId)
          .where('setId', isEqualTo: setId)
          .where('status', isEqualTo: AppConstants.sessionStatusInProgress)
          .orderBy('lastAccessTime', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return StudySession.fromFirestore(snapshot.docs.first);
    } catch (e) {
      _logger.e('Failed to get active session for set $setId: $e');
      throw AppException('Failed to load session', code: 'get-session-failed');
    }
  }

  // Stream the full session history for a set, newest first.
  Stream<List<StudySession>> watchSessionHistory(String setId, String userId) {
    return _sessionsRef(userId)
        .where('setId', isEqualTo: setId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(StudySession.fromFirestore).toList());
  }
}
