import 'package:flash_me/models/study_session.dart';

// Provider-agnostic contract for study session persistence.
abstract class StudySessionRepository {
  // Create and persist a new session; returns it with its generated ID.
  Future<StudySession> createSession(StudySession session, String userId);

  // Persist current session state (called after each user action).
  // The caller is responsible for debouncing to limit write frequency.
  Future<void> saveSession(StudySession session, String userId);

  // Mark a session as completed and write final stats.
  Future<void> completeSession(StudySession session, String userId);

  // Find the most recent in-progress session for [setId], or null if none.
  Future<StudySession?> getActiveSession(String setId, String userId);

  // Stream all sessions for [setId], newest first (for history view).
  Stream<List<StudySession>> watchSessionHistory(String setId, String userId);
}
