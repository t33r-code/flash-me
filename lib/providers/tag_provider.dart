import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/tag.dart';
import 'package:flash_me/repositories/firebase/firebase_tag_repository.dart';
import 'package:flash_me/repositories/tag_repository.dart';

// Bind the abstract TagRepository to its Firebase implementation.
final tagRepositoryProvider = Provider<TagRepository>(
  (_) => FirebaseTagRepository(),
);

// Stream tag suggestions for a given prefix string.
// Returns an empty list when the prefix is blank (avoids a full collection scan).
final tagSearchProvider =
    StreamProvider.family<List<Tag>, String>((ref, prefix) {
  return ref.watch(tagRepositoryProvider).searchTags(prefix);
});
