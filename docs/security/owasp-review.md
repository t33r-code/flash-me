# OWASP Security Review — Agora (#286)

Review of the app/client and end-to-end posture against the **OWASP Mobile Top 10**
(cross-checked against the Web/API Top 10 for the web build). Firestore/Storage
**rules** are reviewed separately in **#285** — this review only confirms whether the
*client* relies on server-side rules, and flags one confirmed rule-level exposure it
directly depends on.

- **Scope of this pass:** P1 surfaces — untrusted (Market) content rendering,
  import parsing & media, and auth/authorization/account-deletion.
- **Deferred (P2/P3):** supply-chain advisory scan, privacy/Data-Safety
  reconciliation, web-build specifics (source maps/CSP), comms/config hardening.
  See #286 for the full plan.

## Summary of findings (P1)

| ID | Severity | Area | Finding |
|----|----------|------|---------|
| F1 | **High** | Auth / privacy (M3/M6) | Any authenticated user can read every other user's **email** (and photoUrl/timestamps) via `users/{uid}` |
| F2 | **Medium** | Import (M4) | Archive size guard checks entry **count**, not bytes — ineffective against a zip bomb / oversized archive (client OOM / DoS) |
| F3 | **Low** | Import (M4) | Malformed-but-valid JSON (wrong types) throws an uncaught `CastError` instead of a handled `AppException` |
| F4 | **Low** | Import (M4) | Untrusted file extension from the import flows into the Storage object name (stays under `users/{uid}/`, so no cross-user write — cosmetic/hardening) |
| F5 | **Low** | Privacy (M6) | User **email** written to device logs in auth flows |
| F6 | **Low** | Privacy (M6) | Account deletion doesn't remove **feedback** submissions; tombstone retention isn't documented for Play Data Safety |
| F7 | **Info** | Supply chain (M2) | `flutter_markdown_plus` and `http` are declared but **unused** (dead deps) |

**Good news (no action):** the app has essentially **no untrusted-content injection
surface** — no `WebView`/`HtmlElementView`/iframe, no markdown/HTML rendering
(descriptions render as plain `Text`), and the only `launchUrl` uses a fixed help
URL. Import media handling has **no path traversal** — the untrusted path is used only
for an in-memory `archive.findFile()` lookup and the Storage destination is
server-derived (`users/{uid}/cards/…`). Auth uses SDK-managed tokens (no raw token
storage), and unlink is guarded against removing the only sign-in method.

---

## F1 — Cross-user email exposure via `users/{uid}` **[High]**

**Evidence.**
- `firestore.rules` — `match /users/{userId} { allow read: if isAuth(); … }`: **any**
  authenticated user can read **any** user document.
- The user document contains `email`, `displayName`, `photoUrl`, `createdAt`,
  `lastLoginAt` (`firebase_auth_repository.dart:255` `_createUserDocument`).
- The Market renders author names by having the client read the author's **full**
  user doc: `getUserDisplayName(userId)`
  (`firebase_auth_repository.dart:226`) → used by `sets_screen.dart:823`.
- Market set documents expose the author's uid (`CardSet.userId`), so author uids are
  discoverable by any user browsing the Market.

**Impact.** Firestore rules grant read access per *document*, not per *field* — so
allowing the client to read a display name also exposes that user's **email address**.
Any account can therefore harvest the email (and photo/first-seen/last-seen) of any
other user, using uids surfaced by the Market or by enumeration. This is a personal-data
(PII) exposure.

**Remediation (pick one).**
1. **Denormalize** the author's display name onto the public set document
   (`set.authorDisplayName`) at publish time, so the client never reads another user's
   user doc — then tighten the rule to `allow read: if isUser(userId)` (own doc only).
   *(Recommended — smallest surface, no extra reads.)*
2. Split public profile fields into a `publicProfiles/{uid}` collection holding only
   `displayName`/`photoUrl`, world-readable by authed users; keep `users/{uid}` private.
3. A callable Cloud Function that returns only the display name.

Rule change belongs to **#285**; the client-side denormalization/read change belongs
here. They must land together (tightening the rule without option 1/2/3 breaks Market
author names).

## F2 — Ineffective archive size guard (zip bomb / OOM) **[Medium]**

**Evidence.** `import_service.dart:57`
```dart
if (archive.length > 50 * 1024 * 1024) {
  throw AppException('Archive exceeds the 50 MB limit.');
}
```
`Archive.length` is the **number of entries**, not a byte size — the check compares an
entry count to ~52 million and never fires. `ZipDecoder().decodeBytes()` and each
`file.content` decompress into memory with no real cap.

