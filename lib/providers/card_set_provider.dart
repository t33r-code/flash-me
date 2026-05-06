import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/services/card_set_service.dart';

// Singleton CardSetService instance shared across the app.
final cardSetServiceProvider = Provider((ref) => CardSetService());

// Streams all sets owned by the currently signed-in user, ordered by most
// recently updated. This is the data source for the "My Sets" home screen.
final userSetsProvider = StreamProvider<List<CardSet>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(cardSetServiceProvider).watchUserSets(user.uid);
});

// Streams the card IDs belonging to a specific set (IDs only — no card data).
// Useful for study session initialization where you just need the sequence.
// Usage: ref.watch(cardIdsInSetProvider('setId123'))
final cardIdsInSetProvider =
    StreamProvider.family<List<String>, String>((ref, setId) {
  return ref.watch(cardSetServiceProvider).watchCardIdsInSet(setId);
});

// Streams the full FlashCard objects for all cards in a specific set.
// Joins the setCards collection with the cards collection under the hood.
// Usage: ref.watch(cardsInSetProvider('setId123'))
final cardsInSetProvider =
    StreamProvider.family<List<FlashCard>, String>((ref, setId) {
  return ref.watch(cardSetServiceProvider).watchCardsInSet(setId);
});
