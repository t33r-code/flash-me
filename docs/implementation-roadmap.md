# Flash Me - Implementation Roadmap

This document outlines the phased implementation approach for the Flash Me application, organized by logical dependencies and development priorities.

## Overview

The implementation is divided into 7 phases, starting with foundational setup and progressing through core features to polish and optimization. Each phase includes specific tasks extracted from the design document.

## Phase 1: Project Setup & Authentication (Weeks 1-2)

**Goal**: Establish project foundation and user authentication system.

**Priority**: Critical - All other features depend on this.

### Tasks
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
- [ ] Implement account linking logic for multiple auth providers
- [x] Set up Firestore collection schema for user profiles (`users/{userId}`)
- [x] Create Firestore user document on successful registration
- [x] Implement auto-login after registration
- [x] Implement logout functionality
- [x] Implement session persistence (keep user logged in across app restarts)
- [x] Add error handling for auth failures (invalid email, weak password, etc.)
- [x] Set up Firebase security rules for user data access
- [x] Implement password reset flow (forgot password screen + sendPasswordResetEmail())
- [x] Implement user profile management screen (view/edit displayName, photoURL)
- [ ] Test both registration flows (local and Google) on all platforms
- [x] Create authentication state provider (using Provider/Riverpod)

**Deliverable**: Working registration and login system on all platforms.

---

## Phase 2: Core Data Models & Database Schema (Weeks 2-3)

**Goal**: Establish data structures and backend infrastructure.

**Dependencies**: Phase 1 (need authenticated user)

**Priority**: Critical - Foundation for all feature development.

### Tasks
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
- [ ] Create validation logic for all models (deferred to Phase 3 with UI)
- [x] Test data models with unit tests *(covered in Phase 7 unit-tests pass)*
- [ ] Test Firestore operations with integration tests (deferred — requires Firebase emulator setup)

**Deliverable**: Complete data layer with working Firestore integration.

---

## Phase 3: Card Templates & Card Management (Weeks 3-5)

**Goal**: Enable users to create card templates and manage individual cards.

**Dependencies**: Phase 2 (need data layer)

**Priority**: High - Core data entry functionality.

### Tasks

#### Phase 3a — Navigation shell + My Cards screen (complete)
- [x] Add `tags: List<String>` to FlashCard model (user-defined labels for search/filter)
- [x] Replace HomeScreen routing with MainScreen (BottomNavigationBar shell)
- [x] Bottom nav: Sets / Cards / Templates / Profile tabs (IndexedStack, mobile-first)
- [x] My Cards screen: card list from userCardsProvider, empty state, search bar stub, tag filter stub
- [x] Templates screen: placeholder (full UI in Phase 3c)
- [x] Remove stale profile-button from HomeScreen AppBar (Profile is now a tab)
- [x] Remove pop-back auth listener from ProfileScreen (main.dart handles it)

#### Phase 3b — Card creation / edit / delete (complete)
- [x] Card creation form: primaryWord, translation, tags, add/remove additional fields
- [x] Support all three field types in the form (reveal, text_input, multiple_choice)
- [x] Card edit screen (same CardFormScreen, pre-populated from existing card)
- [x] Card deletion with confirmation dialog (AppBar delete icon, edit mode only)
- [x] Wire My Cards FAB → create form; card list tap → edit form

#### Phase 3c — Templates (complete)
- [x] TemplateFormScreen: create/edit template (name, description, primaryWordHidden flag)
- [x] Dynamic field builder — same three field types as cards but answer-free
  - Reveal: structure only (answer filled per card)
  - Text input: hint + exact-match toggle (no correct answers)
  - Multiple choice: pre-fillable options list (no correct index)
- [x] TemplatesScreen: live list from userTemplatesProvider, empty state, FAB → create from scratch
- [x] Template edit and delete (with confirmation dialog)
- [x] "Save as Template" overflow menu on CardFormScreen — nulls out answers,
      pre-populates TemplateFormScreen with the card's field structure

