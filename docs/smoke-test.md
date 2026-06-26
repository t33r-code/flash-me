# Agora — Release Smoke Test

A fast manual pass over the app's core flows, run before tagging a release. It is **release-agnostic** — the same checklist every time — plus a short per-release section for whatever changed in that milestone.

**Goal:** catch regressions a green CI can miss. Much of the app's behaviour (haptics, share sheets, media round-trip, question rendering) has no CI-observable surface, and model-only changes can silently break existing flows (e.g. a new sealed-class question type that doesn't break the build but mis-renders an old one).

**How to use:**
- Run **Section 0** first — if the app won't build/launch, stop.
- Run the **core sections (1–7)** on at least one **Android** device (primary platform) and, where noted, one of iOS / Windows.
- Fill the **per-release section** from the milestone's changes (the `/prepare-release` skill prompts for this).
- If short on time, the highest-value pass is **Section 0 + any section touched by the release + Section 4 (Study)**, since study is where most question/scoring regressions surface.

Legend: ✅ pass · ❌ fail (file an issue) · ➖ not applicable this release

---

## 0. Build & launch (gate)

| Step | Expected | Result |
|---|---|---|
| `flutter pub get` clean | No resolution errors | |
| `flutter analyze` clean | No errors | |
| Launch on Android device | Reaches home, no red screens / console errors | |
| Launch on a second platform (iOS or Windows) | Same | |

## 1. Authentication

| Step | Expected | Result |
|---|---|---|
| Register with email/password | Account created, lands on home | |
| Sign out, sign back in | Succeeds | |
| Google Sign-In (real device) | Succeeds; profile populated | |
| Forgot-password flow | Reset email sent | |

## 2. Cards & Templates

| Step | Expected | Result |
|---|---|---|
| Create a **Flash Card** with each question type (text input, multiple choice, word order) | Saves; reloads with all data intact | |
| Edit a Flash Card; change a question type and back | Inputs survive the switch | |
| Create a **Workbook Card** (prompt + multiple questions) | Saves; questions render in editor | |
| Create a **Card Template** and a **Question Template** of each type | Save; correct type labels shown in lists | |
| Create a card **from a template** | Pre-fills as expected | |
| Delete a card | Removed; associated media cleaned up | |

## 3. Card Sets

| Step | Expected | Result |
|---|---|---|
| Create a set; add flash + workbook cards | `cardCount` correct; both types listed | |
| Remove a card from a set | Count decrements; card itself not deleted | |
| Reorder / edit set metadata (name, tags, colour) | Persists | |

## 4. Study Mode

| Step | Expected | Result |
|---|---|---|
| Start a session on a mixed set | Cards sequence correctly | |
| Answer each **question type** correct and incorrect | Correct/incorrect grading + green/red feedback | |
| **Self-eval** (Knew it / Not yet) and **Review / Skip** marks | Recorded; one mark per card | |
| **Haptics** (Android): correct vs incorrect answer | Light pulse correct, stronger incorrect (all question types, incl. MC list *and* grid) | |
| Haptics: self-eval / mark toggle | Subtle selection click | |
| Haptics on iOS | Present (built-in HapticFeedback) | |
| Resume an interrupted session | Restores position and progress | |
| Finish a session | Summary shows per-question results + time | |

## 5. Import / Export

| Step | Expected | Result |
|---|---|---|
| Export a set on **Android** | System share sheet opens with `.zip` | |
| Export on **desktop** | Saved to Downloads; path reported | |
| Import a previously exported ZIP | Cards, media, templates restore intact | |
| Import a ZIP that overlaps existing cards | Diff report flags changed vs unchanged correctly | |

## 6. Account & Settings

| Step | Expected | Result |
|---|---|---|
| Edit display name | Persists | |
| Toggle theme (System / Light / Dark) | Applies immediately | |
| OS high-contrast setting on | High-contrast theme applies | |
| Delete account | Cascade delete; signed out | |

## 7. Offline

| Step | Expected | Result |
|---|---|---|
| Disable network; open cached sets/cards | Loads from cache; offline banner shown | |
| Re-enable network | Syncs without error | |

---

## Per-release checks

> Fill from the milestone's merged PRs. List each user-visible change with a concrete step + expected result. For **model-only / dependency-only** changes with no new surface, add a **regression** line instead: name the existing flow most likely to break and confirm it still works.

| Change (PR/issue) | Step | Expected | Result |
|---|---|---|---|
| _e.g. #170 fill-in-blanks model (model-only)_ | _Study a set with the 3 existing question types_ | _All still render and grade — no regression from the new sealed subtype_ | |
| | | | |