import 'package:flash_me/models/tag.dart';

// Provider-agnostic contract for the global tag collection.
abstract class TagRepository {
  // Normalize [rawTag] and upsert it: create with usageCount=1 if new,
  // or increment usageCount if already present. No-op for empty strings.
  Future<void> upsertTag(String rawTag, String userId);

  // Decrement usageCount on [normalizedTag] by 1.
  // The document is never deleted, even if the count reaches zero.
  Future<void> decrementTag(String normalizedTag);

  // Stream tags whose normalizedName starts with [prefix].
  // Returns up to 10 results ordered by normalizedName. Empty prefix
  // returns an empty stream (not all tags — protects against huge reads).
  Stream<List<Tag>> searchTags(String prefix);
}
