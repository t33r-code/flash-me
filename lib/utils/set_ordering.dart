import 'package:flash_me/models/set_card.dart';

// Orders a set's membership links by author-controlled `position`.
//
// Input MUST already be in addedAt order (that is how the Firestore query
// returns them). We sort client-side rather than server-side because a
// Firestore `orderBy('position')` would silently drop legacy links that have
// no `position` field yet — hiding cards from their set. Sorting in memory
// keeps every link visible.
//
// Sort key per link = position ?? its index in addedAt order. So:
//  - a set never touched by ordering (all positions null) keeps addedAt order;
//  - new links (stamped with position = cardCount on add) sort after the
//    legacy ones, matching how they already appear by addedAt;
//  - once a set is reordered, every link carries a position and those win.
// Ties fall back to addedAt order for determinism.
List<SetCard> sortSetCardsByPosition(List<SetCard> addedAtOrdered) {
  final indexed = addedAtOrdered.asMap().entries.toList();
  indexed.sort((a, b) {
    final ka = a.value.position ?? a.key;
    final kb = b.value.position ?? b.key;
    final cmp = ka.compareTo(kb);
    return cmp != 0 ? cmp : a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}