**Impact.** A crafted (zip bomb) or simply large shared archive can exhaust memory and
crash the app on import — a client-side DoS. Requires the user to import a malicious
file (e.g. a "study set" shared by an attacker).

**Remediation.** Enforce a real byte budget: cap `zipBytes.length` before decoding, and
sum uncompressed sizes (`archive.files.fold(0, (s, f) => s + f.size)`) against the 50 MB
limit before reading `.content`. Reject oversized archives with the existing
`AppException`.

## F3 — Malformed JSON throws uncaught `CastError` **[Low]**

**Evidence.** `import_service.dart:141` `(root['sets'] as List).cast<…>()` and similar
casts run **after** the `jsonDecode` try/catch. Valid JSON with the wrong shape (e.g.
`"sets": "x"`) throws a `TypeError`/`CastError` that isn't wrapped in `AppException`.

**Impact.** Poor input validation — a malformed import surfaces as an unhandled error
rather than a friendly "invalid format" message. No breach; robustness/UX.

**Remediation.** Validate the shape of `sets`/`set`/template entries (type-check before
cast) and throw `AppException('Invalid format …')` on mismatch.

## F4 — Untrusted extension in Storage object name **[Low]**

**Evidence.** `import/import_media.dart:19-23` derives `ext` from the untrusted import
path (`path.split('.').last`) and concatenates it into
`users/$userId/cards/{timestamp}.$ext`. A path whose "extension" contains `/` or `..`
yields an odd object name, but the `users/$userId/` prefix is fixed, so it stays within
the user's own Storage folder (no cross-user write).

**Remediation (hardening).** Sanitize `ext` to `[A-Za-z0-9]+` (and bound its length)
before building the object name. Optionally validate the media bytes' magic number
against the declared content type (`_contentType` whitelist) so non-media bytes aren't
stored under an image/audio MIME type.

## F5 — Email written to device logs **[Low]**

**Evidence.** `firebase_auth_repository.dart` logs raw email in several flows —
`_logger.i('Registering user: $email')` (34), `'Signing in: $email'` (52),
`'Sending password reset to $email'` (197).

**Impact.** PII in device logs (logcat/console). Not sent to any remote sink, so the
exposure is local, but it's avoidable PII handling.

**Remediation.** Log the uid or a redacted email; never log raw credentials/email. (Also
review other `logger` call sites for PII.)

## F6 — Account-deletion completeness & tombstone disclosure **[Low / privacy]**

**Evidence.** `account_deletion_service.dart` anonymises the user doc (tombstone) and
hard-deletes cards, workbook cards, sets, templates, question templates, setCards,
set/card acquisitions, and the study-sessions / card-marks / question-results
subcollections. **Feedback** submissions (`firebase_feedback_repository.dart`, an
`add()` to `feedbackCollection`) are **not** removed; global `tags` (keyed by tag name,
with `createdBy`) are also retained (arguably correct as shared aggregates).

**Impact & actions.**
- If feedback documents carry a uid/email/message, they persist after deletion — verify
  the feedback shape and either anonymise on deletion or disclose retention.
- The tombstone (`displayName: 'Deleted User'`, timestamps retained) is a deliberate
  design choice, but **must be disclosed** in the privacy policy / Play Data Safety.
  **TAKE ACTION (Play Console / privacy policy):** confirm the declaration covers
  post-deletion tombstone + feedback retention.
- Minor: deletion isn't atomic — content is purged before the final
  `currentUser.delete()`, which can fail with `requires-recent-login`, leaving an
  auth account with no data. And the service trusts its `userId` argument; asserting
  `userId == currentUser.uid` would be cheap defense-in-depth (rules already block
  cross-user deletes).

## F7 — Dead dependencies **[Info]**

`flutter_markdown_plus` and `http` are declared in `pubspec.yaml` but imported nowhere
in `lib/`. Removing them trims the supply-chain surface. (`card_set.dart:10`'s comment
claiming descriptions are "rendered with flutter_markdown_plus" is stale — they render
as plain `Text`.)

**Forward guardrail:** if markdown rendering is ever (re)introduced for Market
descriptions, it must disable raw HTML and restrict link schemes (no `javascript:`),
since descriptions are untrusted other-user content.

---

## Out of scope / deferred

- **Firestore/Storage rules** — owned by **#285**. F1 depends on the `users/{uid}` read
  rule and is cross-referenced there.
- **P2:** supply-chain advisory scan (`flutter pub outdated` + advisories, extra
  scrutiny on the `flutter_markdown_plus` fork), privacy/Data-Safety reconciliation,
  web build (source maps in `build/web`, CSP, `firebase_options` client-restricted keys,
  authorized domains — ties to #289).
- **P3:** comms/config (cleartext, Android `network_security_config`, Crashlytics data
  scope).
