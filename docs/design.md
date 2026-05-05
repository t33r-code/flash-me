# Flash Me - Design Specification

This document outlines the design for all major features of the Flash Me application. Each section provides detailed design specifications and serves as the basis for creating implementation plans.

## Table of Contents
- [Authorization and Basic User Accounts](#authorization-and-basic-user-accounts)
- [Create/Update/Delete Flash Cards](#createupdatedelete-flash-cards)
- [Groupings of Flash Cards (Card Sets)](#groupings-of-flash-cards-card-sets)
- [Import and Export Flash Card Sets](#import-and-export-flash-card-sets)
- [Use Flash Card Sets (CORE USE CASE)](#use-flash-card-sets-core-use-case)

---

## Authorization and Basic User Accounts

### Overview
Users must be able to create accounts, log in, and manage their sessions securely.

### Requirements
- User registration with email and password
- User login/logout functionality
- Session management
- Password recovery/reset
- User profile management

### Design Details

#### Authentication Architecture
- **Provider:** Firebase Authentication
- **Platforms:** Web, iOS, Android, macOS, Linux, Windows (via FlutterFire)
- **Supported Sign-In Methods:**
  - Email/Password (Local Accounts)
  - Google Sign-In

#### Registration Flow (Firebase Auth)

**Local Account Registration via Firebase:**
- User provides email and password on registration screen
- Call `FirebaseAuth.instance.createUserWithEmailAndPassword(email, password)`
- Firebase handles password validation and hashing
- Optional: Enable email verification via `sendEmailVerification()` after account creation
- Create Firestore user document with additional profile data (if needed)
- Auto-login user after successful registration
- Redirect to dashboard

**Google OAuth Registration via Firebase:**
- User taps "Sign up with Google" button
- Trigger Google Sign-In via `GoogleSignIn().signIn()`
- Firebase automatically creates user account on first sign-in
- Firebase links email to user identity
- Firestore document created/updated with user profile data
- Auto-login user
- Redirect to dashboard

#### Account Linking
- Firebase natively supports linking multiple auth providers to one user account
- Use `FirebaseAuth.instance.currentUser?.linkWithCredential(credential)` to link providers
- Users can manage connected providers in account settings
- Prevents duplicate accounts with same email from different providers

#### Session Management
- Firebase provides built-in session management via `FirebaseAuth.currentUser`
- Client SDK automatically manages ID tokens and refresh tokens
- ID token stored in secure storage (handled by FlutterFire)
- No need for manual JWT management

#### User Data Storage
- User core auth data in Firebase Authentication
- Extended user profile data stored in Firestore collection: `users/{userId}`
  - Fields: displayName, photoURL, createdAt, etc.
- Sync Firestore user data on first login and periodically

### Implementation Notes
- Use `firebase_auth` and `google_sign_in` Flutter packages
- Firestore will handle user profile data storage
- Email verification enabled by default (can be toggled)
- Leverage Firebase security rules for data access control
- Handle token refresh automatically via Firebase SDK
- Plan for account linking flow and user experience

### Implementation Plan
- [ ] Set up Firebase project and enable Authentication methods (Email/Password, Google)
- [ ] Install and configure `firebase_auth`, `google_sign_in`, and `cloud_firestore` packages
- [ ] Set up Firestore collection schema for user profiles (`users/{userId}`)
- [ ] Implement local registration screen with email/password validation
- [ ] Implement `createUserWithEmailAndPassword()` Firebase call
- [ ] Implement optional email verification flow
- [ ] Implement Google Sign-In button and flow
- [ ] Handle first-time Google Sign-In user creation
- [ ] Implement account linking logic for multiple auth providers
- [ ] Create Firestore user document on successful registration
- [ ] Implement auto-login after registration
- [ ] Implement logout functionality
- [ ] Test both registration flows (local and Google) on all platforms
- [ ] Add error handling for auth failures (invalid email, weak password, etc.)
- [ ] Set up Firebase security rules for user data access

---

## Create/Update/Delete Flash Cards

### Overview
Users need full CRUD capabilities for individual flash cards within their card sets. Cards are displayed as a series of informational boxes rather than traditional flip cards, with flexible field types for different learning scenarios.

### Requirements
- Create new flash cards with customizable fields
- Update existing card content
- Delete cards
- Support for card templates
- Three field types: reveal-on-click, text input with validation, multiple choice
- Card metadata (creation date, last modified, author, etc.)

### Design Details

#### Card Structure
- Each card has a **primary field** (always first): foreign language word (text only)
- Clicking primary field reveals translation to native language (text only, not editable during study)
- **Additional fields** (0 to many): user-defined fields for grammar, examples, context, etc.
  - Each field has: name (label), field type, content/data

#### Field Types

**1. Reveal-on-Click Field**
- Display: Shows a question or label
- Interaction: User clicks to reveal the answer
- Content structure: {label, answer}
- Example: "Gender" → clicks to see "Feminine"

**2. Text Input Field**
- Display: Shows a question/prompt and blank text input box
- Interaction: User types answer, clicks "Check" button
- Validation: Backend compares user input against expected answer(s)
- Feedback: Shows if correct, partially correct, or incorrect
- Content structure: {label, correct_answers (array), hint (optional)}
- Example: "Conjugate this verb in 2nd person singular" → user types answer → feedback

**3. Multiple Choice Field**
- Display: Shows a question and list of 2+ options
- Interaction: User selects an option, clicks "Check" button
- Validation: Checks if selected option is correct
- Feedback: Shows if correct or incorrect (with correct answer revealed)
- Content structure: {label, options (array with correct_index), explanation (optional)}
- Example: "What is the gender?" → options [Masculine, Feminine, Neuter] → user selects → feedback

#### Card Data Model (Firestore)
```
cards/{cardId}
  - setId: string (foreign key to card set)
  - primaryWord: string (word in foreign language)
  - translation: string (word in native language)
  - fields: array of field objects
    - fieldId: unique identifier
    - name: string (label)
    - type: enum (reveal, text_input, multiple_choice)
    - content: object (varies by type)
  - templateId: string (optional, reference to template used)
  - createdAt: timestamp
  - updatedAt: timestamp
  - createdBy: userId
```

#### Card Templates
- Templates are reusable field configurations
- Template structure: {name, description, fields_schema}
- Fields in template have same structure as card fields (but no specific content)
- Users can:
  - Create custom templates from scratch
  - Create template from existing card
  - Browse pre-made templates (optional: shipped with app)
  - Use templates when creating new cards

#### Template Usage Workflow
1. User creates/selects a template with fields: [Primary (auto), Gender, Example, Conjugation]
2. When creating a new card, user selects template
3. Form auto-populates with template fields
4. User fills in specific content for each field
5. Card is created with template structure

#### Card CRUD Operations

**Create Card:**
- User selects a set
- Option A: Select template, fill in fields
- Option B: Create from scratch (manual field addition)
- Validation: Primary word required, at least one additional field recommended
- Save to Firestore

**Read Card:**
- Display full card with all fields during study or edit mode
- Show primary word + translation
- Show all additional fields with their content and field type

**Update Card:**
- Edit any field (primary word, translation, or additional fields)
- Add new fields to existing card
- Remove fields from card
- Save changes to Firestore

**Delete Card:**
- Soft delete or hard delete (TBD)
- Remove card from all sets it belongs to (if applicable)

### Implementation Notes
- Field type icon/visual indicator on card display during study
- Consider rich text support for answers (bold, italic, etc.) - for future consideration
- Text input validation: case-insensitive by default, but option to require exact match
- Multiple choice: randomize option order on each study session (optional)
- Template management: CRUD operations on templates
- Consider providing default/example templates for common languages
- Cloud Firestore indexes needed for efficient card queries by set and user

### Implementation Plan
- [ ] Design and implement Firestore schema for cards and templates
- [ ] Create data models/classes in Dart for Card, Field, Template
- [ ] Implement template CRUD operations (create, read, update, delete, list)
- [ ] Create UI for template creation and management
- [ ] Implement card creation screen with template selection
- [ ] Build dynamic form builder that generates fields based on template
- [ ] Implement primary word field (foreign language + translation reveal)
- [ ] Implement reveal-on-click field type UI and logic
- [ ] Implement text input field type UI with validation and feedback
- [ ] Implement multiple choice field type UI with validation and feedback
- [ ] Implement card update/edit screen
- [ ] Implement card deletion (with confirmation)
- [ ] Add card metadata (createdAt, updatedAt, createdBy)
- [ ] Implement field type icons/indicators for visual distinction
- [ ] Create Firestore queries for efficient card retrieval by set
- [ ] Add optional field randomization for multiple choice
- [ ] Test all three field types in creation, editing, and study modes
- [ ] Create default/example templates (optional)
- [ ] Set up Firestore indexes for card queries

---

## Groupings of Flash Cards (Card Sets)

### Overview
Users can organize flash cards into sets and manage card membership within those sets. Card sets are the primary organizational unit and can contain any number of cards.

### Requirements
- Create card sets with metadata
- Add/remove cards from sets
- Update set metadata (name, description, etc.)
- Delete sets
- View all sets for a user
- Support for cards in multiple sets (cards can belong to 0+ sets)
- View all cards in a set
- Set collaboration/sharing (future consideration)

### Design Details

#### Card Set Data Model (Firestore)
```
sets/{setId}
  - userId: string (owner of the set)
  - name: string (required, e.g., "Spanish Verbs")
  - description: string (optional, e.g., "Regular and irregular verbs")
  - cardIds: array<string> (references to cards in this set)
  - cardCount: integer (denormalized for quick stats)
  - createdAt: timestamp
  - updatedAt: timestamp
  - isPublic: boolean (optional, for future sharing features)
  - tags: array<string> (optional, for organization: ["verbs", "regular"])
  - color: string (optional, for UI differentiation)
```

#### Card-Set Relationship
- **One-to-Many**: One card set contains many cards
- **Many-to-Many**: One card can belong to multiple sets
- **Implementation**: Store `cardIds` array in set document (preferred for small-medium set sizes)
- **Alternative**: Use subcollection `sets/{setId}/cards/{cardId}` if sets grow very large

#### Set Management Operations

**Create Set:**
- User provides: set name (required), description (optional)
- System generates: setId, timestamps, userId
- Set created with empty cardIds array
- Save to Firestore: `sets/{setId}`

**Read Sets:**
- List all sets for a user: Query `sets` collection where `userId == currentUser.id`
- Retrieve single set by ID: Direct document read
- Display set metadata and card count

**Update Set:**
- Edit set name, description, tags, color
- All metadata fields editable except userId and timestamps
- UpdatedAt timestamp updated on save

**Add Cards to Set:**
- User selects one or more existing cards
- Add their cardIds to the set's `cardIds` array
- Update `cardCount` counter
- Cards can be added from: create card flow, card browser, or bulk operations

**Remove Cards from Set:**
- User selects card(s) to remove
- Remove cardId from set's `cardIds` array
- Update `cardCount` counter
- Card itself is not deleted, just removed from this set

**Delete Set:**
- User confirms deletion
- Delete set document from Firestore
- Cards remain intact (only removed from set relationship)
- Soft delete option: mark `isDeleted: true` for future recovery

#### User Workflows

**Creating and Populating a Set:**
1. User navigates to "My Sets" view
2. Clicks "Create New Set"
3. Enters set name and optional description
4. Set created with empty card list
5. User either:
   - A) Creates new cards and adds them to set
   - B) Selects existing cards to add to set
6. Cards appear in set's card list

**Managing Set Membership:**
1. User opens a set
2. Views all cards currently in set
3. Can remove individual cards with confirmation
4. Can add more cards by selecting from existing cards or creating new ones

**Browsing and Studying Sets:**
1. User views "My Sets" dashboard
2. Each set displayed with: name, description, card count, last modified date
3. Can sort/filter by name, created date, card count, etc.
4. Click on set to view cards or start studying

#### Set Organization Features
- **Tags**: Optional tags for categorizing sets (e.g., "Beginner", "Grammar", "Vocabulary")
- **Color coding**: Optional color assignment for visual differentiation in list view
- **Set search**: Full-text search on set name and description
- **Set sorting**: By name, created date, modified date, card count

### Implementation Notes
- Use Firestore batch operations when adding/removing multiple cards from a set
- Denormalize cardCount for quick display without counting array
- Index on `userId + createdAt` for efficient "My Sets" queries
- Consider pagination for users with many sets
- UI should show set icon/thumbnail and last modified indicator
- For future scaling: if cardIds array becomes too large (>5000 items), migrate to subcollection approach

### Implementation Plan
- [ ] Design and implement Firestore schema for card sets
- [ ] Create CardSet data model/class in Dart
- [ ] Implement set creation with name and optional description
- [ ] Create "My Sets" dashboard/list view
- [ ] Display set metadata: name, description, card count, last modified
- [ ] Implement set update functionality (name, description, tags, color)
- [ ] Implement delete set with confirmation dialog
- [ ] Implement add cards to set (from existing cards)
- [ ] Implement remove cards from set
- [ ] Create set detail view showing all cards in set
- [ ] Implement card browser for selecting cards to add to sets
- [ ] Add tags/categorization support for sets
- [ ] Add color coding functionality for sets
- [ ] Implement set search/filtering
- [ ] Implement set sorting (by name, date, card count)
- [ ] Create Firestore queries for efficient set retrieval by user
- [ ] Implement batch operations for adding/removing multiple cards
- [ ] Set up Firestore indexes for set queries
- [ ] Add set modification timestamps to UI
- [ ] Test set CRUD operations on all platforms

### Future Capabilities

#### Public Sets & Discovery
- Allow set creators to mark sets as **public** (discoverable by other users)
- Public sets appear in a searchable, community database
- Public sets are read-only for non-owners (visible, but cannot be edited)
- Metadata tracked: views count, subscriber count, rating/reviews (optional)

#### Set Subscriptions
- Users can **subscribe** to public sets created by other users
- Subscribed sets appear in user's "My Sets" view with a visual indicator (lock icon, "subscribed" badge)
- Subscribed sets are linked to the original set (not a copy)
- When original set is updated (cards added/edited/removed), subscriber sees the updates
- Subscribers cannot edit the set content
- Subscribers can unsubscribe at any time
- Set creator can see subscriber count

**Data Model Addition:**
- Add `subscribers: array<userId>` to public sets
- Add `subscribedSets: array<setId>` to user profile (or separate collection)
- Track subscription metadata: subscribed date, notifications (optional)

#### Set Cloning
- Users can **clone** a public set to create their own independent copy
- Cloned set includes all cards from the original
- Cloned set is fully owned and editable by the cloning user
- Cloned set is no longer connected to the original
- Original set and cloned set evolve independently
- Optional: Track clone origin (show "cloned from" metadata for provenance)

**Workflow:**
1. User finds public set in community database
2. Clicks "Clone This Set" button
3. System creates new set document with cloned data
4. New set appears in user's "My Sets" view as owned by them
5. User can edit the cloned set freely

**Data Model Addition:**
- Add `clonedFromSetId: string (optional)` to track origin
- Add `clonedFromUser: string (optional)` to show who created original

#### Implementation Phasing
- **Phase 1 (Current)**: Private sets only (default implementation plan)
- **Phase 2 (Future)**: Add public/private toggle, community discovery database
- **Phase 3 (Future)**: Add subscription functionality
- **Phase 4 (Future)**: Add cloning functionality

---

## Import and Export Flash Card Sets

### Overview
Users can share and backup their card sets by importing and exporting them in standard formats. Both single sets and bulk operations are supported.

### Requirements
- Export sets to standard formats (JSON and CSV)
- Import sets from files (JSON and CSV)
- Support for exporting single sets or multiple sets
- Support for importing into new sets or existing sets
- Bulk operations (import/export multiple sets at once)
- Comprehensive error handling and validation
- Clear feedback on import success/failure
- Backup/restore capability

### Design Details

#### Export Functionality

**Export Formats:**

**1. JSON Format**
- Preserves complete card structure including all field types and metadata
- Most flexible for transferring between Flash Me instances
- File structure:
```json
{
  "version": "1.0",
  "exportDate": "2026-05-01T10:30:00Z",
  "sets": [
    {
      "name": "Spanish Verbs",
      "description": "Regular and irregular verbs",
      "tags": ["verbs", "regular"],
      "color": "#FF5733",
      "cards": [
        {
          "primaryWord": "hablar",
          "translation": "to speak",
          "fields": [
            {
              "name": "Gender",
              "type": "reveal",
              "content": { "answer": "N/A" }
            },
            {
              "name": "Conjugation (yo)",
              "type": "text_input",
              "content": { "correct_answers": ["hablo"], "hint": "Present tense" }
            },
            {
              "name": "Type",
              "type": "multiple_choice",
              "content": {
                "options": ["Regular", "Irregular", "Reflexive"],
                "correct_index": 0,
                "explanation": "This is a regular -ar verb"
              }
            }
          ]
        }
      ]
    }
  ]
}
```

**2. CSV Format**
- Simpler, compatible with spreadsheet applications (Excel, Google Sheets)
- Limited to basic fields (no complex field types preserved)
- Structure:
  - Header row: Set Name, Set Description, Primary Word, Translation, Field1_Name, Field1_Type, Field1_Content, Field2_Name, ...
  - Data rows: One card per row
  - Multiple sets: Separate sections with set metadata

**Export Workflow:**
1. User navigates to "My Sets"
2. Selects set(s) to export (single or multiple)
3. Chooses format: JSON or CSV
4. System generates file
5. File downloaded to device with name: `flash-me-export-[timestamp].[json/csv]`

**Export Considerations:**
- Include all cards in set
- Include all field types and content
- Include set metadata (name, description, tags, color)
- Include version number for future compatibility
- Timestamp for reference

#### Import Functionality

**Import Formats Supported:**
- JSON (from Flash Me export)
- CSV (from Flash Me export or user-created file)
- Optional: Quizlet CSV format (future consideration)

**Import Workflow:**
1. User navigates to "Import Sets"
2. Selects file from device (JSON or CSV)
3. System validates file format and structure
4. Preview dialog shows:
   - Number of sets to import
   - Number of cards in each set
   - Any validation warnings/errors
5. User can:
   - Proceed with import (creates new sets)
   - Edit set names before import
   - Choose to merge with existing set (optional)
6. System creates set(s) and cards in Firestore
7. Success confirmation with import summary

**Data Validation During Import:**
- File format check (valid JSON/CSV structure)
- Required fields check (primary word, translation, field names)
- Field type validation (reveal, text_input, multiple_choice)
- Text input: Verify correct_answers array is not empty
- Multiple choice: Verify options array and correct_index validity
- Encoding check (UTF-8)
- File size limit (e.g., 10MB)

**Error Handling:**
- **Invalid format**: Clear error message with line number (for CSV)
- **Missing required fields**: Skip problematic cards, report in summary
- **Invalid field types**: Report which cards/fields are affected
- **Encoding issues**: Alert user and suggest remediation
- **Duplicate cards**: Option to skip or overwrite
- **Partial import**: Allow partial success (import valid cards, report invalid)

**Bulk Operations:**
- Import multiple set files at once
- Each file processed independently
- Consolidated summary at end (total sets/cards imported, errors)

**Merge/Update Logic:**
- **Import as new set**: Default behavior, creates new set document
- **Merge to existing set**: User selects target set, imported cards added to it
- **Update existing cards**: Match by primaryWord + translation, ask before overwriting

#### Import/Export Error Scenarios

| Scenario | Behavior |
|----------|----------|
| Empty required field (e.g., primaryWord) | Skip card, report in summary |
| Invalid field type value | Skip field, import card without it |
| Malformed JSON | Reject file, show parse error |
| Invalid CSV structure | Attempt to parse, report problematic rows |
| File too large | Reject with size limit message |
| Duplicate set name in import | Append suffix or allow user to rename |
| Special characters in content | Preserve and encode properly |

### Implementation Notes
- Use `csv` or `excel` package for CSV parsing in Dart
- Validate JSON schema against expected structure
- Use UTF-8 encoding for all files
- Consider adding ZIP support for bulk exports (multiple sets in one file)
- Display detailed import report/log showing what was imported and any issues
- Test with various CSV formats and encodings
- Consider providing CSV template for users to create cards in spreadsheet
- Archive/backup integration: users can schedule automatic exports (future)

### Implementation Plan
- [ ] Design Firestore export function to retrieve full set + card data
- [ ] Implement JSON export format serialization
- [ ] Implement CSV export format serialization
- [ ] Create export UI with format selection
- [ ] Implement file download for both JSON and CSV
- [ ] Add export timestamp and version metadata
- [ ] Create import file picker UI
- [ ] Implement JSON file parsing and validation
- [ ] Implement CSV file parsing and validation
- [ ] Validate required fields during import (primaryWord, translation, etc.)
- [ ] Validate field types and content structure
- [ ] Implement error reporting with line numbers (CSV)
- [ ] Create import preview dialog showing summary
- [ ] Implement merge logic (new set vs. existing set)
- [ ] Implement duplicate detection and handling
- [ ] Create Firestore batch operations for bulk imports
- [ ] Implement success/error summary report after import
- [ ] Add file size validation
- [ ] Test import/export round-trip (export → import → verify)
- [ ] Test with various CSV formats and encodings
- [ ] Create CSV template/example for users
- [ ] Handle special characters and encoding properly
- [ ] Add unit tests for import/export validation logic

---

## Use Flash Card Sets

### Overview
Users study flash cards by going through a set and testing their knowledge with multi-field cards. This is the primary interaction with the application. The study mode displays cards sequentially, allows interaction with different field types, tracks progress, and provides statistics.

### Requirements
- Select a set to study
- Display cards one at a time with all fields visible
- Interact with different field types:
  - Reveal-on-click fields (click to reveal answer)
  - Text input fields (type answer, click check, see feedback)
  - Multiple choice fields (select option, click check, see feedback)
- Navigate between cards (previous/next)
- Mark cards as known/unknown
- Track study progress (current card number, total cards)
- Display session statistics (cards studied, mastery progress)
- Session history (saved session data)
- Resume incomplete sessions
- Study session options (shuffle, filters, etc.)

### Design Details

#### Study Session Architecture

**Study Session Model (Firestore):**
```
users/{userId}/studySessions/{sessionId}
  - setId: string (which set is being studied)
  - startTime: timestamp
  - lastAccessTime: timestamp
  - status: enum (in_progress, completed, paused)
  - cardProgress: map<cardId, cardSessionData>
    - cardId:
      - status: enum (not_started, revealed, answered, marked_known, marked_unknown)
      - revealedFields: array<fieldId> (which reveal fields have been revealed)
      - textInputAnswers: map<fieldId, userAnswer>
      - multipleChoiceAnswers: map<fieldId, selectedIndex>
      - markedKnown: boolean
      - markedUnknown: boolean
      - attempts: integer
  - cardSequence: array<cardId> (order of cards in this session)
  - currentCardIndex: integer
  - totalCardsStudied: integer
  - cardsKnown: integer
  - cardsUnknown: integer
  - sessionStats: object
    - avgTimePerCard: float (milliseconds)
    - totalTimeSpent: integer (milliseconds)
    - correctAnswers: integer
    - incorrectAnswers: integer
    - skipped: integer
```

#### Study Session Flow

**1. Session Selection**
- User navigates to "My Sets"
- Selects a set to study
- System checks for incomplete sessions for this set:
  - If exists: Offer to "Resume" or "Start New Session"
  - If none: Start new session

**2. Study Session Configuration (Optional)**
- Before starting, user can configure:
  - **Shuffle cards**: Randomize card order (yes/no)
  - **Filter**: Study only certain cards (e.g., cards marked unknown last session)
  - **Session limit**: Study only first N cards, or time-based limit (optional future feature)

**3. Session Start**
- Create study session document in Firestore
- Initialize cardProgress map with all cards set to "not_started"
- Generate cardSequence (in order or shuffled based on config)
- Set currentCardIndex to 0
- Display first card

#### Card Display During Study

**Card Layout:**
```
┌─────────────────────────────────────┐
│ Card 1 of 20                        │
├─────────────────────────────────────┤
│ PRIMARY FIELD (Foreign Language)     │
│  ┌─────────────────────────────────┐ │
│  │ hablar                          │ │ Click to reveal translation
│  │ [Click to show translation]     │ │
│  └─────────────────────────────────┘ │
│                                       │
│ ADDITIONAL FIELDS                     │
│  ┌─────────────────────────────────┐ │
│  │ Gender (Reveal)                 │ │
│  │ [Click to reveal] ← not revealed │ │
│  └─────────────────────────────────┘ │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │ Conjugation (yo) (Text Input)   │ │
│  │ Enter your answer: [          ] │ │
│  │ [Check Answer]                  │ │
│  └─────────────────────────────────┘ │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │ Type (Multiple Choice)          │ │
│  │ ◯ Regular  ◯ Irregular          │ │
│  │ [Check Answer]                  │ │
│  └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ ◀ Previous    [Know] [Don't Know]   │
│                              Next ▶  │
└─────────────────────────────────────┘
```

**Primary Field Display:**
- Displays foreign language word prominently
- Initially shows: "Click to show translation"
- On click: Reveals native language translation
- After revealed: User can see both words
- Not timed; user controls when to reveal

**Reveal-on-Click Field:**
- Shows label/question
- Initially shows: "[Click to reveal]"
- On click: Reveals answer
- Label remains visible, answer becomes visible
- Can click again to hide answer (toggle)

**Text Input Field:**
- Shows label/question and text input box
- User types their answer
- Clicks "Check Answer" button
- Feedback displayed:
  - ✓ Correct! (if matches correct_answers exactly or closely)
  - ◐ Close (if partial match, if logic implemented)
  - ✗ Incorrect: The correct answer is... (if wrong)
  - Show hint if available
- Field state locked after checking (can't edit without resetting)
- Option: "Try Again" button to reset and try different answer

**Multiple Choice Field:**
- Shows label/question and options as radio buttons
- User selects one option
- Clicks "Check Answer" button
- Feedback displayed:
  - ✓ Correct!
  - ✗ Incorrect: The correct answer is [option]
  - Optional explanation shown if provided
- Field state locked after checking
- Option: "Try Again" button to reset selection

#### Navigation & Control

**Navigation Controls:**
- **Previous Button**: Go to previous card in sequence
  - Disabled on first card
  - User can review and modify answers from previous attempts
  
- **Next Button**: Go to next card in sequence
  - Disabled on last card
  - Moves to next card regardless of whether current card is fully answered

- **Know Button**: Mark current card as "known"
  - Flag card in cardProgress
  - Can toggle on/off
  - Visible indicator when marked
  
- **Don't Know Button**: Mark current card as "unknown"
  - Flag card in cardProgress
  - Can toggle on/off
  - Useful for prioritizing cards to study again

**Progress Indicator:**
- Show "Card X of Y" at top
- Progress bar showing completion percentage
- Visual indication of known/unknown markers

#### Session Pause & Resume

**Pause Session:**
- User can leave study session at any time
- Current session document saved to Firestore
- Session marked as "paused" or "in_progress"
- User can close app

**Resume Session:**
- When user returns to same set, system detects incomplete session
- Option to "Resume Session" shows:
  - Last card studied
  - Progress so far
  - Time since last access
- Clicking resume loads last session state
- Continue from where user left off (or start over)

**Complete Session:**
- After last card (or user clicks "End Session")
- Session marked as "completed"
- Final statistics calculated:
  - Time spent
  - Cards marked known/unknown
  - Completion percentage
- Session stored as historical record

#### Session Statistics & Reporting

**Session Summary (after completion or on demand):**
- Total cards studied: X of Y
- Cards marked known: X
- Cards marked unknown: X
- Time spent: HH:MM:SS
- Average time per card: X.XX seconds
- Text answers correct/incorrect/skipped
- Multiple choice answers correct/incorrect/skipped

**Session History:**
- Store completed sessions in Firestore
- User can view history:
  - When session was studied
  - Duration
  - Progress summary
  - Date/time
- Optional: Graph showing progress over time (future)

#### Study Mode State Management

**State During Study:**
- Current card: Which card is displayed
- Field visibility: Which reveal fields are shown
- Answers given: Text and multiple choice selections
- Known/Unknown flags: Which cards marked
- Session progress: Time spent, cards covered

**Persistence:**
- Save session state frequently (after each field interaction)
- Use Firestore for cloud sync
- Local cache for offline study (with sync on reconnect)
- Session can be resumed on same or different device

### Implementation Notes
- Use Provider or Riverpod for state management during study session
- Implement auto-save to Firestore after each significant action
- Consider debouncing saves to avoid excessive database writes
- Text input validation: case-insensitive by default (user preference toggleable)
- Multiple choice: Consider randomizing option order each time card is studied
- Implement haptic feedback (vibration) on correct/incorrect answers
- Consider accessibility features: text size adjustment, high contrast mode
- Session history queries: Index on userId + setId + startTime
- Offline support: Cache session data locally, sync when connection restored
- Consider spaced repetition algorithm in future (prioritize unknowns)
- Performance: Preload next/previous cards for smooth scrolling

### Implementation Plan
- [ ] Design and implement Firestore schema for study sessions
- [ ] Create StudySession data model/class in Dart
- [ ] Create CardSessionData model for tracking individual card progress
- [ ] Implement study session selection UI ("Resume" vs "Start New" logic)
- [ ] Implement study session configuration (shuffle, filters, etc.)
- [ ] Create study session initialization and start logic
- [ ] Build primary field display with click-to-reveal translation
- [ ] Build reveal-on-click field type UI and interaction
- [ ] Build text input field UI with answer checking and feedback
- [ ] Build multiple choice field UI with selection and feedback
- [ ] Implement text input validation (case-insensitive by default)
- [ ] Implement feedback messaging (correct, incorrect, partial)
- [ ] Implement hint display for text input fields (optional)
- [ ] Build navigation controls (Previous, Next, Know, Don't Know buttons)
- [ ] Implement navigation logic (prevent going past boundaries)
- [ ] Build progress indicator (Card X of Y, progress bar)
- [ ] Implement card shuffling option
- [ ] Create card session state management (current card, revealed fields, answers)
- [ ] Implement state persistence to Firestore (auto-save after actions)
- [ ] Implement session pause functionality
- [ ] Implement session resume functionality
- [ ] Implement session completion and statistics calculation
- [ ] Build session summary/statistics screen
- [ ] Implement session history storage and retrieval
- [ ] Create session history UI/list view
- [ ] Implement offline support with local caching
- [ ] Add haptic feedback for answer feedback (correct/incorrect)
- [ ] Implement text size adjustment for accessibility
- [ ] Implement high contrast mode option
- [ ] Add keyboard shortcuts (arrow keys for navigation, Enter to check)
- [ ] Create Firestore indexes for efficient session queries
- [ ] Implement preloading of adjacent cards for smooth performance
- [ ] Test all field types during study mode
- [ ] Test navigation and state persistence
- [ ] Test resume functionality across sessions
- [ ] Test offline study with sync on reconnect
- [ ] Performance testing with large card sets (1000+ cards)
- [ ] Accessibility testing (screen readers, text size)

---
