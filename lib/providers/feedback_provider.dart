import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/repositories/feedback_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_feedback_repository.dart';

// Bind the abstract FeedbackRepository to its Firebase implementation.
final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FirebaseFeedbackRepository(),
);
