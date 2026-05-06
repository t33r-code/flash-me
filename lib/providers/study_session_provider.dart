import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/repositories/study_session_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_study_session_repository.dart';

// Bind the abstract StudySessionRepository to its Firebase implementation.
final studySessionRepositoryProvider = Provider<StudySessionRepository>(
  (ref) => FirebaseStudySessionRepository(),
);

// Streams the session history for a specific set, newest first.
// Usage: ref.watch(sessionHistoryProvider('setId123'))
final sessionHistoryProvider =
    StreamProvider.family<List<StudySession>, String>((ref, setId) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value([]);
  return ref
      .watch(studySessionRepositoryProvider)
      .watchSessionHistory(setId, uid);
});
