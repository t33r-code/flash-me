import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/repositories/question_result_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_question_result_repository.dart';

// Provides the QuestionResultRepository singleton.
final questionResultRepositoryProvider = Provider<QuestionResultRepository>(
  (_) => FirebaseQuestionResultRepository(),
);