#### Phase 3d — Card from template (complete)
- [x] "Use Template" button in Additional Fields section of CardFormScreen
- [x] Bottom sheet template picker listing user's templates
- [x] Applying a template pre-populates fields (config carried over, answers blank)
- [x] Confirmation dialog when replacing existing fields

#### Flash Cards (remaining / deferred)
- [ ] Add card metadata display (createdAt, updatedAt, createdBy)
- [ ] Implement field type icons/indicators
- [ ] Add field randomization for multiple choice (optional)
- [ ] Create default/example templates
- [ ] Implement bulk card creation via JSON import (Phase 6)

**Deliverable**: Full CRUD for templates and cards, with working field types.

---

## Phase 4: Card Sets Management (Weeks 5-6)

**Goal**: Enable users to organize cards into sets and manage membership.

**Dependencies**: Phase 3 (need cards to organize)

**Priority**: High - Core organizational feature.

### Tasks

#### Phase 4a — My Sets screen + set CRUD (complete)
- [x] Fix Firestore list-rule violations in CardSetRepository (add userId constraint to all setCards queries)
- [x] MySetsScreen: live list from userSetsProvider, empty state, colour accent bar, tags, relative date
- [x] SetFormScreen: create/edit a set (name, description, colour picker, tags)
- [x] Set deletion with confirmation (cleans up all setCards links)
- [x] SetDetailScreen: placeholder showing card count; edit button → SetFormScreen
- [x] Wire MySetsScreen into the main nav shell (replaces HomeScreen placeholder)

#### Phase 4b — Set detail + card membership (complete)
- [x] Full card list in SetDetailScreen (live via cardsInSetProvider)
- [x] Add cards to set — DraggableScrollableSheet picker with multi-select checkboxes; already-in-set cards shown greyed at the bottom
- [x] Remove card from set — swipe-left Dismissible on each card row
- [x] setByIdProvider — keeps AppBar title in sync after editing set metadata
- [x] Update Firestore indexes: setCards composite indexes now include userId (required by ordered queries with the security rule constraint)

#### Phase 4c — Search & filter (deferred, depends on Phase 4d)
- [ ] Search sets by name
- [ ] Filter sets by tag (requires global tag system from Phase 4d)
- [ ] Sort options (by name, last updated, card count)
- [ ] Search / filter within set detail view
- [ ] Search / filter on My Cards screen (search bar is already stubbed)

#### Phase 4d — Global Tag System (deferred to after Phase 5)

**Rationale for deferral:** Tag infrastructure is a prerequisite for Phase 4c (tag-based filtering) and for the long-term marketplace feature, but does not block Phase 5 (Study Mode). Implementing it after Phase 5 allows Study Mode — the core value proposition — to ship sooner while the tag system is built correctly without time pressure.

