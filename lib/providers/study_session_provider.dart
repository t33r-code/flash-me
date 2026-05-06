import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/services/study_session_service.dart';

// Singleton StudySessionService instance shared across the app.
final studySessionServiceProvider = Provider((ref) => StudySessionService());

// Streams the session history for a specific set (all sessions, newest first).
// Usage: ref.watch(sessionHistoryProvider('setId123'))
final sessionHistoryProvider =
    StreamProvider.family<List<StudySession>, String>((ref, setId) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);
  return ref
      .watch(studySessionServiceProvider)
      .watchSessionHistory(setId, user.uid);
});
