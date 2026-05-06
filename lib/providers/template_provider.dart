import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/repositories/template_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_template_repository.dart';

// Bind the abstract TemplateRepository to its Firebase implementation.
final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => FirebaseTemplateRepository(),
);

// Streams all templates owned by the current user, ordered newest first.
final userTemplatesProvider = StreamProvider<List<CardTemplate>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value([]);
  return ref.watch(templateRepositoryProvider).watchUserTemplates(uid);
});
