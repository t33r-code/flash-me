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

// Mutable multi-select state shared by the card library and the set-detail
// list (#238). Deliberately a plain object rather than a ChangeNotifier: the
// owning State mutates it inside setState, which keeps rebuild control in the
// widget and leaves this class trivially testable.
//
// [mode] is explicit — emptying the selection does NOT leave selection mode,
// so entering it with nothing picked doesn't immediately bounce the user out.
// Only [exit] clears it.
class SelectionModel {
  bool mode = false;
  Set<String> selected = {};
  // The last plainly-toggled id — the origin for a Shift+click range.
  String? anchor;

  bool get isEmpty => selected.isEmpty;
  bool get isNotEmpty => selected.isNotEmpty;
  int get length => selected.length;
  bool contains(String id) => selected.contains(id);

  // Enter selection mode with [id] as the only pick (long-press / modifier
  // click on a row while browsing).
  void enterWith(String id) {
    mode = true;
    selected = {id};
    anchor = id;
  }

  void exit() {
    mode = false;
    selected = {};
    anchor = null;
  }

  void toggle(String id) {
    selected = toggleId(selected, id);
    anchor = id;
  }

  // Shift+click: union the anchor→[id] span into the selection rather than
  // replacing it, so extending never silently discards earlier picks. Falls
  // back to a plain toggle when there's no usable anchor (e.g. it was filtered
  // out from under us).
  void extendTo(String id, List<String> ordered) {
    final from = anchor;
    if (from == null) {
      toggle(id);
      return;
    }
    final span = idsInRange(ordered, from, id);
    if (span.isEmpty) {
      toggle(id);
      return;
    }
    selected = {...selected, ...span};
  }

  // Select all of [ordered], or clear if they're already all selected.
  void toggleSelectAll(List<String> ordered) {
    final all = ordered.toSet();
    final allSelected = all.isNotEmpty && selected.containsAll(all);
    selected = allSelected ? {} : all;
    anchor = null;
  }

  void prune(Iterable<String> visible) {
    selected = pruneSelection(selected, visible);
    if (anchor != null && !selected.contains(anchor)) anchor = null;
  }
}
