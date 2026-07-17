// Pure helpers for the card library's multi-select mode (#238). Kept free of
// Flutter so the selection maths can be unit-tested directly.

// The ids between [anchorId] and [targetId] inclusive, in [ordered] display
// order. Direction-agnostic — the anchor may sit before or after the target.
// Returns an empty set if either id is missing (e.g. the anchor was filtered
// out of the list since it was set), so callers can fall back to a plain toggle.
Set<String> idsInRange(List<String> ordered, String anchorId, String targetId) {
  final anchor = ordered.indexOf(anchorId);
  final target = ordered.indexOf(targetId);
  if (anchor < 0 || target < 0) return {};
  final start = anchor <= target ? anchor : target;
  final end = anchor <= target ? target : anchor;
  return ordered.sublist(start, end + 1).toSet();
}

// [current] with [id] added if absent, removed if present.
Set<String> toggleId(Set<String> current, String id) {
  final next = {...current};
  if (!next.remove(id)) next.add(id);
  return next;
}

// Drops ids that are no longer in [visible] — keeps the selection honest when
// the search/tag filter narrows the list under it.
Set<String> pruneSelection(Set<String> current, Iterable<String> visible) {
  final live = visible.toSet();
  return current.where(live.contains).toSet();
}
