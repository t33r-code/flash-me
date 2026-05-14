import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/repositories/card_mark_repository.dart';
import 'package:flash_me/repositories/firebase/firebase_card_mark_repository.dart';

// Provides the CardMarkRepository singleton — stateless, so a plain Provider is fine.
final cardMarkRepositoryProvider = Provider<CardMarkRepository>(
  (_) => FirebaseCardMarkRepository(),
);
