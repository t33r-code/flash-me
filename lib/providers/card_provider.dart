import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/repositories/card_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_card_repository.dart';

// Bind the abstract CardRepository to its Firebase implementation.
final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => FirebaseCardRepository(),
);

// Streams all cards owned by the currently signed-in user, ordered newest first.
final userCardsProvider = StreamProvider<List<FlashCard>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value([]);
  return ref.watch(cardRepositoryProvider).watchUserCards(uid);
});
