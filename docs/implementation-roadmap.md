# Flash Me - Implementation Roadmap

This document tracks the phased implementation of Flash Me, organised into three versioned releases. **Alpha 0.1** covers the core app (authentication through study mode and import/export). **Alpha 0.2** picks up everything deferred from Alpha 0.1 — tag infrastructure, search/filter, comprehensive testing, accessibility, documentation, and deployment prep. **Beta 0.1** covers the content marketplace and long-term platform features.

## Overview

| Block | Scope | Status |
|---|---|---|
| [Alpha 0.1](#alpha-01--foundation-to-launch) | Phases 1–7: auth, cards, sets, study, import/export, basic polish | Largely complete |
| [Alpha 0.2](#alpha-02--completeness--polish) | Deferred items from Alpha 0.1: tags, search, testing infra, docs, deployment | Planned |
| [Beta 0.1](#beta-01--marketplace--platform) | Marketplace, Lessons, Web Dashboard, sharing | Long-term |

---

## Alpha 0.1 — Foundation to Launch

All seven core phases. Items marked *(→ deferred to Alpha 0.2)* are not done in this block and are listed again in Alpha 0.2.

### Phase 1: Project Setup & Authentication (Weeks 1-2)

**Goal**: Establish project foundation and user authentication system.

**Priority**: Critical - All other features depend on this.

#### Tasks
- [x] Set up Flutter project with multi-platform support (iOS, Android, Web, Windows, macOS, Linux)
- [x] Configure Firebase project in Firebase Console
- [x] Set up Firebase configuration for all platforms (google-services.json, GoogleService-Info.plist, etc.)
- [x] Install and configure `firebase_auth`, `google_sign_in`, `cloud_firestore`, `firebase_storage` packages
- [x] Set up project structure (lib folders, models, providers, screens, services)
- [x] Create authentication service layer (AuthService)
- [x] Implement local registration screen with email/password validation
- [x] Implement `createUserWithEmailAndPassword()` Firebase call
- [x] Implement optional email verification flow
- [x] Implement Google Sign-In button and flow
- [x] Handle first-time Google Sign-In user creation
- [ ] Implement account linking logic for multiple auth providers *(→ deferred to Alpha 0.2)*
- [x] Set up Firestore collection schema for user profiles (`users/{userId}`)
- [x] Create Firestore user document on successful registration
- [x] Implement auto-login after registration
- [x] Implement logout functionality
- [x] Implement session persistence (keep user logged in across app restarts)
- [x] Add error handling for auth failures (invalid email, weak password, etc.)
- [x] Set up Firebase security rules for user data access
- [x] Implement password reset flow (forgot password screen + sendPasswordResetEmail())
- [x] Implement user profile management screen (view/edit displayName, photoURL)
- [ ] Test both registration flows (local and Google) on all platforms *(→ deferred to Alpha 0.2)*
- [x] Create authentication state provider (using Provider/Riverpod)

**Deliverable**: Working registration and login system on all platforms.

---

### Phase 2: Core Data Models & Database Schema (Weeks 2-3)

**Goal**: Establish data structures and backend infrastructure.

**Dependencies**: Phase 1 (need authenticated user)

**Priority**: Critical - Foundation for all feature development.

#### Tasks
- [x] Create Dart data models for: User, Card, CardField, CardTemplate, CardSet, StudySession
- [x] Design and create Firestore collection structure:
  - [x] `users/{userId}` — user profiles
  - [x] `templates/{templateId}` — card templates
  - [x] `cards/{cardId}` — individual cards
  - [x] `sets/{setId}` — card sets
  - [x] `setCards/{linkId}` — many-to-many join (replaces cardIds[] on sets)
  - [x] `users/{userId}/studySessions/{sessionId}` — study sessions
- [x] Create JSON serialization/deserialization for all models (fromJson, toJson, fromFirestore, toFirestore)
- [x] Set up Firestore indexes:
  - [x] Query by userId + createdAt (templates, cards, sets)
  - [x] Query by setId + addedAt (setCards — for retrieving cards in a set)
  - [x] Query by cardId + addedAt (setCards — for set membership lookup)
  - [x] Query by setId + status + lastAccessTime (study sessions)
- [x] Create data service layer (TemplateService, CardService, CardSetService, StudySessionService)
- [x] Implement Firestore write operations (create, update, delete)
- [x] Implement Firestore read operations (get, list, query)
- [x] Implement batch operations for bulk card operations
- [x] Set up proper error handling and exception types (AppException)
- [x] Wire Riverpod providers for all services and streams
- [ ] Create validation logic for all models (deferred to Phase 3 with UI) *(→ deferred to Alpha 0.2)*
- [x] Test data models with unit tests *(covered in Phase 7 unit-tests pass)*
- [ ] Test Firestore operations with integration tests (deferred — requires Firebase emulator setup) *(→ deferred to Alpha 0.2)*

**Deliverable**: Complete data layer with working Firestore integration.

---

### Phase 3: Card Templates & Card Management (Weeks 3-5)

**Goal**: Enable users to create card templates and manage individual cards.

**Dependencies**: Phase 2 (need data layer)

**Priority**: High - Core data entry functionality.

#### Tasks

##### Phase 3a — Navigation shell + My Cards screen (complete)
- [x] Add `tags: List<String>` to FlashCard model (user-defined labels for search/filter)
- [x] Replace HomeScreen routing with MainScreen (BottomNavigationBar shell)
- [x] Bottom nav: Sets / Cards / Templates / Profile tabs (IndexedStack, mobile-first)
- [x] My Cards screen: card list from userCardsProvider, empty state, search bar stub, tag filter stub
- [x] Templates screen: placeholder (full UI in Phase 3c)
- [x] Remove stale profile-button from HomeScreen AppBar (Profile is now a tab)
- [x] Remove pop-back auth listener from ProfileScreen (main.dart handles it)

##### Phase 3b — Card creation / edit / delete (complete)
- [x] Card creation form: primaryWord, translation, tags, add/remove additional fields
- [x] Support all three field types in the form (reveal, text_input, multiple_choice)
- [x] Card edit screen (same CardFormScreen, pre-populated from existing card)
- [x] Card deletion with confirmation dialog (AppBar delete icon, edit mode only)
- [x] Wire My Cards FAB → create form; card list tap → edit form

##### Phase 3c — Templates (complete)
- [x] TemplateFormScreen: create/edit template (name, description, primaryWordHidden flag)
- [x] Dynamic field builder — same three field types as cards but answer-free
  - Reveal: structure only (answer filled per card)
  - Text input: hint + exact-match toggle (no correct answers)
  - Multiple choice: pre-fillable options list (no correct index)
- [x] TemplatesScreen: live list from userTemplatesProvider, empty state, FAB → create from scratch
- [x] Template edit and delete (with confirmation dialog)
- [x] "Save as Template" overflow menu on CardFormScreen — nulls out answers,
      pre-populates TemplateFormScreen with the card's field structure

##### Phase 3d — Card from template (complete)
- [x] "Use Template" button in Additional Fields section of CardFormScreen
- [x] Bottom sheet template picker listing user's templates
- [x] Applying a template pre-populates fields (config carried over, answers blank)
- [x] Confirmation dialog when replacing existing fields

##### Phase 3e — Workbook Cards

**Goal**: Add a second card type — prompt + structured questions — alongside Flash Cards. See `docs/design.md § Workbook Cards` for the full specification.

**Data layer**
- [x] `WorkbookCard` model: `fromFirestore` / `toFirestore` / `toJson`
- [x] `WorkbookQuestion` sealed class hierarchy: `TextInputQuestion`, `MultipleChoiceQuestion`, `WordOrderQuestion`
- [x] `MultipleChoiceDisplayMode` enum (`list` | `chips`)
- [x] `WorkbookCardRepository` abstract interface + `FirebaseWorkbookCardRepository`
- [x] `workbookCardRepositoryProvider`, `userWorkbookCardsProvider`
- [x] Extend `SetCard` model with `cardType: String` (`'flashcard'` | `'workbook'`); update `FirebaseCardSetRepository` writes to include it (existing docs without the field default to `'flashcard'`)
- [x] `CardSetRepository.watchSetCards` — streams raw `SetCard` join objects with `cardType` for mixed-set session building
- [x] Extend `StudySession` with `cardTypeMap: Map<String, String>`; update session repository reads/writes (absent field defaults to all `'flashcard'`)
- [x] Firestore security rules for `workbookCards/` (owner-only, same pattern as `cards/`)
- [x] Firestore indexes: `workbookCards` by `createdBy + createdAt`; deploy both

**UI — creation / editing**
- [x] `WorkbookCardFormScreen`: prompt text field + ordered question list with add / remove / reorder
- [x] Inline question editors for all three types (expand in-place; no separate screen)
- [x] Word bank editor: chip-add input for individual tiles; correct-order chip builder
- [x] Display-mode toggle (`list` / `chips`) in the multiple choice question editor
- [x] My Cards screen FAB: card-type chooser bottom sheet (Flash Card / Workbook Card)
- [x] Set detail screen: add-card picker shows both flash cards and workbook cards; passes correct `cardType` to `addCardToSet` (Phase 4 set-detail work)

**UI — study**
- [x] Study session screen: read `cardTypeMap` from session; branch to `_WorkbookCardView` vs existing flash card view
- [x] `_WorkbookCardView`: prompt block + all questions revealed on More tap
- [x] Text input and multiple choice question widgets (`_WorkbookTextInputCard`, `_WorkbookMultipleChoiceCard`)
- [x] `_WordOrderCard`: word bank chip row + answer chip row; tap-to-place / tap-to-return; Check + feedback
- [x] Chips display mode for multiple choice questions
- [x] Question result tracking for workbook questions (`{cardId}_{questionId}` pattern)
- [x] Study setup screen: populate `cardTypeMap` via `watchSetCards` when creating a new session

**Firestore / deploy**
- [x] Deploy updated Firestore rules
- [x] Deploy updated Firestore indexes

##### Flash Cards (remaining / deferred)
- [x] Image and audio attachment on Flash Cards — picker UI in CardFormScreen; upload to Firebase Storage on save; replace/clear deletes old file; thumbnail/audio indicator shown in form
- [ ] Add card metadata display (createdAt, updatedAt, createdBy) *(→ deferred to Alpha 0.2)*
- [ ] Implement field type icons/indicators *(→ deferred to Alpha 0.2)*
- [ ] Add field randomization for multiple choice (optional) *(→ deferred to Alpha 0.2)*
- [ ] Create default/example templates *(→ deferred to Alpha 0.2)*
- [ ] Implement bulk card creation via JSON import (Phase 6) *(→ deferred to Alpha 0.2)*

**Deliverable**: Full CRUD for templates and cards, with working field types.

---

### Phase 4: Card Sets Management (Weeks 5-6)

**Goal**: Enable users to organize cards into sets and manage membership.

**Dependencies**: Phase 3 (need cards to organize)

**Priority**: High - Core organizational feature.

#### Tasks

##### Phase 4a — My Sets screen + set CRUD (complete)
- [x] Fix Firestore list-rule violations in CardSetRepository (add userId constraint to all setCards queries)
- [x] MySetsScreen: live list from userSetsProvider, empty state, colour accent bar, tags, relative date
- [x] SetFormScreen: create/edit a set (name, description, colour picker, tags)
- [x] Set deletion with confirmation (cleans up all setCards links)
- [x] SetDetailScreen: placeholder showing card count; edit button → SetFormScreen
- [x] Wire MySetsScreen into the main nav shell (replaces HomeScreen placeholder)

##### Phase 4b — Set detail + card membership (complete)
- [x] Full card list in SetDetailScreen (live via cardsInSetProvider)
- [x] Add cards to set — DraggableScrollableSheet picker with multi-select checkboxes; already-in-set cards shown greyed at the bottom
- [x] Remove card from set — swipe-left Dismissible on each card row
- [x] setByIdProvider — keeps AppBar title in sync after editing set metadata
- [x] Update Firestore indexes: setCards composite indexes now include userId (required by ordered queries with the security rule constraint)

##### Phase 4c — Search & filter (deferred, depends on Phase 4d)
- [ ] Search sets by name *(→ deferred to Alpha 0.2)*
- [ ] Filter sets by tag (requires global tag system from Phase 4d) *(→ deferred to Alpha 0.2)*
- [ ] Sort options (by name, last updated, card count) *(→ deferred to Alpha 0.2)*
- [ ] Search / filter within set detail view *(→ deferred to Alpha 0.2)*
- [ ] Search / filter on My Cards screen (search bar is already stubbed) *(→ deferred to Alpha 0.2)*

##### Phase 4d — Global Tag System (deferred to Alpha 0.2)

**Rationale for deferral:** Tag infrastructure is a prerequisite for Phase 4c (tag-based filtering) and for the long-term marketplace feature, but does not block Phase 5 (Study Mode). Implementing it after Phase 5 allows Study Mode — the core value proposition — to ship sooner while the tag system is built correctly without time pressure.

**Design summary:** Tags are stored in a global Firestore collection (`tags/{normalizedName}`) shared across all users. The document ID is the normalized form of the tag (lowercase, trimmed, spaces collapsed to hyphens). A `usageCount` field is maintained as tags are added/removed across all content types. The autocomplete widget queries this collection with a prefix filter. Full design in [docs/design.md — Tag System](design.md#tag-system).

###### 4d-1 — Firestore Infrastructure ✅
- [x] Deploy `tags` collection security rules (read: any authed user; create: authed + `usageCount=1` constraint; update: count-only, `displayName`/`createdBy`/`normalizedName` immutable; delete: never)
- [x] Deploy Firestore indexes: `normalizedName ASC` (prefix queries), `usageCount DESC` (popularity), composite `(createdBy, tags[])` on `cards`, composite `(userId, tags[])` on `sets`

###### 4d-2 — Data Layer ✅
- [x] Implement `normalizeTag(String input) → String` utility in `AppHelpers`
- [x] Implement `TagRepository` abstract interface: `upsertTag`, `decrementTag`, `searchTags(prefix)`
- [x] Implement `FirebaseTagRepository`
- [x] Add `tagRepositoryProvider` and `tagSearchProvider.family` to provider layer

###### 4d-3 — Content Lifecycle Hooks ✅
- [x] Card create/edit: diff old vs new tags → upsert added, decrement removed
- [x] Set create/edit: same
- [x] Card delete: decrement all tags on the card
- [x] Set delete: decrement all tags on the set
- [x] Import: upsert every tag on new cards; diff tags on updated cards

###### 4d-4 — TagInputField Widget ✅
- [x] Build shared `TagInputField`: debounced autocomplete (~300ms), chip display, comma-paste, Enter-to-create, `usageCount >= 2` threshold (own tags always shown)
- [x] Replace chip-input on `CardFormScreen` with `TagInputField`
- [x] Replace chip-input on `SetFormScreen` with `TagInputField`
- [x] Replace chip-input on `WorkbookCardFormScreen` + add the 4d-3 lifecycle hooks it was missing (folded in for consistency)

###### 4d-5 — Search & Filter (Phase 4c) ✅
- [x] Tag filter on My Cards screen (search bar already stubbed)
- [x] Tag filter on My Sets screen
- [x] Name search on My Cards and My Sets screens
- [x] Sort options (name, last updated, card count) on sets

**Deliverable**: Complete set management with card organization.

---

### Phase 5: Study Mode - The Core Experience (Weeks 6-8)

**Goal**: Implement the primary user interaction - studying cards with full session tracking.

**Dependencies**: Phase 4 (need sets to study)

**Priority**: Critical - This is the core value proposition.

#### Tasks

##### Phase 5a — Session infrastructure + session selection UI (complete)
- [x] Confirm StudySession + CardSessionData data models and Firestore schema (already in Phase 2)
- [x] Implement study session repository (FirebaseStudySessionRepository)
- [x] Wire studySessionRepositoryProvider and sessionHistoryProvider
- [x] Study set selection UI: tap a set → prompt "Resume" vs "Start New Session" when an active session exists
- [x] Session configuration screen: shuffle toggle, (future: card filters)
- [x] Session initialization: build card sequence (ordered or shuffled), write session document to Firestore
- [x] Card shuffling option (Fisher-Yates on the card sequence)

##### Phase 5b — Card display & field interaction (complete)
- [x] Build study session screen scaffold (AppBar with progress + exit, card area, control row)
- [x] Primary field: show `primaryWord` (and image/audio if present); tap to reveal `translation`
- [x] Respect `primaryWordHidden` flag — hide word until "Show Word" is tapped when set
- [x] Reveal-on-click fields: prompt label + tap-to-reveal answer
- [x] Text input fields: text field + submit; case-insensitive validation; respect `exactMatch` flag; correct/incorrect feedback
- [x] Multiple choice fields: option buttons; highlight correct/incorrect on selection
- [x] "Try Again" button to re-attempt a field after a wrong answer
- [x] Feedback messaging (correct, incorrect, partial) with visual distinction

##### Phase 5c — Session controls, navigation & persistence (complete)
- [x] Navigation controls: Previous / Next buttons; Know / Don't Know marking
- [x] Progress indicator: "Card X of Y" label + linear progress bar
- [x] Card marking: known/unknown toggles with visual indicator per card
- [x] Boundary checks: disable Previous on first card, Next on last card
- [x] Card session state tracking: record per-card attempts, result, and timestamp
- [x] Auto-save to Firestore after each navigation action (debounced ~1 s to reduce write volume)
- [x] Session pause: write current state and navigate back; session stays in "active" status
- [x] Session resume: restore card sequence, current index, and all per-card state from Firestore
- [x] Session completion: mark status "completed", calculate and write SessionStats (total, known, unknown, duration)

##### Phase 5d — Session summary & history (complete)
- [x] Session summary screen: shown on completion; display stats (cards studied, known %, time, date)
- [x] "Study Again" and "Done" actions on summary screen
- [x] Session history list: per-set list of past sessions from sessionHistoryProvider
- [x] Session history entry: date, duration, known/unknown counts, completion status

##### Advanced features (deferred)
- [ ] Offline support with local caching *(→ deferred to Alpha 0.2)*
- [ ] Haptic feedback for answer results *(→ deferred to Alpha 0.2)*
- [ ] Keyboard shortcuts (arrow keys, Enter) for desktop *(→ deferred to Alpha 0.2)*
- [ ] Card preloading for smooth performance *(→ deferred to Alpha 0.2)*

**Deliverable**: Fully functional study mode with session tracking and statistics.

---

### Phase 6: Import/Export (Weeks 8-9)

**Goal**: Enable users to bulk-create cards, share sets, and back up their data via JSON + ZIP.

**Dependencies**: Phase 4 (need sets to export), Phase 3 (need cards)

**Priority**: Medium - Important for data portability and bulk card creation.

#### Tasks

##### Phase 6a — Export (complete)
- [x] Implement Firestore export function (retrieve full set + card data)
- [x] Build ZIP archive: write `cards.json` with relative `media/` paths, download media from Firebase Storage
- [x] Add export metadata to `cards.json` (version, exportDate)
- [x] Create export UI (trigger from set detail screen)
- [x] Implement file download / share sheet

##### Phase 6b — Import (account-level) (complete)
- [x] Fix: strip `fieldId` from exported card fields in `ExportService`
- [x] Fix: enforce `primaryWord` uniqueness within a set in the card picker UI
- [x] New Data screen (accessible from profile screen; hosts both Import and Export sections)
- [x] Import file picker (accepts `.zip`; triggers parse + diff immediately on pick)
- [x] ZIP parser supporting both single-set (`set: {}`) and multi-set (`sets: []`) formats
- [x] Validate required fields (primaryWord, translation, field types, content structure)
- [x] Diff engine: match cards by `primaryWord` within the target set; check global library by `[primaryWord, translation]` before creating — matched library cards are linked (not duplicated)
- [x] Import preview dialog:
  - Options: [Delete cards not in import] [Skip card updates] — apply to all sets
  - Per-set sections: matched set name or "New set"; New / From library / Updated / Deleted card counts
  - Expandable lists: New shows primaryWord + translation; From library shows existing card being linked; Updated shows old→new value per changed field + other affected sets; Deleted shown only when delete option is on
  - Deleting whole sets is never part of import (only per-card deletion within a set)
- [x] Firestore batch write: create/update sets + cards + upload media to Firebase Storage
- [ ] Run tag upsert for every imported tag (see Phase 4d) *(→ deferred to Alpha 0.2)*
- [x] Success/error summary report

##### Phase 6c — Bulk export (account-level) (complete)
- [x] Bulk export UI on Data screen: set list with checkboxes + select-all
- [x] Multi-set ZIP format: `{ "version": "1.0", "exportDate": "...", "sets": [...] }`
- [x] Shared `media/` folder across all sets in the archive (no duplication)
- [x] Add unit tests for validation and diff logic *(covered in Phase 7 unit-tests pass)*
- [ ] Test full round-trip (export → import → verify data integrity) (deferred — requires Firebase emulator setup) *(→ deferred to Alpha 0.2)*

##### Phase 6d — Template export/import (complete)
- [x] Export includes all user Card Templates and Question Templates as top-level `cardTemplates`/`questionTemplates` arrays in `cards.json` (both single-set and bulk export)
- [x] Templates fetched directly from repositories at export time (not from cached stream state)
- [x] Import analyze: parses templates from JSON root; deduplicates against DB (QT by Import ID then name, CT by name); JSON-defined QTs added to `##templateId` lookup map so cards in the same file can reference them before they exist in Firestore
- [x] Import execute: creates new Question Templates before Card Templates before cards
- [x] Import preview: collapsible Templates section shows new card and question templates (name, type, Import ID) above the per-set diffs
- [x] Import summary: counts card and question templates created
- [x] Template providers invalidated after import so Templates screen reflects new templates immediately

**Deliverable**: Account-level Data screen with bulk import/export; full round-trip for single and multi-set ZIPs covering all field types and media.

---

### Phase 7: Polish, Testing & Optimization (Weeks 9-10)

**Goal**: Refine UX, ensure stability, and optimize performance.

**Dependencies**: All previous phases

**Priority**: High - Ensures quality release.

#### Tasks

##### Phase 7c — Study tab & study modes (complete)
- [x] Add Study tab to bottom nav (centre position: Sets | Cards | Study | Templates | Profile); icon: `Icons.school`
- [x] `StudyScreen` — mode card list: "Study a Set" (enabled), "Study Review" + "Study Mistakes" (disabled, "Soon" badge)
- [x] Set-picker bottom sheet (`DraggableScrollableSheet`) on "Study a Set" tap; shows name, card count, colour accent; tapping a set navigates to `StudySetupScreen`
- [x] Remove Study FAB from `SetDetailScreen`; replace with play-circle AppBar icon as a quick shortcut

##### Phase 7a — Study flow enhancements (complete)
- [x] Three-phase card reveal: tap word → translation fades in with MORE / NEXT buttons; MORE expands full card; mark buttons activate only after MORE
- [x] Rename Know / Don't Know → **Skip / Review** throughout (study screen, summary screen, strings)
- [x] Skip / Review icons: Skip = check-circle (amber), Review = flag (green)
- [x] `users/{uid}/cardMarks/{cardId}` Firestore subcollection — durable cross-session card marks; fire-and-forget upsert preserving original `markedAt`
- [x] Question result tracking — rolling 5-result window (`success` / `fail` / `unseen`, newest-first) stored at `users/{uid}/questionResults/{cardId}_{fieldId}`; tracked for `text_input` and `multiple_choice` fields; `reveal` fields excluded
- [x] `QuestionResultRepository` + `FirebaseQuestionResultRepository`; prefix range query for per-card lookup without a composite index
- [x] Deploy updated Firestore rules for `cardMarks` and `questionResults` subcollections

##### Phase 7b — Language pair on cards and sets (complete)
- [x] Add `nativeLanguage` + `targetLanguage` (ISO 639-1 string, nullable) to `FlashCard` and `CardSet` models, Firestore serialization, and JSON export
- [x] `lib/utils/languages.dart` — curated list of 74 ISO 639-1 languages (`kLanguages`) + `languageName(code)` lookup
- [x] `LanguagePicker` widget — searchable bottom sheet (`DraggableScrollableSheet`) with autofocus search field filtering by name or code; current selection highlighted; "Not set" always pinned at top
- [x] Language pickers added to `CardFormScreen` and `SetFormScreen`
- [x] Default language inheritance: card created inside a set inherits set's language pair; card created in the Cards section inherits from `lastUsedLanguagesProvider` (last card saved this session)
- [x] One-shot admin script (`scripts/seed_languages.js`) to back-fill language fields on existing Firestore documents

##### UI/UX Polish
- [x] Review all screens for visual consistency
- [x] Improve error messages and user feedback
- [x] Add loading states and spinners
- [x] Implement smooth animations and transitions
- [ ] Ensure responsive design on all screen sizes *(→ deferred to Alpha 0.2 — widescreen layout owned by the Web Dashboard phase; see Beta 0.1)*
- [ ] Test on various device sizes (phones, tablets, desktops) *(→ deferred to Alpha 0.2 — tablet/desktop testing blocked on Web Dashboard phase)*

##### Comprehensive Testing
- [x] Unit tests for models (`CardField`, `FlashCard`, `ImportSetDiff`, `ImportAnalysis`) and import service logic (`_parseCard`, `_buildChanges`, `_fieldsChanged`, new-card routing) — 47 tests, all passing
- [ ] Widget/UI tests for all screens *(→ deferred to Alpha 0.2 — lower ROI at this stage; revisit once screens stabilise)*
- [ ] Integration tests for core workflows *(→ deferred to Alpha 0.2 — requires Firebase Local Emulator Suite)*
- [ ] Cross-platform testing (iOS, Android, Web, Windows, macOS, Linux) *(→ deferred to Alpha 0.2 — desktop/web testing blocked on Web Dashboard phase)*
- [ ] Test on real devices and emulators *(→ deferred to Alpha 0.2 — covered by manual QA during feature development)*
- [ ] Performance testing and optimization *(→ deferred to Alpha 0.2 — post-launch once usage patterns are known)*
- [ ] Memory leak detection and fixing *(→ deferred to Alpha 0.2)*
- [ ] Battery usage optimization (for mobile) *(→ deferred to Alpha 0.2)*

##### Phase 7d — Accessibility & Localization
- [x] Audit for accessibility issues (colour contrast, touch target sizes, semantic labels on custom widgets)
- [x] Dark mode: audit for hardcoded colours that break in dark theme; add dark mode toggle to ProfileScreen (persisted to device preferences)
- [ ] Add screen reader support (`Semantics` labels on custom widgets; smoke-test core flows with TalkBack/VoiceOver) *(→ deferred to Alpha 0.2)*
- [ ] Test with accessibility tools *(→ deferred to Alpha 0.2)*
- [ ] Add text size adjustment controls *(→ deferred to Alpha 0.2 — Flutter respects system text scale by default; revisit if issues found)*
- [ ] Implement high contrast mode *(→ deferred to Alpha 0.2)*
- [ ] Prepare for localization (structure for multiple languages) *(→ deferred to Alpha 0.2 — no second language planned for MVP)*

##### Documentation
- [ ] Create user documentation/help *(→ deferred to Alpha 0.2)*
- [ ] Document API endpoints and data structures *(→ deferred to Alpha 0.2)*
- [ ] Create developer setup guide *(→ deferred to Alpha 0.2)*
- [ ] Add code comments and documentation *(→ deferred to Alpha 0.2)*
- [ ] Create architecture documentation *(→ deferred to Alpha 0.2)*

##### Deployment Preparation
- [ ] Set up CI/CD pipeline *(→ deferred to Alpha 0.2)*
- [ ] Configure build and signing certificates (iOS, Android) *(→ deferred to Alpha 0.2)*
- [ ] Set up app store deployment process *(→ deferred to Alpha 0.2)*
- [ ] Create release notes template *(→ deferred to Alpha 0.2)*
- [ ] Set up analytics/crash reporting (Firebase Crashlytics) *(→ deferred to Alpha 0.2)*
- [ ] Set up user feedback mechanism *(→ deferred to Alpha 0.2)*

**Deliverable**: Production-ready application.

---

## Alpha 0.2 — Completeness & Polish

Items deferred from Alpha 0.1, grouped by theme. All are prerequisites for a public release or are technically blocked on other work in this block (e.g. Phase 4c requires Phase 4d).

### Known Defects
- [x] Display Skip / Review indication on card revisit — when navigating back to a card already marked in this session, the current mark (skip/review) is not shown on the card
- [ ] "More" button visible on flash cards with no questions — should be hidden (or disabled) when `card.questions` is empty, so only "Next" shows

### Auth & Account
- [ ] Implement account linking logic for multiple auth providers
- [ ] Test both registration flows (local and Google) on all platforms

### Data Layer
- [ ] Create validation logic for all models
- [ ] Test Firestore operations with integration tests (requires Firebase emulator setup)

### Field / Question Model Unification

**Goal:** Replace the separate `CardField` (flash cards) and `WorkbookQuestion` (workbook cards) models with a single unified question model, used by both card types and their templates.

**Decisions:**

| Topic | Decision |
|---|---|
| Card types | Kept separate (`flashcard` \| `workbook`); only the question model is unified |
| Base model | WorkbookQuestion subtypes — more capable, adopted as the canonical form |
| `reveal` question type | Deleted entirely — no trackable outcome, fully covered by the Flash Card primary field |
| Template answers | Single hierarchy with nullable answers (`correctAnswers: List<String>?`, `correctIndex: int?`, `correctOrder: List<String>?`); configuration fields (options, wordBank, hint, displayMode) remain non-nullable |
| Session answer tracking | Remove `textInputAnswers`, `multipleChoiceAnswers`, `revealedFields` from `CardSessionData`; all outcome tracking via `questionResults` subcollection (already in use for workbook cards) |
| Identifier | `questionId` (replaces `fieldId`) |
| Label | `prompt` (replaces `name`) |

**Note on `CardSessionData` simplification:** `textInputAnswers`, `multipleChoiceAnswers`, and `revealedFields` are currently write-only — the study screen never reads them back to restore widget state. Removing them has no visible UI impact. Existing Firestore session documents retain these fields but `fromJson` ignores unknown keys; no session migration needed.

#### Step 1 — Unified question model (data layer) ✅
- [x] Rename `WorkbookQuestion` → `CardQuestion`; rename `questionId` field (already correct); rename `prompt` field (already correct on workbook side)
- [x] Make answer fields nullable on all three subtypes to support templates: `correctAnswers: List<String>?`, `correctIndex: int?`, `correctOrder: List<String>?`
- [x] Add `WordOrderQuestion` to the flash card field type set (flash cards can now include word-order questions)
- [x] Remove `CardField`, `CardFieldContent`, `RevealContent`, `TextInputContent`, `MultipleChoiceContent` — replaced by `CardQuestion` subtypes
- [x] Update `FlashCard` model: replace `fields: List<CardField>` with `questions: List<CardQuestion>`
- [x] Update `CardTemplate` model: replace `fields: List<CardField>` with `questions: List<CardQuestion>`
- [x] Update `fromFirestore` / `toFirestore` / `fromJson` / `toJson` on `FlashCard` and `CardTemplate`
- [x] Simplify `CardSessionData`: remove `revealedFields`, `textInputAnswers`, `multipleChoiceAnswers`; update `fromJson`/`toJson`
- [x] Update `FirebaseCardRepository` writes to use `questions` key

#### Step 2 — Firestore data migration ✅
- [x] Migration script: for each doc in `cards/`, rename `fields` → `questions`; within each question rename `fieldId` → `questionId`, `name` → `prompt`; delete any questions with `type == 'reveal'`
- [x] Migration script: for each doc in `templates/`, same field renames and reveal removal
- [x] Deploy and verify; no session migration needed (unknown keys ignored by `fromJson`)

#### Step 3 — Card form UI ✅
- [x] Replace `CardFormScreen` field editors with unified `CardQuestion` editors
- [x] Remove reveal field editor and "Add Reveal Field" option
- [x] Update `TemplateFormScreen` similarly
- [x] Update "Save as Template" flow to null out answer fields on the unified type

#### Step 4 — Study screen ✅
- [x] Replace flash card `_buildField` / `_RevealFieldCard` / `_TextInputFieldCard` / `_MultipleChoiceFieldCard` with unified `_buildQuestion` / workbook question widgets
- [x] Remove `_RevealFieldCard` entirely
- [x] Unified `_recordQuestionResult` covers both flash card and workbook card questions
- [x] Flash card `_PrimaryFieldCard` and two-phase word reveal unchanged

#### Step 5 — Import / export ✅
- [x] Update `ExportService` to serialise `questions` (unified type) instead of `fields`
- [x] `ImportService` handles both old (`fields`) and new (`questions`) ZIP formats
- [x] Import validation updated for unified question types

#### Step 6 — Question templates (new feature, depends on Steps 1–3) ✅
- [x] `QuestionTemplate` Firestore collection (`questionTemplates/{templateId}`): `createdBy`, `name`, `description`, `question: CardQuestion` (single question, answers nullable)
- [x] `QuestionTemplateRepository` + `FirebaseQuestionTemplateRepository`
- [x] `questionTemplateRepositoryProvider`, `userQuestionTemplatesProvider`
- [x] Question template picker in `CardFormScreen` — two-tab bottom sheet (Card Templates / Question Templates); selecting a question template appends without replacing
- [x] "Use Template" button in `TemplateFormScreen` — opens question template picker, appends to template questions
- [x] Create / edit / delete question templates from the Question Templates tab in the Templates screen
- [x] Firestore security rules for `questionTemplates/`
- [x] Optional Import ID (`templateId`) field on `QuestionTemplate` — user-defined slug (alphanumeric/hyphen/underscore), unique per user; validated and checked for uniqueness on save in `QuestionTemplateFormScreen`
- [x] Import shorthand: `{"template": "##id", "correctIndex": N}` — importer resolves `##id` references at parse time, merging template structure with answer-field overrides; unknown references fail immediately with a descriptive error
- [x] `QuestionTemplateRepository.getUserTemplates()` — one-shot future for import-time lookup
- [x] Trailing commas tolerated in hand-authored `cards.json` files
- [x] Fix: `cardsInSetProvider` invalidated after import so updated card data (questions, `correctIndex`) is visible immediately in study mode without requiring a full app restart

### Cards & Templates
- [ ] Add card metadata display (createdAt, updatedAt, createdBy)
- [ ] Implement field type icons/indicators
- [ ] Add field randomization for multiple choice
- [ ] Create default/example templates
- [ ] Bulk card creation via JSON import (keyboard-focused grid UI — see Web Dashboard in Beta 0.1)

### Global Tag System (Phase 4d)

**Design summary:** Tags stored in `tags/{normalizedName}` (global, shared across users). Document ID is the normalized tag. `usageCount` maintained on add/remove. Autocomplete queries with a prefix filter. Full design in [docs/design.md — Tag System](design.md#tag-system).

#### 4d-1 — Firestore Infrastructure ✅
- [x] Deploy `tags` collection security rules (read: any authed user; create: authed + `usageCount=1` constraint; update: count-only, `displayName`/`createdBy`/`normalizedName` immutable; delete: never)
- [x] Deploy Firestore indexes: `normalizedName ASC` (prefix queries), `usageCount DESC` (popularity), composite `(createdBy, tags[])` on `cards`, composite `(userId, tags[])` on `sets`

#### 4d-2 — Data Layer ✅
- [x] Implement `normalizeTag(String input) → String` utility in `AppHelpers`
- [x] Implement `TagRepository` abstract interface: `upsertTag`, `decrementTag`, `searchTags(prefix)`
- [x] Implement `FirebaseTagRepository`
- [x] Add `tagRepositoryProvider` and `tagSearchProvider.family` to provider layer

#### 4d-3 — Content Lifecycle Hooks ✅
- [x] Card create/edit: diff old vs new tags → upsert added, decrement removed
- [x] Set create/edit: same
- [x] Card delete: decrement all tags on the card
- [x] Set delete: decrement all tags on the set
- [x] Import: upsert every tag on new cards; diff tags on updated cards

#### 4d-4 — TagInputField Widget ✅
- [x] Build shared `TagInputField`: debounced autocomplete (~300ms), chip display, comma-paste, Enter-to-create, `usageCount >= 2` threshold (own tags always shown)
- [x] Replace chip-input on `CardFormScreen` with `TagInputField`
- [x] Replace chip-input on `SetFormScreen` with `TagInputField`
- [x] Replace chip-input on `WorkbookCardFormScreen` + add the 4d-3 lifecycle hooks it was missing (folded in for consistency)

#### 4d-5 — Search & Filter (Phase 4c) ✅
- [x] Tag filter on My Cards screen (search bar already stubbed)
- [x] Tag filter on My Sets screen
- [x] Name search on My Cards and My Sets screens
- [x] Sort options (name, last updated, card count) on sets

### Study Enhancements
- [ ] Set summary results improvement — richer breakdown on the session summary screen (e.g. per-field question results, time-per-card)

### Advanced Study Features
- [ ] Offline support with local caching
- [ ] Haptic feedback for answer results
- [ ] Keyboard shortcuts (arrow keys, Enter) for desktop
- [ ] Card preloading for smooth performance

### Import/Export
- [ ] CSV → card import (development / bulk-seeding tool; not user-facing)
- [ ] Run tag upsert for every imported tag
- [ ] Test full round-trip (export → import → verify data integrity) (requires Firebase emulator setup)

### Responsive Design & Device Testing
- [ ] Ensure responsive design on all screen sizes (widescreen layout; co-ordinate with Web Dashboard in Beta 0.1)
- [ ] Test on various device sizes (phones, tablets, desktops)

### Testing Infrastructure
- [ ] Widget/UI tests for all screens
- [ ] Integration tests for core workflows (requires Firebase Local Emulator Suite)
- [ ] Cross-platform testing (iOS, Android, Web, Windows, macOS, Linux)
- [ ] Test on real devices and emulators
- [ ] Performance testing and optimization
- [ ] Memory leak detection and fixing
- [ ] Battery usage optimization (mobile)

### Accessibility & Localization
- [ ] Add screen reader support (`Semantics` labels on custom widgets; smoke-test with TalkBack/VoiceOver)
- [ ] Test with accessibility tools
- [ ] Add text size adjustment controls
- [ ] Implement high contrast mode
- [ ] Prepare for localization (structure for multiple languages)

### Documentation
- [ ] Create user documentation/help
- [ ] Document API endpoints and data structures
- [ ] Create developer setup guide
- [ ] Add code comments and documentation
- [ ] Create architecture documentation

### Deployment Preparation
- [ ] Set up CI/CD pipeline
- [ ] Configure build and signing certificates (iOS, Android)
- [ ] Set up app store deployment process
- [ ] Create release notes template
- [ ] Set up analytics/crash reporting (Firebase Crashlytics)
- [ ] Set up user feedback mechanism

---

## Beta 0.1 — Marketplace & Platform

These features are important but deferred to post-Alpha-launch:

### Marketplace & Lessons

> **See [docs/design.md — Marketplace & Lessons](design.md#marketplace--lessons--long-term-vision) for full pre-design notes.**

The long-term vision for Flash Me is a content marketplace where users can publish sets and lessons for others to discover, study, and build upon. Key planned capabilities:

- **Published Sets** — owners mark sets as public; non-owners can browse, subscribe, or clone
- **Lessons** — a new content type: an ordered grouping of sets forming a structured learning curriculum (analogous to a course chapter). Requires its own data model, creation UI, and study flow.
- **Marketplace Discovery** — browse by tag (global tag system), search by name/description (requires external full-text search service: Algolia, Typesense, or Firebase Search Extension), sort by popularity/recency
- **Subscriptions** — user's library includes subscribed sets; receives updates when owner edits
- **Cloning** — user gets an independent editable copy; clone provenance recorded for attribution
- **Creator Tools** — view counts, subscriber counts, clone counts for publishers
- **Content Moderation** — flagging, takedowns, abuse prevention (required before public launch)

**Architectural decisions already made in support of this:**
- Global normalized tag system (Alpha 0.2) — tags converge across users for marketplace search
- `isPublic` field reserved on `CardSet`
- `createdBy` on all content types for attribution
- `setCards` join collection supports future subscription patterns

**Implementation phasing (future):**
1. Marketplace Alpha — publish/unpublish; tag + popularity browsing; subscribe + clone
2. Marketplace Beta — ratings, reviews, moderation
3. Lessons — data model, creation UI, lesson-level study flow
4. Creator Analytics & optional monetization design

### Sharing & Community
- [ ] Set subscriptions (see Marketplace above)
- [ ] Set cloning (see Marketplace above)
- [ ] User profiles and profile management
- [ ] Social features (ratings, reviews, followers)

### Advanced Study Features
- [ ] Spaced repetition algorithm
- [ ] Adaptive difficulty
- [ ] Study statistics and learning graphs
- [ ] Recommended study sessions
- [ ] Flashcard mastery levels

### Data Features
- [ ] Quizlet import
- [ ] Bulk export to other formats
- [ ] Cloud backup/restore
- [ ] Automatic scheduled backups

### Mobile-Specific
- [ ] Native notifications for study reminders
- [ ] Home screen widgets (study progress)
- [ ] Shortcuts/voice commands

### Desktop-Specific
- [ ] Keyboard-centric UI modes
- [ ] Window management enhancements
- [ ] Drag-and-drop improvements

### Deferred Animation Work (from Phase 7 polish pass)
- [ ] Staggered list-item entrance animations on Sets, Cards, and Templates screens (first-load fade-in per item)
- [ ] Animated add/remove for dynamic fields in CardFormScreen and TemplateFormScreen (`AnimatedList` refactor)

### Web Dashboard — Bulk Card Creation & Desktop Experience

> **Full design: [docs/design.md — Web Dashboard](design.md#web-dashboard--bulk-card-creation--desktop-experience)**

This phase establishes the desktop layout conventions for the whole app (responsive shell, NavigationDrawer, content max-width) and delivers a keyboard-focused bulk card creation interface for teachers and content creators.

**Why deferred:** Widescreen layout decisions are made here once, correctly, rather than retrofitted during Alpha 0.1 mobile polish.

#### Dashboard Alpha
- [ ] Responsive shell: swap `BottomNavigationBar` → persistent `NavigationDrawer` above a screen-width breakpoint; establish content max-width constraints app-wide
- [ ] Bulk card editor: template-driven grid (one row per card, columns match template fields), keyboard Tab/Enter navigation, batch Firestore write on save
- [ ] Set assignment on save — choose or create target set before committing

#### Dashboard Beta
- [ ] Inline per-cell field validation
- [ ] Undo/redo, duplicate row, reorder rows

#### Master-detail layouts
- [ ] Set detail split-pane (card list + card preview/edit panel)
- [ ] Cards screen list + form panel

#### Advanced creator tools
- [ ] CSV paste with column mapping
- [ ] Bulk tag assignment

---

## Development Timeline Summary

| Block / Phase | Duration | Focus |
|---|---|---|
| **Alpha 0.1** | | |
| Phase 1: Setup & Auth | 2 weeks | Foundation |
| Phase 2: Data Layer | 1 week | Infrastructure |
| Phase 3: Cards & Templates | 2 weeks | Data entry |
| Phase 4: Card Sets | 1 week | Organization |
| Phase 5: Study Mode | 2 weeks | Core feature |
| Phase 6: Import/Export | 1 week | Data portability |
| Phase 7: Polish & Test | 1 week | Quality |
| **Alpha 0.1 Total** | **10 weeks** | **Launchable app** |
| — | — | — |
| **Alpha 0.2** | | |
| Global Tag System (4d) | 1 week | Search foundation |
| Search & Filter (4c) | 1 week | Discovery (needs 4d) |
| Testing infrastructure | 1 week | Firebase emulator + coverage |
| Deployment prep + docs | 1 week | Store release |
| **Alpha 0.2 Total** | **~4 weeks** | **Public release ready** |
| — | — | — |
| **Beta 0.1** | | |
| Web Dashboard Alpha | TBD | Desktop layout + bulk card creation |
| Web Dashboard Beta+ | TBD | Master-detail, advanced creator tools |
| Marketplace Alpha | TBD | Content sharing (long-term) |

---

## Implementation Priorities

**Must Have (MVP):**
- ✅ Authentication (local + Google)
- ✅ Card creation and management
- ✅ Card templates
- ✅ Card sets organization
- ✅ Study mode with all field types
- ✅ Session tracking and statistics
- ✅ Import/Export (JSON)

**Should Have (Alpha 0.2):**
- ⭐ Global tag system + search/filter (Phase 4c/4d)
- ⭐ Testing infrastructure (Firebase emulator, widget tests)
- ⭐ Deployment preparation (CI/CD, app store, signing)
- ⭐ Accessibility (screen reader, high contrast)
- ⭐ Offline support

**Nice to Have (Alpha 0.2 / Beta 0.1):**
- ⭐ Spaced repetition
- ⭐ Advanced analytics
- ⭐ Localization
- ⭐ Responsive/desktop layout (Web Dashboard)

**Long-Term (Beta 0.1 Marketplace):**
- 🌐 Published sets & marketplace discovery
- 🌐 Lessons (structured set groupings)
- 🌐 Set subscriptions & cloning
- 🌐 Creator tools & content moderation

---

## Dependencies & Critical Path

**Critical Path** (longest sequence of dependent tasks):
1. Phase 1: Authentication
2. Phase 2: Data models
3. Phase 3: Cards & Templates
4. Phase 4: Card Sets
5. Phase 5: Study Mode (the core value delivery)

**Parallel Work** (can be done while other phases progress):
- Some Phase 6 (Import/Export) can be started once Phase 2-3 are complete
- Phase 7 (Testing) can begin after Phase 5
- Alpha 0.2 Global Tag System unblocks Phase 4c Search & Filter

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Firebase integration complexity | Allocate buffer time in Phase 1, thorough testing |
| Performance with large card sets | Profile early, optimize Firestore queries, implement pagination |
| Cross-platform issues | Test on real devices early and often |
| Complex study state management | Consider state management library (Riverpod), test thoroughly |
| User data loss | Implement robust error handling, backup/recovery mechanisms |
| Scope creep | Stick to MVP features, defer "Nice to Have" items |

---

## Success Criteria

- ✅ All MVP features implemented and tested
- ✅ App runs smoothly on all target platforms
- ✅ Study mode is stable and performant
- ✅ User can import/export without data loss
- ✅ Authentication is secure
- ✅ Code is well-tested (>80% coverage for core features)
- ✅ App is accessible (WCAG AA compliance)
