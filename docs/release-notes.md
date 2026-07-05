# Release Notes

---

## v0.6.0 — Alpha 0.6 — 2026-07-04

### New features
- Re-queue missed cards within a study session — an optional setting brings back cards you got wrong so they keep reappearing until you answer them right in one go (#214)
- Progressive question reveal — on cards with several questions, each question now appears one at a time as you answer the previous one, instead of all at once (#215)
- Search and filter your cards when adding them to a set, so large libraries are easier to work through (#210)
- Add distractor words in bulk — paste a comma-separated list to create several at once when building fill-in-the-blanks and grid questions (#209)
- Answer boxes in fill-in-the-blanks and grid questions are now sized to the expected answer length, as a subtle length hint (#216)
- Answering a question is now final across all question types — the "Try Again" retry was removed for consistent scoring (#213)

### Bug fixes
- None

### Known issues
- None identified

---

## v0.5.0 — Alpha 0.5 — 2026-07-01

### New features
- Fill-in-the-blanks question type — blank out selected words in a sentence and answer by picking from a word bank or typing the answer (#170)
- Complete-the-grid question type — fill cells in a labelled grid, ideal for conjugation tables and similar structured patterns (#167)
- Distractor words for complete-the-grid — add extra words to the word bank to increase difficulty (#203)
- Smart answer matching — text input answers are accepted with missing diacritics or minor typing slips; full diacritic entry still accepted (#168)
- Three-level answer feedback — answers are graded as correct, close (minor slip forgiven), or incorrect, with varied confirmation phrases (#206)
- Question-as-card mode — single-question workbook cards can open directly to the question without tapping "More" (#169)

### Bug fixes
- Fixed "Study Again" button showing a spinner indefinitely after completing a session (#211)

### Known issues
- None identified

---

## v0.4a — Alpha 0.4 — 2026-06-25

### New features
- Study Review mode: study all cards you've flagged for extra practice, pulled from across your entire library (#179)
- Study Mistakes mode: study cards where you've recently answered incorrectly (#179)
- Language filter for Study Review and Study Mistakes — when your pool spans multiple languages, choose which one to focus on (#180)
- High contrast theme — automatically applied when your device's high contrast accessibility setting is on (#94)
- Haptic feedback in study mode — a light pulse for correct answers, a stronger pulse for incorrect ones, and a subtle click when self-evaluating or toggling card marks (#86)

### Bug fixes
- Fixed import incorrectly flagging unchanged multiple-choice cards as modified (#177)

### Known issues
- None identified

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