**Design summary:** Tags are stored in a global Firestore collection (`tags/{normalizedName}`) shared across all users. The document ID is the normalized form of the tag (lowercase, trimmed, spaces collapsed to hyphens). A `usageCount` field is maintained as tags are added/removed across all content types. The autocomplete widget queries this collection with a prefix filter. Full design in [docs/design.md — Tag System](design.md#tag-system).

- [ ] Create `tags` Firestore collection; deploy security rules (read: any authed user; create/update: authed user with constraints; delete: never)
- [ ] Add Firestore indexes for prefix queries (`normalizedName ASC`) and array-contains tag filters on `cards` and `sets`
- [ ] Implement `normalizeTag(String input) → String` utility in `AppHelpers`
- [ ] Implement `TagRepository` abstract interface with: `upsertTag`, `decrementTag`, `searchTags(prefix)`
- [ ] Implement `FirebaseTagRepository`
- [ ] Add `tagRepositoryProvider` and `tagSearchProvider.family` to provider layer
- [ ] Build shared `TagInputField` widget: debounced autocomplete, chip display, comma-paste, Enter-to-create
- [ ] Replace current chip-input on `CardFormScreen` with `TagInputField`
- [ ] Replace current chip-input on `SetFormScreen` with `TagInputField`
- [ ] Update card save/edit to diff old vs new tags and call upsert/decrement accordingly
- [ ] Update set save/edit to diff old vs new tags similarly
- [ ] Update card delete to decrement all tags on the deleted card
- [ ] Update set delete to decrement all tags on the deleted set
- [ ] Update import flow (Phase 6) to run upsert for every imported tag
- [ ] Deploy updated Firestore rules and indexes
- [ ] Wire tag filter into Phase 4c (My Cards and My Sets screens)

**Deliverable**: Complete set management with card organization.

---

## Phase 5: Study Mode - The Core Experience (Weeks 6-8)

**Goal**: Implement the primary user interaction - studying cards with full session tracking.

**Dependencies**: Phase 4 (need sets to study)

**Priority**: Critical - This is the core value proposition.

### Tasks

#### Phase 5a — Session infrastructure + session selection UI (complete)
- [x] Confirm StudySession + CardSessionData data models and Firestore schema (already in Phase 2)
- [x] Implement study session repository (FirebaseStudySessionRepository)
- [x] Wire studySessionRepositoryProvider and sessionHistoryProvider
- [x] Study set selection UI: tap a set → prompt "Resume" vs "Start New Session" when an active session exists
- [x] Session configuration screen: shuffle toggle, (future: card filters)
- [x] Session initialization: build card sequence (ordered or shuffled), write session document to Firestore
- [x] Card shuffling option (Fisher-Yates on the card sequence)

#### Phase 5b — Card display & field interaction (complete)
- [x] Build study session screen scaffold (AppBar with progress + exit, card area, control row)
- [x] Primary field: show `primaryWord` (and image/audio if present); tap to reveal `translation`
- [x] Respect `primaryWordHidden` flag — hide word until "Show Word" is tapped when set
- [x] Reveal-on-click fields: prompt label + tap-to-reveal answer
- [x] Text input fields: text field + submit; case-insensitive validation; respect `exactMatch` flag; correct/incorrect feedback
- [x] Multiple choice fields: option buttons; highlight correct/incorrect on selection
- [x] "Try Again" button to re-attempt a field after a wrong answer
- [x] Feedback messaging (correct, incorrect, partial) with visual distinction

#### Phase 5c — Session controls, navigation & persistence (complete)
- [x] Navigation controls: Previous / Next buttons; Know / Don't Know marking
- [x] Progress indicator: "Card X of Y" label + linear progress bar
- [x] Card marking: known/unknown toggles with visual indicator per card
- [x] Boundary checks: disable Previous on first card, Next on last card
- [x] Card session state tracking: record per-card attempts, result, and timestamp
- [x] Auto-save to Firestore after each navigation action (debounced ~1 s to reduce write volume)
- [x] Session pause: write current state and navigate back; session stays in "active" status
- [x] Session resume: restore card sequence, current index, and all per-card state from Firestore
- [x] Session completion: mark status "completed", calculate and write SessionStats (total, known, unknown, duration)

#### Phase 5d — Session summary & history (complete)
- [x] Session summary screen: shown on completion; display stats (cards studied, known %, time, date)
- [x] "Study Again" and "Done" actions on summary screen
- [x] Session history list: per-set list of past sessions from sessionHistoryProvider
- [x] Session history entry: date, duration, known/unknown counts, completion status

#### Advanced features (deferred)
- [ ] Offline support with local caching
- [ ] Haptic feedback for answer results
- [ ] Keyboard shortcuts (arrow keys, Enter) for desktop
- [ ] Card preloading for smooth performance

**Deliverable**: Fully functional study mode with session tracking and statistics.

---

## Phase 6: Import/Export (Weeks 8-9)

**Goal**: Enable users to bulk-create cards, share sets, and back up their data via JSON + ZIP.

**Dependencies**: Phase 4 (need sets to export), Phase 3 (need cards)

**Priority**: Medium - Important for data portability and bulk card creation.

### Tasks

#### Phase 6a — Export (complete)
- [x] Implement Firestore export function (retrieve full set + card data)
- [x] Build ZIP archive: write `cards.json` with relative `media/` paths, download media from Firebase Storage
- [x] Add export metadata to `cards.json` (version, exportDate)
- [x] Create export UI (trigger from set detail screen)
- [x] Implement file download / share sheet

#### Phase 6b — Import (account-level) (complete)
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
- [ ] Run tag upsert for every imported tag (see Phase 4d)
- [x] Success/error summary report

#### Phase 6c — Bulk export (account-level) (complete)
- [x] Bulk export UI on Data screen: set list with checkboxes + select-all
- [x] Multi-set ZIP format: `{ "version": "1.0", "exportDate": "...", "sets": [...] }`
- [x] Shared `media/` folder across all sets in the archive (no duplication)
- [x] Add unit tests for validation and diff logic *(covered in Phase 7 unit-tests pass)*
- [ ] Test full round-trip (export → import → verify data integrity) (deferred — requires Firebase emulator setup)

**Deliverable**: Account-level Data screen with bulk import/export; full round-trip for single and multi-set ZIPs covering all field types and media.

---

## Phase 7: Polish, Testing & Optimization (Weeks 9-10)

**Goal**: Refine UX, ensure stability, and optimize performance.

**Dependencies**: All previous phases

**Priority**: High - Ensures quality release.

### Tasks

#### Phase 7c — Study tab & study modes (complete)
- [x] Add Study tab to bottom nav (centre position: Sets | Cards | Study | Templates | Profile); icon: `Icons.school`
- [x] `StudyScreen` — mode card list: "Study a Set" (enabled), "Study Review" + "Study Mistakes" (disabled, "Soon" badge)
- [x] Set-picker bottom sheet (`DraggableScrollableSheet`) on "Study a Set" tap; shows name, card count, colour accent; tapping a set navigates to `StudySetupScreen`
- [x] Remove Study FAB from `SetDetailScreen`; replace with play-circle AppBar icon as a quick shortcut

#### Phase 7a — Study flow enhancements (complete)
- [x] Three-phase card reveal: tap word → translation fades in with MORE / NEXT buttons; MORE expands full card; mark buttons activate only after MORE
- [x] Rename Know / Don't Know → **Skip / Review** throughout (study screen, summary screen, strings)
- [x] Skip / Review icons: Skip = check-circle (amber), Review = flag (green)
- [x] `users/{uid}/cardMarks/{cardId}` Firestore subcollection — durable cross-session card marks; fire-and-forget upsert preserving original `markedAt`
- [x] Question result tracking — rolling 5-result window (`success` / `fail` / `unseen`, newest-first) stored at `users/{uid}/questionResults/{cardId}_{fieldId}`; tracked for `text_input` and `multiple_choice` fields; `reveal` fields excluded
- [x] `QuestionResultRepository` + `FirebaseQuestionResultRepository`; prefix range query for per-card lookup without a composite index
- [x] Deploy updated Firestore rules for `cardMarks` and `questionResults` subcollections

#### Phase 7b — Language pair on cards and sets (complete)
- [x] Add `nativeLanguage` + `targetLanguage` (ISO 639-1 string, nullable) to `FlashCard` and `CardSet` models, Firestore serialization, and JSON export
- [x] `lib/utils/languages.dart` — curated list of 74 ISO 639-1 languages (`kLanguages`) + `languageName(code)` lookup
- [x] `LanguagePicker` widget — searchable bottom sheet (`DraggableScrollableSheet`) with autofocus search field filtering by name or code; current selection highlighted; "Not set" always pinned at top
- [x] Language pickers added to `CardFormScreen` and `SetFormScreen`
- [x] Default language inheritance: card created inside a set inherits set's language pair; card created in the Cards section inherits from `lastUsedLanguagesProvider` (last card saved this session)
- [x] One-shot admin script (`scripts/seed_languages.js`) to back-fill language fields on existing Firestore documents

#### UI/UX Polish
- [x] Review all screens for visual consistency
- [x] Improve error messages and user feedback
- [x] Add loading states and spinners
- [x] Implement smooth animations and transitions
- [ ] Ensure responsive design on all screen sizes *(deferred — widescreen layout owned by the Web Dashboard phase; see Post-MVP below)*
- [ ] Test on various device sizes (phones, tablets, desktops) *(deferred — tablet/desktop testing blocked on Web Dashboard phase)*

#### Comprehensive Testing
- [x] Unit tests for models (`CardField`, `FlashCard`, `ImportSetDiff`, `ImportAnalysis`) and import service logic (`_parseCard`, `_buildChanges`, `_fieldsChanged`, new-card routing) — 47 tests, all passing
- [ ] Widget/UI tests for all screens *(deferred — lower ROI at this stage; revisit once screens stabilise post-MVP)*
- [ ] Integration tests for core workflows *(deferred — requires Firebase Local Emulator Suite; scheduled alongside Firebase emulator setup)*
- [ ] Cross-platform testing (iOS, Android, Web, Windows, macOS, Linux) *(deferred — desktop/web testing blocked on Web Dashboard phase; mobile covered by manual QA)*
- [ ] Test on real devices and emulators *(deferred — covered by manual QA during feature development)*
- [ ] Performance testing and optimization *(deferred — post-MVP once usage patterns are known)*
- [ ] Memory leak detection and fixing *(deferred — post-MVP)*
- [ ] Battery usage optimization (for mobile) *(deferred — post-MVP)*

#### Phase 7d — Accessibility & Localization
- [x] Audit for accessibility issues (colour contrast, touch target sizes, semantic labels on custom widgets)
- [x] Dark mode: audit for hardcoded colours that break in dark theme; add dark mode toggle to ProfileScreen (persisted to device preferences)
- [ ] Add screen reader support (`Semantics` labels on custom widgets; smoke-test core flows with TalkBack/VoiceOver)
- [ ] Test with accessibility tools
- [ ] Add text size adjustment controls *(deferred — Flutter respects system text scale by default; revisit if issues found during audit)*
- [ ] Implement high contrast mode *(deferred — post-MVP enhancement)*
- [ ] Prepare for localization (structure for multiple languages) *(deferred — no second language planned for MVP)*

#### Documentation
- [ ] Create user documentation/help
- [ ] Document API endpoints and data structures
- [ ] Create developer setup guide
- [ ] Add code comments and documentation
- [ ] Create architecture documentation

#### Deployment Preparation
- [ ] Set up CI/CD pipeline
- [ ] Configure build and signing certificates (iOS, Android)
- [ ] Set up app store deployment process
- [ ] Create release notes template
- [ ] Set up analytics/crash reporting (Firebase Crashlytics)
- [ ] Set up user feedback mechanism

**Deliverable**: Production-ready application.

---

## Future Enhancements (Post-MVP)

These features are important but can be deferred to post-launch:

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
- Global normalized tag system (Phase 4d) — tags converge across users for marketplace search
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

**Why deferred:** Widescreen layout decisions are made here once, correctly, rather than retrofitted during Phase 7 mobile polish.

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

| Phase | Duration | Focus |
|-------|----------|-------|
| Phase 1: Setup & Auth | 2 weeks | Foundation |
| Phase 2: Data Layer | 1 week | Infrastructure |
| Phase 3: Cards & Templates | 2 weeks | Data entry |
| Phase 4: Card Sets | 1 week | Organization |
| Phase 5: Study Mode | 2 weeks | Core feature |
| Phase 6: Import/Export | 1 week | Data portability |
| Phase 7: Polish & Test | 1 week | Quality |
| **Total** | **10 weeks** | **MVP Ready** |
| — | — | — |
| Phase 4d: Global Tag System | 1 week | Search foundation (post-MVP) |
| Phase 4c: Search & Filter | 1 week | Discovery (post-MVP, needs 4d) |
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

**Should Have (High Priority):**
- ✅ Offline support
- ✅ Bulk import/export
- ✅ Session resume
- ✅ Accessibility features
- ✅ Cross-platform support

**Nice to Have (Lower Priority):**
- ⭐ Global tag system + search/filter (Phase 4c/4d)
- ⭐ Spaced repetition
- ⭐ Advanced analytics
- ⭐ Localization

**Long-Term (Marketplace):**
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
- ✅ Offline functionality works reliably
- ✅ Authentication is secure
- ✅ Code is well-tested (>80% coverage for core features)
- ✅ App is accessible (WCAG AA compliance)

