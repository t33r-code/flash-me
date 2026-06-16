# Release Notes Template

Use this template when preparing a release. Fill in each section, then condense the user-facing content into `whatsnew/whatsnew-en-US` (plain text, 500-character Play Store limit).

---

## vX.Y — Sprint N — YYYY-MM-DD

### New features
- 

### Bug fixes
- 

### Known issues
- 

---

## Play Store "What's New" checklist

1. Edit `whatsnew/whatsnew-en-US` with a plain-text summary (max 500 characters).
2. Commit the file on `main` before pushing the `vX.Y` tag.
3. The `release` workflow picks it up automatically and submits it with the AAB.

Keep the tone user-facing ("You can now…", "Fixed a crash when…"). Omit internal tech-debt items.