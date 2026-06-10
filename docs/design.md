# Flash Me - Design Specification

This document outlines the design for all major features of the Flash Me application. Each section provides detailed design specifications and serves as the basis for creating implementation plans.

## Table of Contents
- [Authorization and Basic User Accounts](#authorization-and-basic-user-accounts)
- [Create/Update/Delete Flash Cards](#createupdatedelete-flash-cards)
- [Groupings of Flash Cards (Card Sets)](#groupings-of-flash-cards-card-sets)
- [Tag System](#tag-system)
- [Import and Export Flash Card Sets](#import-and-export-flash-card-sets)
- [Study Tab & Study Modes](#study-tab--study-modes)
- [Use Flash Card Sets (CORE USE CASE)](#use-flash-card-sets-core-use-case)
- [User Performance Tracking](#user-performance-tracking)
- [Marketplace MVP (Alpha 0.2)](#marketplace-mvp)
- [Marketplace & Lessons — Long-Term Vision](#marketplace--lessons--long-term-vision)

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
- Trigger Google Sign-In via `GoogleSignIn.instance.authenticate()` (v7 API; `GoogleSignIn.instance.initialize()` called once at app startup in `main.dart`)
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
- Each card has a **primary field** (always first): foreign language word → translation reveal
  - **Text** (`primaryWord` / `translation`) is always present on every card
  - **Image** (`primaryImageUrl`, optional): a clip-art style illustration stored in Firebase Storage
  - **Audio** (`primaryAudioUrl`, optional): a short pronunciation clip stored in Firebase Storage
  - **`primaryWordHidden`** flag (default `false`): when `true` and at least one media asset is present, the primary word text is hidden on first display and revealed via a "Show Word" button — useful for image/audio-first drilling
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
  - primaryWord: string (word in foreign language; always present)
  - translation: string (word in native language; always present)
  - primaryImageUrl: string? (optional Firebase Storage download URL for a clip-art image)
  - primaryAudioUrl: string? (optional Firebase Storage download URL for a pronunciation clip)
  - primaryWordHidden: boolean (default false; hides primaryWord until "Show Word" is tapped,
                                only meaningful when at least one media URL is set)
  - questions: array of question objects  ← sealed class hierarchy in Dart (TextInputQuestion,
                                            MultipleChoiceQuestion, WordOrderQuestion)
    - questionId: string (client-generated unique ID)
    - prompt: string? (optional label shown above the question)
    - type: string ('text_input' | 'multiple_choice' | 'word_order')
    - content: object (shape varies by type; answer fields are nullable so templates reuse this model)
  - templateId: string? (optional, reference to Card Template used to create this card)
  - nativeLanguage: string? (optional, ISO 639-1 code for the user's reading language, e.g. 'en')
  - targetLanguage: string? (optional, ISO 639-1 code for the language being studied, e.g. 'es')
  - tags: string[] (normalized tag names from the global `tags` collection; default empty)
  - createdAt: timestamp
  - updatedAt: timestamp
  - createdBy: userId
```
Note: legacy documents written before the unification may use a `fields` key instead of `questions`. `FlashCard.fromFirestore` reads `questions ?? fields` for backward compatibility.
Set membership is tracked in `setCards` (see Card-Set Relationship below), not on the card document itself.

**Read permissions:** Card reads are open to any authenticated user. Card IDs are not guessable, and future sharing and marketplace features require that a user who has legitimately obtained a card ID (e.g. from a shared or subscribed set) can read it. Write operations (create, update, delete) remain restricted to the `createdBy` user. The security rule uses `.get('createdBy', request.auth.uid)` as a fallback for legacy documents that predate this field.

**Media lifecycle:** When a card is deleted, `firebase_card_repository` fetches the card document first, deletes both Storage files (if present) via `refFromURL`, then removes all `setCards` links and the card document in a Firestore batch. Deletion errors on Storage files are logged as warnings and do not block the card deletion.

#### Card Language Pair

Each card (and each set) carries an optional language pair: **`nativeLanguage`** (the user's reading language) and **`targetLanguage`** (the language being studied). Both are ISO 639-1 two-letter codes (e.g. `'en'`, `'es'`, `'ja'`).

**Design decision — language on the card, not inferred from content:** A user learning multiple languages will create cards and sets in different target languages. Tagging the card itself (rather than relying on set membership) makes each card self-describing — a card remains correctly identified even if it appears in multiple sets or in a future auto-generated "Review" set. The same pair is also stored on the set as a default for new cards.

**Default inheritance when creating a card:**
1. If the card is created from inside a set (future set-level creation flow), it inherits the set's language pair.
2. If the card is created in the Cards section (no parent set), it inherits from the last card created this session.
3. If neither applies (first card this session), the pickers default to "Not set" and the user fills them in.

**UI:** A `LanguagePicker` widget opens a searchable bottom sheet listing 74 ISO 639-1 languages. The user can filter by typing either the language name (e.g. "Spanish") or its code (e.g. "es"). Current selection is highlighted; "Not set" is always available at the top. The session-level default is stored in `lastUsedLanguagesProvider` (in-memory, not persisted across app launches).

**Future use:** Language pair will be used to filter study sessions by language (e.g. "only study Spanish cards"), to group cards in auto-generated Review/problem sets, and to display correctly in a future marketplace where content is discoverable by target language.

**Templates do not carry a language pair.** Templates define field structure only; the language is a property of the content (card or set), not the structure.

#### Card Templates

Card Templates define a reusable question structure for Flash Cards. A template stores the full `questions` array (type, prompt, options, hint, exactMatch, etc.) but with answer fields left null — correct answers are filled in per card. Firestore schema:

```
templates/{templateId}
  - createdBy: userId
  - name: string
  - description: string?
  - primaryWordHidden: boolean (inherited by cards created from this template)
  - questions: array (same CardQuestion structure as cards; answers null)
  - createdAt: timestamp
  - updatedAt: timestamp
```

Users can create a Card Template from scratch, or save any existing card's question structure as a template (answers are cleared). Applying a template to a card in the editor replaces all current questions (with confirmation) and pre-populates the structure for the user to fill in.

#### Question Templates

Question Templates define a reusable single question — one `CardQuestion` with its structure and config (options, hint, displayMode, etc.) but with answer fields null. They are separate from Card Templates and serve a different purpose: a Card Template replaces an entire card's question set, while a Question Template appends one question without affecting anything else. Firestore schema:

```
questionTemplates/{templateId}
  - createdBy: userId
  - name: string
  - description: string?
  - question: CardQuestion (single question; answers null)
  - templateId: string? (optional user-defined Import ID; must be unique per user if set)
  - createdAt: timestamp
  - updatedAt: timestamp
```

**Import ID (`templateId` field):** Users can assign a short slug (e.g. `gender`) to a Question Template. This allows import files to reference the template using the `##` prefix instead of repeating the full question definition (see [Import Shorthand](#import-shorthand)). The slug must be unique across the user's question templates; only alphanumeric characters, hyphens, and underscores are allowed.

**Usage in the card editor:** The "Use Template" bottom sheet has two tabs — Card Templates and Question Templates. Selecting a Question Template appends the question to the card's current list; it never replaces existing questions and requires no confirmation.

**Usage in the Card Template editor:** A "Use Template" button alongside "Add Question" opens a Question Template picker. The selected question is appended to the template's question list with a fresh ID.

#### Template Usage Workflow
1. User creates/selects a Card Template with questions: [Gender (MC), Example (text input)]
2. When creating a new card, user taps "Use Template" → Card Templates tab → picks a template
3. Form pre-populates with template questions (structure and config carried over, answers blank)
4. User fills in correct answers for each question
5. Card is saved with the completed question structure

Alternatively, user taps "Use Template" → Question Templates tab to append one question at a time.

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
- Hard delete: Storage files (image, audio) are fetched and deleted first, then all `setCards` join documents are removed and the card document itself is deleted in a Firestore batch
- Deletion errors on Storage files are logged as warnings and do not block the Firestore deletion

### Implementation Notes
- Field type icon/visual indicator on card display during study
- Consider rich text support for answers (bold, italic, etc.) - for future consideration
- Text input validation: case-insensitive by default, but option to require exact match
- Multiple choice: randomize option order on each study session (optional)
- Template management: CRUD operations on templates
- Consider providing default/example templates for common languages
- Cloud Firestore indexes needed for efficient card queries by set and user

---

## Workbook Cards

### Overview

Workbook Cards are a second card type alongside Flash Cards. Where a Flash Card centres on a single vocabulary item (word → translation reveal), a Workbook Card presents a descriptive prompt followed by one or more structured questions — similar to a short exercise in a language workbook or a DuoLingo challenge. A single workbook card can test multiple related concepts in one interaction.

Workbook Cards live in a separate Firestore collection (`workbookCards/`) and have their own data model. Sets can contain a mix of Flash Cards and Workbook Cards.

---

### Card Structure

A Workbook Card has two visible sections during study:

1. **Prompt** — a plain-text block describing the task (e.g. *"Read the sentence and answer the questions below"*). Shown alone on first view. The user taps **Next** to skip the card entirely, or **More** to expand the questions.

2. **Questions** — all revealed at once when **More** is tapped. Users can work through them in any order and revisit earlier ones. Three question types are supported.

---

### Question Types

#### 1. Text Input

User types a free-text answer, taps **Check**, and receives correct/incorrect feedback. Accepted answers are an ordered list; any match is a pass.

Content fields: `correctAnswers: List<String>`, `hint: String?`, `exactMatch: bool` (default false = case-insensitive).

Identical validation semantics to the `text_input` field on Flash Cards.

---

#### 2. Multiple Choice

User selects one option and taps **Check**. Two display modes let the card author choose between readability and compactness:

| Mode | When to use |
|---|---|
| `list` | Full-width vertical buttons — best for longer option text |
| `chips` | Wrapping chip row — best for short options (single words, short phrases) |

Content fields: `options: List<String>`, `correctIndex: int`, `displayMode: 'list' \| 'chips'`, `explanation: String?`.

---

#### 3. Word Order *(new)*

User assembles an answer by tapping word tiles from a bank. Tapping a tile moves it to an answer row above the bank; tapping a placed tile returns it to the bank. When the user taps **Check**, the assembled sequence is compared against `correctOrder`.

**Word bank design:** The author populates `wordBank` with all available tiles. This can be exactly the words needed (simpler) or include distractor words (harder). The subset of tiles that forms the correct answer is `correctOrder`.

**Prompt:** An optional per-question instruction string (e.g. *"Put these words in the correct order"*) displayed above the bank. Plain text only — inline blank-slot rendering where tiles slot into the prompt text is a future enhancement deferred until user feedback warrants it.

**Evaluation:** Exact sequence match of assembled tiles against `correctOrder`. Case-sensitive (consistent with existing `exactMatch: true` behaviour; a future option can relax this per-question).

Content fields: `wordBank: List<String>`, `correctOrder: List<String>` (non-empty subset of `wordBank`).

---

### Study Flow

1. The study session screen detects card type from `cardTypeMap` (see Session Integration below).
2. For a Workbook Card, the primary view shows only the **prompt** — there is no word/translation reveal.
3. **More** reveals all questions simultaneously. Users can answer in any order.
4. **Skip / Review** marks work identically to Flash Cards — one mark per card for the whole card.
5. Per-question pass/fail is tracked in `questionResults` using the same `{cardId}_{questionId}` key pattern used for Flash Card fields.

---

### Data Model (Firestore)

```
workbookCards/{cardId}
  prompt: string                  ← task description shown before questions expand
  questions: array                ← ordered list of WorkbookQuestion maps
    questionId: string            ← client-generated unique ID (same pattern as fieldId)
    type: string                  ← 'text_input' | 'multiple_choice' | 'word_order'
    prompt: string?               ← optional per-question label / instruction
    content: map                  ← shape varies by type (see below)
  tags: string[]
  nativeLanguage: string?         ← ISO 639-1 code
  targetLanguage: string?         ← ISO 639-1 code
  createdAt: timestamp
  updatedAt: timestamp
  createdBy: userId
```

**`content` shapes by question type:**

```
text_input:
  correctAnswers: string[]        ← one or more accepted answers
  hint: string?                   ← shown before the user answers
  exactMatch: bool                ← false = case-insensitive (default)

multiple_choice:
  options: string[]               ← option strings
  correctIndex: int               ← index of the correct option
  displayMode: string             ← 'list' | 'chips'
  explanation: string?            ← revealed after answering

word_order:
  wordBank: string[]              ← all available tiles (correct + optional distractors)
  correctOrder: string[]          ← expected answer; ordered subset of wordBank
```

---

### Set Membership and Mixed Sets

The `setCards` join document gains a `cardType` field (`'flashcard'` | `'workbook'`) so the study engine and set-detail screen know which Firestore collection to load each card from. Existing `setCards` documents without this field are treated as `'flashcard'` (backward compatible — no migration required).

---

### Session Integration

`StudySession` gains an optional `cardTypeMap: Map<String, String>` field (cardId → `'flashcard'` | `'workbook'`). Sessions without this field treat all cards as `'flashcard'` (backward compatible). All existing session fields — `cardSequence`, `cardProgress`, `cardMarks`, statistics — are unchanged.

---

### Implementation Notes

- `WorkbookQuestion` uses the same sealed-class pattern as `CardFieldContent`: adding a new question type means adding one subclass and updating `fromJson`/`toJson`; no other code changes required.
- The word order interaction (tile bank + answer row) is a self-contained stateful widget; the check/feedback cycle follows the same pattern as `_OptionButton` in the existing study screen.
- Multiple choice chips mode reuses the existing options data; `displayMode` is a rendering hint only — no change to validation logic.
- Workbook Cards do not have `primaryWord` / `translation` fields. They cannot be created from a card template (templates are Flash Card structures). A future "workbook template" concept is possible but not planned for MVP.
- Media attachments (images, audio) on a Workbook Card are not supported in the initial implementation. The prompt and question prompts are plain text.

---

See [implementation roadmap — Phase 3e](implementation-roadmap.md) for the full task breakdown.

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
  - cardCount: integer (denormalized counter; increment/decrement on setCards link create/delete)
  - acquisitionCount: integer (denormalized counter; incremented each time the set is acquired
                               via clone or subscription — never decremented)
  - createdAt: timestamp
  - updatedAt: timestamp
  - isPublic: boolean (default false; true means the set appears in the Market tab)
  - tags: array<string> (optional, for organization: ["verbs", "regular"])
  - color: string (optional, for UI differentiation)
  - nativeLanguage: string? (optional, ISO 639-1 code; inherited by cards created within this set)
  - targetLanguage: string? (optional, ISO 639-1 code; inherited by cards created within this set)
```

#### Set Description Format
The `description` field stores **Markdown** text. It is intended as a short intro or summary written by the set author — covering what a student will learn, helpful hints, prerequisites, etc.

- Stored as a plain markdown string in Firestore
- Rendered using `flutter_markdown` in the set detail and study selection views
- Edited using a `TextFormField` with a formatting toolbar (Bold, Italic, Bullet List, Heading buttons that insert markdown syntax at the cursor)
- Users who know markdown can type it directly; the toolbar makes it accessible to those who don't

```

setCards/{linkId}                 ← many-to-many join collection
  - setId: string
  - cardId: string
  - userId: string                ← owner; used in security rules
  - cardType: string              ← 'flashcard' | 'workbook'; legacy documents without this field are treated as 'flashcard'
  - addedAt: timestamp
```

#### Card-Set Relationship
- **Many-to-Many**: One card can belong to multiple sets; one set contains many cards
- **Implementation**: Dedicated `setCards` join collection (not `cardIds[]` array on sets)
- **Rationale**: Firestore documents cap at 1 MB — an embedded array breaks at scale. The join collection also enables efficient bi-directional queries: all cards in a set (`where setId == x`) and all sets containing a card (`where cardId == x`).
- **Indexes**: Composite index on `(setId, addedAt)` for set detail view; `(cardId, addedAt)` for card-membership queries

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
- User selects one or more existing cards (Flash Cards and/or Workbook Cards)
- Create a `setCards` join document for each card (`{setId, cardId, userId, cardType, addedAt}`)
- Increment the `cardCount` counter on the set document
- Cards can be added from: create card flow, card browser, or bulk operations

**Remove Cards from Set:**
- User selects card(s) to remove
- Delete the corresponding `setCards` join document(s)
- Decrement the `cardCount` counter on the set document
- Card itself is not deleted, just removed from this set

**Delete Set:**
- User confirms deletion
- Hard delete: all `setCards` join documents for this set are removed first, then the set document is deleted
- Cards remain intact — individual cards are unaffected; only the set membership is removed

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
- Denormalize `cardCount` for quick display without a collection count query
- Index on `userId + createdAt` for efficient "My Sets" queries
- Consider pagination for users with many sets
- UI shows set colour accent, tags, and relative last-modified date

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

## Tag System

### Overview

Tags serve two distinct purposes that must be satisfied by a single architecture:

1. **Personal organisation** — users label their cards and sets for filtering and quick retrieval within their own library (e.g., find all sets tagged "beginner" or all cards tagged "irregular-verbs").
2. **Marketplace discovery** — when the content marketplace launches, tags become the primary cross-user discovery mechanism. A user searching for language content should find every set tagged "spanish-verbs" regardless of who created it.

These two requirements preclude a per-user tag namespace. If every user maintains their own isolated tag list, tags fragment across the user base ("spanish-verbs", "Spanish Verbs", "SpanishVerbs", "verbos-español") and marketplace tag search returns only a fraction of the relevant content. The correct architecture is a **single global tag pool with normalization**, designed now so that no migration is needed when the marketplace feature is built.

### Design Decision: Global Normalized Tags

Tags are stored in a top-level `tags` Firestore collection, shared across all users. The document ID is the **normalized form** of the tag name. Normalization rules:

1. Lowercase
2. Trim leading and trailing whitespace
3. Collapse runs of whitespace to a single hyphen

Examples:
| User input | Normalized (document ID) | Stored displayName |
|---|---|---|
| `Spanish Verbs` | `spanish-verbs` | `Spanish Verbs` |
| `spanish verbs` | `spanish-verbs` | `Spanish Verbs` ← first user's casing wins |
| `spanish-verbs` | `spanish-verbs` | ← no-op, document already exists |
| `SPANISH  VERBS` | `spanish-verbs` | ← no-op |

Because the document ID equals the normalized tag, `setDoc(..., merge: true)` on the same document ID is naturally idempotent — creating a duplicate is impossible by construction.

The `displayName` field is set only on document **creation** (first user to coin the tag). Subsequent writes only increment `usageCount`.

### Firestore Data Model

```
tags/{normalizedName}
  normalizedName: string   ← duplicated from document ID for prefix-query support
  displayName:   string    ← original casing from first user to coin the tag
  usageCount:    int       ← sum of all references across all cards, sets, and future content types
  createdAt:     timestamp
  createdBy:     userId    ← who first coined this tag
```

Cards and sets store the **normalized** form in their `tags` array:

```
cards/{cardId}
  tags: ["spanish-verbs", "irregular", "ar-verbs"]   ← normalized names only

sets/{setId}
  tags: ["beginner", "spanish-verbs"]                ← normalized names only
```

This means all tag-based queries (`where('tags', arrayContains: 'spanish-verbs')`) work identically whether filtering a single user's cards or searching the global marketplace.

### Tag Lifecycle

#### Adding a tag

When a user adds a tag to any content object (card or set):

1. Normalize the input string.
2. Call `tags/{normalizedName}` with `setDoc(..., merge: true)`:
   - If the document does not exist: create it with `displayName`, `usageCount: 1`, `createdAt`, `createdBy`.
   - If it exists: increment `usageCount` by 1 only (do not overwrite `displayName`).
3. Add the normalized tag to the content object's `tags` array.

Both writes should be batched or run as a transaction to stay consistent.

#### Removing a tag

When a user removes a tag from a content object:

1. Remove the normalized tag from the content object's `tags` array.
2. Decrement `usageCount` on `tags/{normalizedName}` by 1.

The tag document is **not deleted** when `usageCount` reaches zero. Orphaned tags (those no longer used anywhere) are harmless — they appear as low-ranked suggestions but will never surface above popular tags because suggestions are sorted by `usageCount` descending.

#### Editing content (tags changed)

When a user saves an edit and the `tags` array has changed:

1. Compute `added = newTags − oldTags` and `removed = oldTags − newTags`.
2. For each tag in `added`: run the "adding a tag" flow above.
3. For each tag in `removed`: run the "removing a tag" flow above.
4. Save the content document with the new `tags` array.

This logic lives in the form save methods and must be applied consistently across `CardFormScreen`, `SetFormScreen`, and any future content types.

### Autocomplete Behaviour

The tag input widget queries the global `tags` collection as the user types:

```dart
_firestore
  .collection('tags')
  .where('normalizedName', isGreaterThanOrEqualTo: normalizedInput)
  .where('normalizedName', isLessThanOrEqualTo: normalizedInput + '')
  .orderBy('normalizedName')
  .limit(10)
```

Suggestions are presented as the `displayName` values of the returned documents. Selecting a suggestion inserts the `normalizedName` into the `tags` array (not the display name, to maintain storage consistency).

If the user presses Enter on a string that matches no suggestion, a new tag is created (the "adding a tag" flow above).

A **minimum suggestion threshold** of `usageCount >= 2` is applied client-side when filtering the suggestion list. This suppresses one-off typos from polluting other users' autocomplete results while still showing low-count tags to the user who created them (they will see their own tags even if they fall below the threshold).

### Security Rules

```javascript
match /tags/{tagId} {
  // Anyone authenticated can read tags (required for autocomplete and marketplace search).
  allow read: if isAuth();

  // Any authenticated user can create a new tag.
  allow create: if isAuth()
      && request.resource.data.createdBy == request.auth.uid
      && request.resource.data.usageCount == 1;

  // usageCount increments and decrements only; displayName and createdBy are immutable.
  allow update: if isAuth()
      && request.resource.data.displayName == resource.data.displayName
      && request.resource.data.createdBy  == resource.data.createdBy
      && request.resource.data.normalizedName == resource.data.normalizedName;

  // Tags are never hard-deleted by clients.
  allow delete: if false;
}
```

### Firestore Indexes Required

| Collection | Fields | Purpose |
|---|---|---|
| `tags` | `normalizedName ASC` | Prefix autocomplete queries |
| `tags` | `usageCount DESC` | Popularity-sorted suggestions (future) |
| `cards` | `createdBy ASC, tags ARRAY` | Filter user's cards by tag |
| `sets` | `userId ASC, tags ARRAY` | Filter user's sets by tag |

Composite array-contains indexes are created automatically by Firestore for `arrayContains` queries; the explicit index entries above are for multi-field combinations used in the filter UI.

### Bloat Analysis and Mitigations

With a global tag pool, the realistic bloat concerns and their mitigations are:

| Concern | Assessment | Mitigation |
|---|---|---|
| Duplicate tags with different casing ("Spanish Verbs" vs "spanish verbs") | Eliminated | Normalization — all variants resolve to the same document ID |
| Typos ("spannish-verbs") | Low impact | Suggestions sorted by `usageCount`; typos have count=1 and sink below popular tags; `usageCount >= 2` threshold hides them from other users |
| Language fragmentation ("verbos", "slovesa", "Verben") | Not a problem | Legitimately distinct tags in a multilingual app; good for marketplace discovery |
| Orphaned tags (content deleted, usageCount drifts toward 0) | Harmless | Low-count tags don't surface in autocomplete; no active cleanup needed at MVP scale |
| Spam or malicious tags | Low at MVP scale | Security rules prevent deletion; usageCount controls ranking; active moderation deferred to marketplace launch |
| Scale (millions of users, millions of tags) | Not a near-term concern | Firestore document count does not affect read performance; tag documents are tiny; compound queries on `tags` array scale with index size, not tag count |

Active tag pruning (deleting orphans) is explicitly deferred. If it becomes necessary post-marketplace-launch, it can be implemented as a Cloud Function triggered on document writes, or as a scheduled cleanup job.

### UI Components

#### TagInputField (shared widget)

A reusable `TagInputField` widget (`lib/widgets/tag_input_field.dart`) replaces the former ad-hoc chip-input pattern on `CardFormScreen`, `SetFormScreen`, and `WorkbookCardFormScreen`. It encapsulates:

- A `TextField` that queries the global `tags` collection (debounced ~300ms; the query state only updates 300ms after the last keystroke so a new Firestore listener isn't opened per character)
- An inline suggestion list showing up to 10 matching `displayName` results, each with its `usageCount`
- Threshold filtering: a suggestion is shown if `usageCount >= 2` **or** it was created by the current user (so users always see their own tags, even one-offs, while other users' typos stay hidden)
- Enter (or the `+` button) to commit the current input as a tag; comma-paste splits into multiple tags
- Chip display of already-added tags with delete affordance

The parent owns the tag list — the widget calls `onChanged` with the new list on every add/remove. Persisting tags and running the upsert/decrement lifecycle hooks remains the parent screen's responsibility (see Phase 4d-3).

#### Display

New tags are **normalized at input time** and stored in their normalized form, so chips display the canonical value (e.g. `spanish-verbs`). This keeps what the user sees identical to what is stored and to the `tags/{normalizedName}` document ID. Pre-existing un-normalized tags on older content are displayed as-is and converge to normalized form on the next save. Resolving and displaying the prettier `displayName` per chip (via a cached tag map) is a possible future refinement, deferred to avoid per-chip Firestore reads.

### Import / Export Considerations

The ZIP export format stores tags in their normalized form in `cards.json`:

```json
"tags": ["spanish-verbs", "irregular", "ar-verbs"]
```

On import, each tag is run through the "adding a tag" flow above — either creating a new global tag document or incrementing an existing one. This means importing a set from another user propagates their tags into the global pool, which is the desired behaviour for marketplace content sharing.

See [implementation roadmap — Phase 4d](implementation-roadmap.md) for the full task breakdown. This phase is deferred to after Phase 5 (Study Mode).

---

## Import and Export Flash Card Sets

### Overview
Users can share and backup their card sets by importing and exporting them in standard formats. Both single sets and bulk operations are supported.

### Requirements
- Export sets as self-contained ZIP archives (JSON + media)
- Import sets from ZIP archives
- Support for exporting single sets or multiple sets
- Support for importing into new sets or merging into existing sets
- Bulk import (multiple ZIP files at once)
- Comprehensive error handling and validation
- Clear feedback on import success/failure

### Design Details

#### Export Functionality

**Export Format: ZIP Archive**

Each exported set is a self-contained ZIP file containing:
- `cards.json` — card definitions with relative paths for any media assets
- `media/` — folder containing any image/audio files referenced by the cards

```
spanish-verbs-export.zip
├── cards.json
└── media/
    ├── hablar.mp3
    └── hablar.png
```

`cards.json` structure:
```json
{
  "version": "1.0",
  "exportDate": "2026-05-01T10:30:00Z",
  "set": {
    "name": "Spanish Verbs",
    "description": "Regular and irregular verbs",
    "tags": ["verbs", "regular"],
    "color": "#FF5733",
    "nativeLanguage": "en",
    "targetLanguage": "es",
    "cards": [
      {
        "primaryWord": "hablar",
        "translation": "to speak",
        "primaryImageUrl": "media/hablar.png",
        "primaryAudioUrl": "media/hablar.mp3",
        "primaryWordHidden": false,
        "nativeLanguage": "en",
        "targetLanguage": "es",
        "questions": [
          {
            "prompt": "Conjugation (yo)",
            "type": "text_input",
            "content": { "correctAnswers": ["hablo"], "hint": "Present tense" }
          },
          {
            "prompt": "Type",
            "type": "multiple_choice",
            "content": {
              "options": ["Regular", "Irregular", "Reflexive"],
              "correctIndex": 0
            }
          }
        ]
      }
    ]
  }
}
```

**JSON format notes:**
- The `questions` key replaced the legacy `fields` key; both are accepted on import for backward compatibility.
- Trailing commas before `]` or `}` are tolerated in hand-authored files.
- Exported ZIPs include all of the exporting user's Card Templates and Question Templates as top-level `cardTemplates` and `questionTemplates` arrays. Example top-level structure:

```json
{
  "version": "1.0",
  "exportDate": "2026-06-07T00:00:00.000Z",
  "cardTemplates": [
    {
      "name": "Spanish Verb",
      "questions": [
        { "type": "text_input", "prompt": "1st person", "content": { "hint": null, "exactMatch": false } }
      ]
    }
  ],
  "questionTemplates": [
    {
      "name": "Gender",
      "templateId": "gender",
      "question": {
        "type": "multiple_choice",
        "prompt": "Gender",
        "content": { "options": ["MA", "MI", "F", "N"] }
      }
    }
  ],
  "sets": [ ... ]
}
```

Both arrays are omitted when empty. Templates are stripped of Firestore IDs and ownership fields; the importer assigns fresh IDs and sets `createdBy` to the importing user's UID.

#### Import Shorthand for Question Templates { #import-shorthand }

Instead of repeating a full question definition in every card, a hand-authored import file can reference a Question Template by its Import ID using the `##` prefix:

```json
{
  "template": "##gender",
  "correctIndex": 2
}
```

The `##` prefix signals a template reference. The value after `##` must match the `templateId` field of one of the importing user's Question Templates. The importer resolves the reference at parse time, merging the template's question structure with any answer-field overrides provided inline (`correctIndex`, `correctAnswers`, `correctOrder`, `wordBank`). If the referenced template is not found the import fails immediately with a descriptive error.

This shorthand is an alternative to the full question definition — both forms can appear in the same `questions` array and in the same file.

**Rationale for ZIP format:** Firebase Storage download URLs are user-scoped and non-portable. Bundling media files inside the ZIP makes sets fully self-contained for sharing and bulk creation — the recipient imports one file and gets cards plus all media. JSON handles all field types (including multiple choice options and correct indices) natively without representational compromises.

**Export Workflow:**
1. User navigates to "My Sets"
2. Selects a set to export
3. System downloads media files from Firebase Storage, writes `cards.json` with relative `media/` paths
4. Packages everything into a ZIP named `[set-name]-export.zip`

**Export Considerations:**
- Include all cards in set with all field types and content
- Include set metadata (name, description, tags, color)
- Include version number for future compatibility
- Include all of the user's Card Templates and Question Templates as top-level arrays (not filtered to only referenced templates)

#### Import Functionality

**Import Formats Supported:**
- ZIP archive containing `cards.json` plus `media/` folder (Flash Me standard format)

**Import Workflow:**
1. User navigates to "Import Sets"
2. Selects a `.zip` file from device
3. System extracts and validates the archive structure
4. Preview dialog shows:
   - New Card Templates and Question Templates that will be created (collapsible, with name, type, and Import ID)
   - Number of sets to import / per-set card changes
   - Any validation warnings/errors
5. User can:
   - Proceed with import (creates new sets)
   - Edit set names before import
   - Choose to merge with existing set (optional)
6. System creates any new templates first, then set(s) and cards in Firestore
   - Card Templates deduped by name; Question Templates deduped by Import ID (then name)
   - Existing templates are left unchanged; only genuinely new ones are created
7. Success confirmation with import summary (cards and templates created)

**Data Validation During Import:**
- ZIP structure check (contains `cards.json`)
- JSON schema validation
- Required fields check (primaryWord, translation, field names)
- Field type validation (reveal, text_input, multiple_choice)
- Text input: verify correctAnswers array is non-empty
- Multiple choice: verify options array and correctIndex are valid
- Encoding check (UTF-8)
- File size limit (10 MB)

**Error Handling:**
- **Invalid JSON**: Reject file, show parse error
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
| File too large | Reject with size limit message |
| Duplicate set name in import | Append suffix or allow user to rename |
| Special characters in content | Preserve and encode properly |

#### Workbook Card Support

Both single-set and bulk ZIP exports include Workbook Cards alongside Flash Cards. The `cards.json` format uses the same top-level structure; Flash Cards and Workbook Cards are stored in separate arrays within each set object:

```json
{
  "version": "1.0",
  "set": {
    "name": "...",
    "cards": [ ... ],
    "workbookCards": [ ... ]
  }
}
```

On import, cards in `workbookCards` are written to the `workbookCards/` Firestore collection with `createdBy` set to the importing user. All validation and diff logic applies to workbook cards using `prompt` as the identity key (equivalent to `primaryWord` for Flash Cards).

### Implementation Notes
- Use `archive` package for ZIP creation/extraction in Dart
- Validate JSON schema against expected structure before processing
- Use UTF-8 encoding for all files
- Display detailed import report showing what was imported and any issues
- Archive/backup integration: users can schedule automatic exports (future)

See [implementation roadmap — Phase 6](implementation-roadmap.md) for the full task breakdown (6a export, 6b import core, 6c bulk export).

---

## Study Tab & Study Modes

### Overview

Study is the core use case of Flash Me. Rather than being a secondary action buried inside a set's detail screen, it lives as a first-class tab in the main navigation bar (centre position: **Sets | Cards | Study | Templates | Profile**).

### Study Mode Cards

The Study tab home displays a card for each available study mode. Modes that are not yet implemented are shown in a disabled state with a "Soon" badge — the UI scales to new modes without structural changes.

| Mode | Status | Description |
|---|---|---|
| **Study a Set** | Available | Choose a set from a bottom-sheet picker; proceeds to the session setup screen |
| **Study Review** | Coming soon | Study only cards the user has flagged with the Review mark |
| **Study Mistakes** | Coming soon | Drill questions the user has answered incorrectly in recent sessions |

### Set Picker Flow

Tapping "Study a Set" opens a `DraggableScrollableSheet` listing all the user's sets (name, card count, colour accent). Tapping a set navigates to `StudySetupScreen` which handles the Resume/New Session choice and shuffle toggle.

### Quick-Study Shortcut

The Set Detail screen retains a play-circle icon in the AppBar that navigates directly to `StudySetupScreen` for that set — bypassing the Study tab set picker for users who arrive at a set and want to study immediately.

### Future Modes

"Study Review" and "Study Mistakes" will be implemented once sufficient `cardMarks` and `questionResults` data exists to make them meaningful. Each mode generates a synthetic card set at session start (filtered from the user's full card library) and passes it to the existing `StudySetupScreen` + `StudySessionScreen` pipeline.

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
- Mark cards as Skip or Review
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
  - cardTypeMap: map<cardId, string> (cardId → 'flashcard' | 'workbook'; absent for sessions created before Workbook Card support — missing entries default to 'flashcard')
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
│  │ hablar                          │ │ Phase 1: tap reveals translation
│  │ 👆 Tap to reveal                │ │
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
│ ◀ Previous    [Review] [Skip]       │
│                              Next ▶  │
└─────────────────────────────────────┘
```

**Primary Field Display (Three-Phase Reveal):**

The primary field reveal is a three-step progression that keeps the word visually stable while progressively exposing more content:

- **Phase 1 — Word shown:** Primary word displayed prominently; a "Tap to reveal" hint appears beneath it. Additional fields are not yet visible.
- **On tap → Phase 2 — Translation revealed:** The translation fades in below the word in-place (the word does not move). Two buttons appear:
  - **NEXT** — advance to the next card without interacting with any additional fields and without marking the card.
  - **MORE** — expand to the full card view.
- **Phase 3 — Fully revealed:** All additional fields slide in and become interactive. Skip / Review mark buttons in the navigation bar become active. The user can answer text input and multiple choice fields, and mark the card.
- Not timed; the user controls each reveal step.

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

- **Skip Button** (amber, check-circle): Mark current card as known / skip in future
  - Flag card in cardProgress; also persisted globally in `cardMarks`
  - Can toggle on/off; mutually exclusive with Review
  
- **Review Button** (green, flag): Mark current card for focused follow-up
  - Flag card in cardProgress; also persisted globally in `cardMarks`
  - Can toggle on/off; mutually exclusive with Skip

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
- Riverpod for state management during study session
- Auto-save to Firestore after each navigation action (debounced ~1 s to reduce write volume)
- Text input validation: case-insensitive by default; respect `exactMatch` flag per field
- Multiple choice: option order as authored (randomization is a future option)
- Session history queries: index on `userId + setId + startTime`
- Offline support: deferred post-MVP

See [implementation roadmap — Phase 5](implementation-roadmap.md) for the full task breakdown.

---

## User Performance Tracking

### Overview

Flash Me tracks two complementary signals of user performance to enable future adaptive study features:

1. **User-initiated marks (Skip / Review)** — explicit, per-card judgements made by the user during study. Durable across sessions; represent the user's own assessment of each card.
2. **Question result history** — automatic, per-field recordings of success and failure on interactive questions. Capture objective performance data over time.

Together these signals will power future filtered study modes — for example, "study only cards marked Review" or "study only cards where I've failed the conjugation question recently."

---

### User-Initiated Card Marks (Skip / Review)

#### Behaviour

After a card is fully revealed (user has tapped **More**), two mark buttons appear in the navigation bar:

- **Skip** (check-circle, amber): "I know this card — skip it in future."
- **Review** (flag, green): "I need more practice — prioritise this card."

Tapping the active button a second time **clears** the mark. The two marks are mutually exclusive — activating one while the other is set switches to the new one. Marks are intentionally separate from the session's counter totals; they are a durable cross-session signal rather than a per-session statistic.

#### Data Model

```
users/{userId}/cardMarks/{cardId}
  mark:       string    — 'skip' | 'review'
  markedAt:   timestamp — when the card was first marked (preserved on updates)
  updatedAt:  timestamp — when the mark was last changed
```

`cardId` is used as the document ID for O(1) lookup and natural upsert semantics — writing the same document ID simply replaces the previous mark.

#### Future Use

- Filter study sessions to show only **Review** cards
- Filter study sessions to exclude **Skip** cards
- Per-set dashboard row showing how many cards are in each mark state

---

### Automatic Question Result Tracking

#### What Is Tracked

Every time a user answers an interactive field during study, the outcome is recorded automatically:

| Field type | Trigger | Recorded outcome |
|---|---|---|
| `text_input` | User taps **Check** | `success` if answer matches `correctAnswers`; `fail` otherwise |
| `multiple_choice` | User selects an option | `success` if selected index matches `correctIndex`; `fail` otherwise |
| `reveal` | User taps to reveal | **Not tracked** — passive field with no checkable outcome |

A **Try Again** on a text input generates a second result entry if the user re-checks — the full attempt history is captured.

#### Rolling Window

Each field stores the **last 5 results**, newest-first, padded with `'unseen'` until the field has been answered 5 times:

```
['success', 'fail', 'unseen', 'unseen', 'unseen']
  ↑ most recent                           ↑ oldest / not yet attempted
```

When a new result arrives it is prepended and the oldest entry is dropped. This gives a compact, time-ordered snapshot of recent performance without unbounded storage growth.

#### Data Model

```
users/{userId}/questionResults/{cardId}_{fieldId}
  cardId:     string         — owning card
  fieldId:    string         — which field on the card
  fieldName:  string         — human-readable label, e.g. "Conjugation (yo)"
  fieldType:  string         — 'text_input' | 'multiple_choice'
  results:    array<string>  — 5 entries, newest first; values: 'success' | 'fail' | 'unseen'
  updatedAt:  timestamp
```

The document ID `{cardId}_{fieldId}` (two Firestore auto-IDs joined with an underscore) enables an efficient **prefix range query** to fetch all results for a given card without a composite index:

```dart
.where(FieldPath.documentId, isGreaterThanOrEqualTo: '${cardId}_')
.where(FieldPath.documentId, isLessThan:             '${cardId}_￿')
```

#### Future Use

- Identify cards where a specific field has been failed repeatedly (e.g. 4 of last 5 = `fail`)
- Filter study sessions to include only cards with at least one recent `fail`
- Surface weak-spot analysis: "You consistently struggle with gender questions"
- Provide input data for a future spaced-repetition scheduler

---

## Marketplace MVP (Alpha 0.2) { #marketplace-mvp }

> **Status: Designed, implementation in sub-phases Mk-1 through Mk-5.**
> This section covers the Alpha 0.2 slice of marketplace functionality: publish, browse, and clone. Subscriptions, ratings, and moderation are deferred to the full marketplace (Beta 0.1).

### Overview

Creators can offer their sets in the Market. Other users can browse public sets and clone them into their own library. Clones are fully independent — the cloner owns their copy and edits do not propagate. Subscription-based live updates are deferred to Beta 0.1.

### Firestore Data Model

#### `setAcquisitions/{id}` — new collection

Records every acquisition event across all acquisition types (clone, and future: subscription, purchase).

```
setAcquisitions/{id}
  acquiredByUserId:  string     ← user who acquired the set
  originalSetId:     string     ← the market set (source of truth)
  originalUserId:    string     ← the creator
  acquiredSetId:     string     ← the resulting set in the acquirer's library
  acquisitionType:   string     ← 'clone' | 'subscription' (extensible)
  acquiredAt:        timestamp
```

Query patterns:
- **Creator report** — who/how many acquired my set: `where('originalSetId', ==, id)`
- **Acquirer history** — what a user has acquired: `where('acquiredByUserId', ==, uid)`
- **More from this creator** — read `originalUserId` from any record, query `sets` where `userId == originalUserId && isPublic == true`

`acquisitionCount` on the `CardSet` document is a denormalized counter incremented on every acquisition, used for display in Market tiles without a per-tile count query. It is never decremented (acquisition count = "times acquired", not "currently in others' libraries").

### Publish / Unpublish Flow

Publishing is a dedicated action on the Set detail screen (not a field on the edit form). Tapping "Offer in Market" opens a bottom sheet listing the publication options:

| Option | Default | Notes |
|---|---|---|
| Allow Clone | On | The only supported acquisition type in Alpha 0.2 |

The bottom sheet will gain more options (subscription, pricing) in Beta 0.1.

**Un-publishing** shows the current `acquisitionCount` as a guard: *"X users have acquired this set. Un-publishing removes it from the Market but does not affect their copies."* This guard is intentional infrastructure for subscriptions — when subscribed users exist, un-publishing will have live consequences.

### Security Rules

- `sets`: read allowed for any authenticated user when `resource.data.isPublic == true`; write remains owner-only
- `setAcquisitions`: any authenticated user can create a record for themselves; read and delete restricted to the involved user IDs

### Market Tab

The Sets section is split into two tabs: **My Sets** and **Market**. The Market tab shows all public sets from all users, sorted newest-published first. Each tile shows:
- Set name, description, tags, card count, language pair
- Creator display name (from their user profile)
- Acquisition count

Filtering and search within the Market tab are deferred to Beta 0.1 (requires full-text search infrastructure).

### Clone Operation

Tapping **Clone** on a market set opens a dedicated confirmation screen (not a generic dialog — designed to accommodate preview details in future iterations). Confirming performs:

1. Create a new `CardSet` document under the cloner's `userId` (same name, description, tags, color, language pair)
2. For each card in the original set:
   - **Flash cards** — match against the cloner's library by `[primaryWord, translation]`; link existing card if found, copy (new document, `createdBy` = cloner) if not
   - **Workbook cards** — always copy (no reliable dedup key yet; universal card dedup via `cardAcquisitions` is a fast-follow in Mk-5)
3. Write a `setAcquisitions` record
4. Increment `acquisitionCount` on the original set

The cloner's set is fully editable and evolves independently. No ongoing link to the original is maintained in this phase.

#### `cardAcquisitions/{id}` — card-level provenance (Mk-5)

Records every card that is **copied** (not just linked) during a clone. Used as a universal dedup key: if a user clones a second set containing the same source card, they get their existing copy rather than a duplicate.

```
cardAcquisitions/{id}
  acquiredByUserId: string  ← cloner uid
  originalCardId:   string  ← source card document ID
  originalCardType: string  ← 'flashcard' | 'workbook'
  acquiredCardId:   string  ← resulting card in cloner's library
  acquiredAt:       timestamp
```

Flash cards that are **content-matched** against the cloner's existing library (by `[primaryWord, translation]`) are linked without a `cardAcquisitions` record — they are pre-existing library cards, not market acquisitions. A record is written only when a new card document is created.

### Indexes

```
setAcquisitions:  (originalSetId ASC, acquiredAt DESC)       ← creator report
setAcquisitions:  (acquiredByUserId ASC, acquiredAt DESC)    ← acquirer history
sets:             (isPublic ASC, createdAt DESC)              ← market browse
cardAcquisitions: (acquiredByUserId ASC, originalCardId ASC) ← dedup lookup
```

---

## Marketplace & Lessons — Long-Term Vision

> **Status: Pre-design only.** The Alpha 0.2 slice (publish + clone) is specified in [Marketplace MVP](#marketplace-mvp) above. This section documents the longer-term vision that informed early architectural decisions.

### Purpose

The marketplace allows users to publish their content — sets and lessons — for other users to discover, study, and build upon. It transforms Flash Me from a personal study tool into a collaborative learning platform.

This section exists in the design document now because several early architectural decisions are shaped by it:
- The [global tag system](#tag-system) was designed for marketplace discoverability, not just personal organisation.
- The `isPublic` flag on `CardSet` is a reserved field for this feature.
- The `setCards` join-collection approach (rather than embedded arrays) supports future content sharing patterns cleanly.

### Concepts

#### Published Sets

A set is currently always private. In the marketplace, a set owner may **publish** it, making it discoverable and usable by others. Key properties:

- Published sets are **read-only** for non-owners (content cannot be edited, but can be studied or cloned).
- The owner can unpublish a set at any time; published content already cloned by others is unaffected.
- Published sets appear in the marketplace search index.
- Metadata tracked per published set: view count, subscriber count, clone count, rating/reviews (TBD).

#### Lessons

A **Lesson** is a structured, ordered grouping of sets — analogous to a course chapter or a curriculum unit. Where a set is a flat collection of cards, a lesson imposes a learning sequence on multiple sets and may include:

- An ordered list of sets (e.g., "Week 1: Greetings → Week 2: Numbers → Week 3: Verbs")
- A title, description, and cover image
- Prerequisite tags or difficulty level
- Author attribution

Lessons are a new content type and will require their own Firestore collection (`lessons/{lessonId}`), data model, UI screens, and study flow. They are out of scope for all current phases.

#### Content Discovery

Users find marketplace content through:
1. **Tag-based browsing** — filter by one or more global tags (e.g., "spanish-verbs" + "beginner"). Works natively via Firestore `arrayContains` queries.
2. **Name/description search** — free-text search across set and lesson names and descriptions. Firestore does not support full-text search natively; this will require an external search service (Algolia, Typesense, or the Firebase Search Extension). This is the primary reason to evaluate a search service early, even though it is not needed for personal-library search at MVP scale.
3. **Popularity / trending** — sets sorted by subscriber count, clone count, or recency. Standard Firestore orderBy queries on denormalized counters.

#### Content Lifecycle

```
Draft (private) → Published (discoverable) → [Unpublished → private again]
```

Content moderation (flagging, takedowns) will be required at marketplace scale and should be designed as part of the marketplace phase, not retrofitted.

#### Subscriptions and Cloning

Two consumption patterns:

| Pattern | Description | Ownership | Default |
|---|---|---|---|
| **Subscribe** | User's library shows the original set; receives updates when owner edits | Owner retains authorship | Enabled for all public content |
| **Clone** | User gets an independent copy; free to edit; diverges from original | User becomes owner of clone | **Opt-in by creator only** |

**Subscription** is the default for all published content — any user can subscribe to any public set or lesson without the creator needing to take any action.

**Cloning** is an explicit permission granted by the creator at publish time (or toggled afterwards). A creator who allows cloning is accepting that their content may be modified and redistributed independently. Creators who want their content consumed but not forked — e.g., for quality control or pedagogical integrity — can publish without enabling cloning.

The UI should make this distinction clear on the publish settings screen: a simple toggle such as "Allow others to clone this set" defaulting to off.

Clone provenance (`clonedFromSetId`, `clonedFromUserId`) should be recorded on cloned content for attribution, regardless of whether the provenance is surfaced in the initial UI.

### Architectural Implications for Current Development

| Decision | Reason |
|---|---|
| Global normalized tags (not per-user) | Tag convergence across users is required for marketplace search to work |
| `isPublic: bool` on `CardSet` | Reserved field; set to `false` for all current content |
| `cloneable: bool` on `CardSet` | Reserved field; set to `false` by default — creator must explicitly opt in. Separate from `isPublic` because a set can be public (subscribable) without being cloneable. |
| `setCards` join collection (not embedded array) | Supports future "subscriber's view" patterns where a subscribed set's card list is derived from the owner's join collection |
| Markdown description on sets | Rich descriptions are more valuable for marketplace listings than plain text |
| `createdBy` on cards and templates | Attribution field; needed for marketplace provenance display |

### Full-Text Search Consideration

At marketplace scale, users need to search set and lesson names and descriptions by free text. Options to evaluate before the marketplace phase:

- **Algolia via Firebase Extension** — most mature, generous free tier, excellent Flutter SDK
- **Typesense** — open-source, self-hostable, lower cost at scale
- **Meilisearch** — similar to Typesense, very fast
- **Vertex AI Search (Google)** — native Firebase integration, AI-enhanced relevance

The choice should be made as a dedicated spike task at the start of the marketplace phase. The data model does not need to change; the search service indexes a projection of the Firestore data via a Cloud Function trigger.

### Implementation Phasing (future)

| Sub-phase | Scope |
|---|---|
| Marketplace Alpha | Publish/unpublish sets; basic tag + popularity browsing; subscribe and clone |
| Marketplace Beta | Ratings, reviews, moderation tools, content reporting |
| Lessons | Lesson data model, creation UI, lesson-level study flow |
| Creator Tools | Analytics for publishers (views, subscribers, clone counts) |
| Monetization | If pursued: premium content, creator revenue share (requires separate design) |

---

## Post-MVP Considerations

### Web Dashboard — Bulk Card Creation & Desktop Experience

> **Status: Formal post-MVP phase.** No implementation tasks assigned yet.

#### Motivation

The mobile app is optimised for study-focused users: single-card creation, set browsing, and session-based learning. A second, distinct audience — teachers and content creators who need to produce large volumes of cards (e.g. a full vocabulary unit) — is poorly served by the per-card mobile flow and benefits from a keyboard-driven, wide-layout experience. Rather than retrofitting the mobile UI with desktop patterns, the dashboard will be built as a dedicated effort that owns the widescreen layout from the ground up.

#### Responsive Design Deferral

Widescreen layout decisions (navigation pattern, master-detail splits, content max-width breakpoints) are intentionally deferred from Phase 7 mobile polish to this effort. Implementing responsive layout twice — once as a retrofit and once properly for the dashboard — would produce inconsistent results and wasted work. The dashboard phase will establish and own the desktop layout conventions for the whole app.

#### Concept

A web-first, wide-layout screen presenting a spreadsheet-style editor where each row is a card. Columns correspond to the fields of a chosen template, so the structure is fixed per session and each row is directly editable inline. Changes are batched and written to Firestore on save rather than on every keystroke.

**Key behaviours:**
- Template-driven column layout — select a template and the grid columns match its fields
- Keyboard-first navigation — Tab/Enter to move between cells, no mouse required for bulk entry
- Inline validation — field errors surface per cell without blocking other rows
- Batch Firestore write — same write path as the existing import infrastructure (Phase 6)
- Set assignment on save — choose or create the target set before committing

#### Navigation Pattern

Desktop and wide-tablet layouts will use a persistent `NavigationDrawer` (full-width sidebar with labels and optional metadata) rather than a `NavigationRail`. The `BottomNavigationBar` remains for mobile. The shell adapts based on a screen-width breakpoint, swapping between the two at runtime.

#### Relationship to Import/Export

JSON import (Phase 6) and the dashboard serve overlapping user needs. Import is better when the user already has data elsewhere or wants to use external tools (including AI) to generate content at scale. The dashboard is better for users who want to create content directly in-app without leaving it. Both paths share the same Firestore batch write layer.

#### Scope of the Dashboard Phase

Beyond the bulk editor, this effort is the right time to address:
- **Navigation shell** — swap `BottomNavigationBar` for persistent `NavigationDrawer` on wide screens; establish breakpoints app-wide
- **Content max-width** — constrain all single-column screens (forms, study session, summary) so they don't stretch on desktop
- **Hover and focus states** — audit interactive elements for mouse/keyboard accessibility on desktop
- **Master-detail layouts** — set detail (list + card preview), cards screen (list + form panel) where screen width allows

#### Implementation Phasing (future)

| Sub-phase | Scope |
|---|---|
| Dashboard Alpha | Responsive shell (NavigationDrawer + breakpoints + content max-width); bulk card editor (template-driven grid, keyboard nav, batch save) |
| Dashboard Beta | Inline field validation, undo/redo, duplicate row, reorder rows |
| Master-detail layouts | Set detail split-pane, Cards screen list+form panel |
| Advanced creator tools | CSV paste, column mapping, bulk tag assignment |
