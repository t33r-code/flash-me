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
- [ ] Test data models with unit tests (deferred to Phase 7)
- [ ] Test Firestore operations with integration tests (deferred to Phase 7)

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
- [ ] Implement bulk card creation from CSV (optional, Phase 6)

**Deliverable**: Full CRUD for templates and cards, with working field types.

---

## Phase 4: Card Sets Management (Weeks 5-6)

**Goal**: Enable users to organize cards into sets and manage membership.

**Dependencies**: Phase 3 (need cards to organize)

**Priority**: High - Core organizational feature.

### Tasks
- [ ] Design Firestore schema for card sets
- [ ] Create CardSet data model
- [ ] Implement set creation with name and description
- [ ] Create "My Sets" dashboard/list view
- [ ] Display set metadata (name, card count, last modified)
- [ ] Implement set update functionality (name, description, tags, color)
- [ ] Implement set deletion with confirmation
- [ ] Implement add cards to set functionality
- [ ] Implement remove cards from set functionality
- [ ] Create set detail view showing all cards
- [ ] Implement card browser for selecting cards to add
- [ ] Add tags/categorization support
- [ ] Add color coding functionality
- [ ] Implement set search/filtering
- [ ] Implement set sorting options
- [ ] Implement pagination for sets list (avoid performance issues at scale)
- [ ] Create Firestore queries for set retrieval
- [ ] Implement batch operations for card management
- [ ] Set up Firestore indexes
- [ ] Add modification timestamp display
- [ ] Test set CRUD on all platforms
- [ ] Create set templates (preset sets for common languages - optional)

**Deliverable**: Complete set management with card organization.

---

## Phase 5: Study Mode - The Core Experience (Weeks 6-8)

**Goal**: Implement the primary user interaction - studying cards with full session tracking.

**Dependencies**: Phase 4 (need sets to study)

**Priority**: Critical - This is the core value proposition.

### Tasks

#### Study Session Infrastructure
- [ ] Design and implement Firestore schema for study sessions
- [ ] Create StudySession data model
- [ ] Create CardSessionData model for tracking card progress
- [ ] Implement study session service
- [ ] Implement session state management (Provider/Riverpod)

#### Study Session Flow
- [ ] Implement study set selection UI
- [ ] Implement "Resume" vs "Start New Session" logic
- [ ] Create study session configuration screen (shuffle, filters)
- [ ] Implement session initialization
- [ ] Implement card shuffling option

#### Card Display & Interaction
- [ ] Build study session screen UI
- [ ] Implement primary field display with click-to-reveal translation
- [ ] Build reveal-on-click field interaction
- [ ] Build text input field UI with validation and feedback
- [ ] Build multiple choice field UI with selection and feedback
- [ ] Implement text input validation (case-insensitive by default, respect per-field exact-match setting)
- [ ] Implement feedback messaging (correct, incorrect, partial)
- [ ] Implement "Try Again" button for fields

#### Session Controls & Navigation
- [ ] Build navigation controls (Previous, Next, Know, Don't Know)
- [ ] Implement navigation logic (boundary checks)
- [ ] Build progress indicator (Card X of Y, progress bar)
- [ ] Implement card marking (known/unknown toggles)
- [ ] Add visual indicators for marked cards

#### State Management & Persistence
- [ ] Implement card session state tracking
- [ ] Implement auto-save to Firestore (after each action, debounced to reduce write volume)
- [ ] Implement session pause functionality
- [ ] Implement session resume logic
- [ ] Implement session completion and statistics calculation

#### Session Statistics & History
- [ ] Build session summary screen
- [ ] Calculate session statistics (time spent, cards studied, accuracy)
- [ ] Implement session history storage
- [ ] Create session history UI/list view
- [ ] Display historical session data

#### Advanced Features
- [ ] Implement offline support with local caching
- [ ] Add haptic feedback (vibration) for answer feedback
- [ ] Implement text size adjustment (accessibility)
- [ ] Implement high contrast mode
- [ ] Add keyboard shortcuts (arrow keys, Enter)
- [ ] Implement card preloading for smooth performance

#### Testing
- [ ] Test all field types during study
- [ ] Test navigation and state persistence
- [ ] Test resume functionality
- [ ] Test offline study with sync
- [ ] Performance test with large sets (1000+ cards)
- [ ] Accessibility testing

**Deliverable**: Fully functional study mode with session tracking and statistics.

---

## Phase 6: Import/Export (Weeks 8-9)

**Goal**: Enable users to backup and share card sets.

**Dependencies**: Phase 4 (need sets to export), Phase 3 (need cards)

**Priority**: Medium - Important for data portability and sharing.

### Tasks

#### Export Functionality
- [ ] Implement Firestore export function (retrieve full set + card data)
- [ ] Implement JSON export format serialization
- [ ] Implement CSV export format serialization
- [ ] Create export UI with format selection
- [ ] Implement file download for JSON and CSV
- [ ] Add export metadata (timestamp, version)

#### Import Functionality
- [ ] Create import file picker UI
- [ ] Implement JSON file parsing and validation
- [ ] Implement CSV file parsing and validation
- [ ] Validate required fields during import
- [ ] Validate field types and content structure
- [ ] Implement error reporting with line numbers (CSV)
- [ ] Create import preview dialog
- [ ] Implement merge logic (new vs. existing set)
- [ ] Implement duplicate detection and handling
- [ ] Implement Firestore batch operations for bulk imports
- [ ] Implement bulk import (multiple files at once) with consolidated summary report
- [ ] Create success/error summary report

#### Supporting Features
- [ ] Add file size validation
- [ ] Handle special characters and encoding
- [ ] Create CSV template/example for users
- [ ] Add unit tests for validation logic
- [ ] Test import/export round-trip
- [ ] Test with various CSV formats

**Deliverable**: Complete import/export functionality for all formats.

---

## Phase 7: Polish, Testing & Optimization (Weeks 9-10)

**Goal**: Refine UX, ensure stability, and optimize performance.

**Dependencies**: All previous phases

**Priority**: High - Ensures quality release.

### Tasks

#### UI/UX Polish
- [ ] Review all screens for visual consistency
- [ ] Improve error messages and user feedback
- [ ] Add loading states and spinners
- [ ] Implement smooth animations and transitions
- [ ] Ensure responsive design on all screen sizes
- [ ] Test on various device sizes (phones, tablets, desktops)

#### Comprehensive Testing
- [ ] Unit tests for all services and models
- [ ] Widget/UI tests for all screens
- [ ] Integration tests for core workflows
- [ ] Cross-platform testing (iOS, Android, Web, Windows, macOS, Linux)
- [ ] Test on real devices and emulators
- [ ] Performance testing and optimization
- [ ] Memory leak detection and fixing
- [ ] Battery usage optimization (for mobile)

#### Accessibility & Localization
- [ ] Audit for accessibility issues
- [ ] Add screen reader support
- [ ] Test with accessibility tools
- [ ] Add text size adjustment controls
- [ ] Implement high contrast mode
- [ ] Prepare for localization (structure for multiple languages)

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

### Sharing & Community
- [ ] Public sets database
- [ ] Set subscriptions
- [ ] Set cloning
- [ ] User profiles and profiles management
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
- ✅ CSV export
- ✅ Session resume
- ✅ Accessibility features
- ✅ Cross-platform support

**Nice to Have (Lower Priority):**
- ⭐ Public sets sharing
- ⭐ Set subscriptions
- ⭐ Set cloning
- ⭐ Spaced repetition
- ⭐ Advanced analytics
- ⭐ Localization

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

