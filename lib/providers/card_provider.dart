import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/services/card_service.dart';

// Singleton CardService instance shared across the app.
final cardServiceProvider = Provider((ref) => CardService());

// Streams all cards owned by the currently signed-in user, ordered newest first.
// Re-evaluates automatically when the auth state changes.
final userCardsProvider = StreamProvider<List<FlashCard>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(cardServiceProvider).watchUserCards(user.uid);
});
