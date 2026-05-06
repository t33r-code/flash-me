import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/services/template_service.dart';

// Singleton TemplateService instance shared across the app.
final templateServiceProvider = Provider((ref) => TemplateService());

// Streams all templates owned by the currently signed-in user, ordered newest first.
final userTemplatesProvider = StreamProvider<List<CardTemplate>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(templateServiceProvider).watchUserTemplates(user.uid);
});
