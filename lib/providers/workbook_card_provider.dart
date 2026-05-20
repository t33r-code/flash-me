import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/repositories/firebase/firebase_workbook_card_repository.dart';
import 'package:flash_me/repositories/workbook_card_repository.dart';

// Bind the abstract WorkbookCardRepository to its Firebase implementation.
final workbookCardRepositoryProvider = Provider<WorkbookCardRepository>(
  (ref) => FirebaseWorkbookCardRepository(),
);

// Streams all workbook cards owned by the currently signed-in user, newest first.
final userWorkbookCardsProvider = StreamProvider<List<WorkbookCard>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value;
  if (uid == null) return Stream.value([]);
  return ref.watch(workbookCardRepositoryProvider).watchUserCards(uid);
});
