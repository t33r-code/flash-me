# Release Notes

---

## v0.7.0 — Alpha 0.7 — 2026-07-26

### New features
- In-place set builder — build a set without leaving the editor: create new cards in the set, drag existing cards in from a library drawer, drag to reorder, edit cards in place, and remove them, all on one screen (#232, #233, #234, #245, #247, #259, #260)
- Multi-pane set view — a master–detail layout on wider screens so you can see the set and a card side by side (#236)
- Author-controlled card order — arrange the cards in a set, with an option to enforce that order (#244); study honours the enforced order and turns off shuffle when it's on (#246)
- Clone a card to quickly enter similar ones — for both Flash Cards (#231) and Workbook Cards (#274)
- Use Question and Card Templates when adding or editing Workbook Cards (#248)
- Multi-select in the card library for bulk actions — add to a set, delete, tag, or set language on many cards at once (#238)
- Hover states and right-click context menus for cards and sets on desktop (#237)
- Side navigation rail on landscape and desktop layouts for quicker navigation (#230)
- Desktop keyboard support — study shortcuts (arrow keys, Enter, mark Skip/Review), Enter-to-confirm / Esc-to-cancel in editors and dialogs, and a keyboard-navigable colour picker (#87, #235)

### Bug fixes
- Fixed a permission error when deleting a Workbook Card (#201)

### Known issues
- None identified

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