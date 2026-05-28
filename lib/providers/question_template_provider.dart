import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/question_template.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/repositories/firebase/firebase_question_template_repository.dart';
import 'package:flash_me/repositories/question_template_repository.dart';

// Repository singleton — swap implementation here to change backend.
final questionTemplateRepositoryProvider =
    Provider<QuestionTemplateRepository>((ref) {
  return FirebaseQuestionTemplateRepository();
});

// Live stream of the current user's question templates, ordered newest-first.
final userQuestionTemplatesProvider =
    StreamProvider<List<QuestionTemplate>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null || uid.isEmpty) return const Stream.empty();
  return ref
      .read(questionTemplateRepositoryProvider)
      .watchUserTemplates(uid);
});
