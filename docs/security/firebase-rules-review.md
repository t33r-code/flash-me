# Firebase Rules Security Review — Agora (#285)

Audit of `firestore.rules` and `storage.rules` for correctness and least-privilege.
Companion to the app-level OWASP review (`docs/security/owasp-review.md`, #286) —
that review's F1 (cross-user email exposure) was a rules-level issue and was fixed
separately in #297; this review covers the rest of the rules surface.

Every finding below was grounded against the actual Flutter client code (query
patterns, write call sites), not just the rules text, to confirm real exploitability
and that fixes don't break a legitimate flow.

## Summary of findings

| ID | Severity | Area | Finding | Fixed |
|----|----------|------|---------|-------|
| R1 | **Medium** | `setCards` | `create` doesn't verify the referenced `setId`/`cardId` actually belong to the creator | ✅ |
| R2 | **Medium** | `sets` | The `acquisitionCount`-only update exception has no `isPublic` gate or delta check | ✅ |
| R3 | **Low** | `cards` / `workbookCards` | Update/delete default an absent `createdBy` field to the requester's own uid — fails **open** | ✅ |
| R4 | **Low** | `tags` | `update` doesn't constrain the `usageCount` delta | ✅ |
| R5 | **Low** | `templates` / `questionTemplates` | `update` doesn't enforce `createdBy` immutability (unlike `tags`, which does) | ✅ |
| R6 | **Medium** | Storage | No file size or content-type validation on uploads | ✅ |
| R7 | **Info** | `cards` / `workbookCards` / Storage | Both are globally readable by any authenticated user — deliberate, documented design tradeoff | No action |

---

## R1 — `setCards` create doesn't verify ownership of `setId`/`cardId` **[Medium]**

**Evidence.** `firestore.rules` (before fix):
```
allow create: if isAuth() && request.resource.data.userId == request.auth.uid;
```
This only checks that the **link document's own** `userId` field matches the creator —
it never confirms that `setId` refers to a set the creator owns, nor that `cardId`
refers to a card they created. The `SetCard` model's own doc comment claims
"security rules can verify ownership without looking up the parent set or card
document," which the rule as written did not actually do.

**Exploitability.** Confirmed against the client: every real query filters
`setCards` by **both** `setId` and `userId` together
(`firebase_card_set_repository.dart`), so a forged link can't make content appear in
*another* user's set view. But a user who knows (or enumerates) another user's
`cardId` — cards are globally readable by design, see R7 — could craft a `setCards`
link with `setId` = their own set and `cardId` = someone else's card, `userId` =
themselves. This attaches another user's card into their own set/study flow **without
going through Clone** (which copies the card and records provenance via
`cardAcquisitions`). Confirmed the only legitimate flow (`import_service.dart`,
clone) always creates/owns the card **before** linking it, so tightening this
doesn't break anything.

**Fix.** Added `get()` ownership checks at create time:
```
allow create: if isAuth() &&
    request.resource.data.userId == request.auth.uid &&
    get(/databases/$(database)/documents/sets/$(request.resource.data.setId)).data.userId == request.auth.uid &&
    (request.resource.data.cardType == 'workbook'
      ? get(/databases/$(database)/documents/workbookCards/$(request.resource.data.cardId)).data.createdBy == request.auth.uid
      : get(/databases/$(database)/documents/cards/$(request.resource.data.cardId)).data.createdBy == request.auth.uid);
```

## R2 — `sets.update`'s `acquisitionCount` exception has no gate **[Medium]**

**Evidence.** `firestore.rules` (before fix):
```
allow update: if isAuth() && (
    resource.data.userId == request.auth.uid ||
    request.resource.data.diff(resource.data).affectedKeys().hasOnly(['acquisitionCount'])
);
```
The second branch lets **any** authenticated user update `acquisitionCount` on **any**
set — public or private — to **any** value, with no ownership, no `isPublic`
requirement, and no check that the change is actually an increment.

**Exploitability.** Confirmed the only legitimate writer is
`firebase_set_acquisition_repository.dart`, which does `FieldValue.increment(1)` on a
set it has just resolved as the clone source (a public set). A raw SDK/REST call
bypassing the app could set any set's `acquisitionCount` to an arbitrary number —
inflating/deflating a Market trust signal, or writing to a private set's field the
owner never opted to expose.

**Fix.**
```
allow update: if isAuth() && (
    resource.data.userId == request.auth.uid ||
    (resource.data.isPublic == true &&
     request.resource.data.diff(resource.data).affectedKeys().hasOnly(['acquisitionCount']) &&
     request.resource.data.acquisitionCount == resource.data.acquisitionCount + 1)
);
```

## R3 — `cards`/`workbookCards` fail **open** on a missing `createdBy` **[Low]**

**Evidence.** Before fix:
```
allow update, delete: if isAuth() &&
    resource.data.get('createdBy', request.auth.uid) == request.auth.uid;
```
`Map.get(key, default)` returns `default` when the key is **absent**. The default
here is `request.auth.uid` — so a document missing `createdBy` is editable/deletable
by **any** signed-in user, since the comparison trivially matches whoever is asking.
The existing `scripts/fix_card_createdby.js` migration ("for every card ... whose
`createdBy` field doesn't match ... updates `createdBy`") indicates such documents
have existed in this project's history.

**Fix.** Default to `null` instead, which can never equal a real uid, so an
absent-field document now fails **closed** (uneditable until backfilled) rather than
open (editable by anyone):
```
allow update, delete: if isAuth() &&
    resource.data.get('createdBy', null) == request.auth.uid;
```
Applied identically to both `cards` and `workbookCards`.

## R4 — `tags.update` doesn't constrain the `usageCount` delta **[Low]**

**Evidence.** The rule preserves `displayName`/`createdBy`/`normalizedName`
immutability but places no constraint on how `usageCount` changes between
`upsertTag`'s increment and `decrementTag`'s decrement. A client could set it to an
arbitrary value in a single write. Low impact — only affects tag-popularity ordering
in autocomplete, not access control.

**Fix.**
```
allow update: if isAuth()
    && request.resource.data.displayName == resource.data.displayName
    && request.resource.data.createdBy  == resource.data.createdBy
    && request.resource.data.normalizedName == resource.data.normalizedName
    && (request.resource.data.usageCount == resource.data.usageCount + 1 ||
        request.resource.data.usageCount == resource.data.usageCount - 1);
```

## R5 — `templates`/`questionTemplates.update` don't enforce `createdBy` immutability **[Low]**

**Evidence.** Unlike `tags`, these collections' update rules only check that the
**current** document belongs to the requester — nothing stops the requester from
changing `createdBy` to an arbitrary uid on update. Since you must already own the
document to update it at all, this can't be used to steal *another* user's template;
at most it lets an owner orphan their own template into an account they don't
control. Low severity, but worth the same immutability guarantee `tags` already has,
for consistency.

**Fix.** Added `request.resource.data.createdBy == resource.data.createdBy` to both
collections' `update` conditions.

## R6 — No Storage size or content-type validation **[Medium]**

**Evidence.** `storage.rules`'s write rule only checked auth + path ownership — no
`request.resource.size` or `request.resource.contentType` constraint. Confirmed the
client picker (`card_form_screen.dart`, `FileType.image`/`FileType.audio`) applies no
size limit either, so nothing anywhere capped an upload.

**Impact.** A user (or a script running under their own account) could upload
arbitrarily large files under their own `users/{uid}/...` path — a storage-cost/abuse
vector. Not a cross-user access issue (writes are already uid-scoped), but worth
capping regardless.

**Fix.** Added a **10 MB** per-file cap and restricted content type to
`image/*`/`audio/*` (matching the whitelist `import_media.dart` already uses
client-side for the same media):
```
allow write: if request.auth != null && request.auth.uid == userId &&
    request.resource.size < 10 * 1024 * 1024 &&
    request.resource.contentType.matches('image/.*|audio/.*');
```

## R7 — Global read on `cards`/`workbookCards`/Storage **[Info — no action]**

Both are deliberately, explicitly documented as readable by any authenticated user
("card IDs are not guessable... future sharing/marketplace features require..."). R1's
exploit doesn't expose anything an attacker couldn't already read directly via this
same design decision — it only lets them structurally *attach* content they could
already see. Changing this would require a real ACL/sharing model, which the
project's own docs describe as intentionally deferred. No fix recommended; noted as a
residual risk to keep in mind if a future feature ever assumes card content is private
by default.

---

## Test coverage

Added `firestore-tests/rules.test.js` — a `@firebase/rules-unit-testing` suite run
against the local Firestore + Storage emulators (`firebase emulators:exec`), covering
the allow/deny paths for every fix above (R1–R6) plus the pre-existing `users/{uid}`
owner-only read from #297. See `firestore-tests/README.md` for how to run it.

## Deploy status

Rule changes are implemented and tested against the emulator in this PR, but **not
yet deployed** — deploy via `firebase deploy --only firestore:rules,storage
--project flash-me-7a1a2` after merge, on explicit go-ahead (same discipline as
#297's rollout).
