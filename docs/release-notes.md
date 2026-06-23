# Release Notes

---

## v0.3a — Alpha 0.3 — 2026-06-23

### New features
- Shuffle multiple choice options each time a card is shown in study mode (#82)
- Richer study session summary with per-question results and time spent per card (#84)
- Cards and sets now load offline using local caching (#85)
- Link a Google account and email/password sign-in to a single account (#75)
- Delete your account directly from within the app (#77)
- Card edit screen now shows when a card was created, last updated, and by whom (#80)
- Question type indicators on card previews (#81)
- All UI strings externalised for future translation support (#95)

### Bug fixes
- Fixed Firestore listener leak — previously one listener per visited set or search prefix accumulated for the lifetime of the session (#92)

### Known issues
- None identified