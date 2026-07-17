import 'package:flash_me/utils/helpers.dart';

// Pure helpers behind the tri-state bulk tag dialog (#238). Kept free of
// Flutter so the "which tags does this selection have?" maths is unit-testable.

// How widely a tag is applied across a selection.
enum TagPresence {
  all, // every selected card has it  → ticked
  some, // only some do               → dash (indeterminate)
  none, // none do                    → unticked
}

// Presence of every tag used anywhere across [cardTags] (one entry per selected
// card). Tags are normalised first, so callers get canonical forms back — the
// same forms used as tags/{normalizedName} document ids.
Map<String, TagPresence> tagPresence(Iterable<List<String>> cardTags) {
  final cards = cardTags
      .map(
        (tags) => tags
            .map(AppHelpers.normalizeTag)
            .where((t) => t.isNotEmpty)
            .toSet(),
      )
      .toList();
  if (cards.isEmpty) return {};

  final every = <String>{for (final tags in cards) ...tags};
  final result = <String, TagPresence>{};
  for (final tag in every) {
    final count = cards.where((tags) => tags.contains(tag)).length;
    result[tag] = count == cards.length ? TagPresence.all : TagPresence.some;
  }
  return result;
}

// [cardTags] with [add] applied and [remove] stripped. Normalises throughout
// and never duplicates. Order is stable: existing tags keep their position and
// additions land at the end.
List<String> applyTagDelta(
  List<String> cardTags,
  Set<String> add,
  Set<String> remove,
) {
  final normalizedRemove = remove.map(AppHelpers.normalizeTag).toSet();
  final result = <String>[];
  for (final tag in cardTags) {
    final norm = AppHelpers.normalizeTag(tag);
    if (norm.isEmpty || normalizedRemove.contains(norm)) continue;
    if (!result.contains(norm)) result.add(norm);
  }
  for (final tag in add) {
    final norm = AppHelpers.normalizeTag(tag);
    if (norm.isEmpty || normalizedRemove.contains(norm)) continue;
    if (!result.contains(norm)) result.add(norm);
  }
  return result;
}
