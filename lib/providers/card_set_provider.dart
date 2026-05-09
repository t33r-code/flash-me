import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/repositories/card_set_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_card_set_repository.dart';

// Bind the abstract CardSetRepository to its Firebase implementation.
final cardSetRepositoryProvider = Provider<CardSetRepository>(
  (ref) => FirebaseCardSetRepository(),
);

// Streams all sets owned by the current user, ordered by most recently updated.
// This is the data source for the "My Sets" home screen.
final userSetsProvider = StreamProvider<List<CardSet>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value([]);
  return ref.watch(cardSetRepositoryProvider).watchUserSets(uid);
});

// Derives a single live CardSet from the user's set list by ID.
// Returns null if the set has been deleted or hasn't loaded yet.
final setByIdProvider = Provider.family<CardSet?, String>((ref, setId) {
  final sets = ref.watch(userSetsProvider).asData?.value ?? [];
  try {
    return sets.firstWhere((s) => s.id == setId);
  } catch (_) {
    return null;
  }
});

// Streams card IDs in a specific set (lightweight — no card document data).
// Usage: ref.watch(cardIdsInSetProvider('setId123'))
final cardIdsInSetProvider =
    StreamProvider.family<List<String>, String>((ref, setId) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value([]);
  return ref.watch(cardSetRepositoryProvider).watchCardIdsInSet(setId, uid);
});

// Streams the full FlashCard objects for all cards in a specific set.
// Usage: ref.watch(cardsInSetProvider('setId123'))
final cardsInSetProvider =
    StreamProvider.family<List<FlashCard>, String>((ref, setId) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value([]);
  return ref.watch(cardSetRepositoryProvider).watchCardsInSet(setId, uid);
});
