# Flash Me — Claude Code Guide

## What this project is
A multi-platform Flutter flashcard app for language learning. Cards have a primary field (foreign word → translation reveal) plus additional fields of three types: **reveal-on-click**, **text input** (validated), and **multiple choice**. Cards are grouped into sets; users study sets in sessions that are tracked and resumable.

Full feature specifications: `docs/design.md`
Implementation progress: `docs/implementation-roadmap.md`

---

## Tech stack

| Layer | Choice |
|---|---|
| UI | Flutter (iOS, Android, Web, Windows, macOS, Linux) |
| Auth | Firebase Authentication (email/password + Google Sign-In) |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| State management | Riverpod (`flutter_riverpod: ^3.3.1`, `riverpod: ^3.2.1`) |
| Key packages | `google_sign_in: ^7.2.0`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `csv`, `file_picker`, `connectivity_plus` |

---

## Code structure

```
lib/
├── main.dart                   # App entry point; initialises Firebase + GoogleSignIn; routes via authStateProvider
├── firebase_options.dart       # Firebase config for all platforms (currentPlatform dispatcher)
├── models/
│   └── user.dart               # AppUser — Firestore ↔ Dart model (fromFirestore, toFirestore, copyWith)
├── providers/
│   └── auth_provider.dart      # authServiceProvider, authStateProvider (StreamProvider<User?>),
│                               # currentUserProvider, appUserProvider (StreamProvider<AppUser?>)
├── services/
│   └── auth_service.dart       # AuthService — all Firebase Auth operations
├── screens/
│   ├── auth_screen.dart        # Login / register / forgot-password (ConsumerStatefulWidget)
│   ├── home_screen.dart        # Post-login home; shows "My Sets" placeholder + profile nav
│   └── profile_screen.dart     # View/edit display name; sign out
├── theme/
│   └── app_theme.dart          # AppTheme.lightTheme / darkTheme (Material 3, indigo primary)
└── utils/
    ├── constants.dart          # AppConstants (collection names, field types, status enums, pagination)
    └── helpers.dart            # AppLogger (static debug/info/error), AppValidators (email, password, name)
```

---

## Key technical decisions & gotchas

### google_sign_in v7 — API completely changed from v6
- **No constructor** — use the singleton: `GoogleSignIn.instance`
- **No `signIn()`** — use `GoogleSignIn.instance.authenticate()` (throws `GoogleSignInException`, not nullable)
- **`authentication` is now synchronous** and returns only `idToken` (no `accessToken`); `idToken` alone is sufficient for Firebase Auth
- **`initialize()` must be called once at startup** — done in `main.dart` before `runApp`
- Cancellation returns `GoogleSignInExceptionCode.canceled` — catch and return `null`, don't show an error

### Riverpod v3 — `valueOrNull` removed
- Use `asyncValue.asData?.value` instead of `asyncValue.valueOrNull`
- Action providers are not needed for simple auth calls — call `ref.read(authServiceProvider).method()` directly from UI handlers

### Firebase options
- `firebase_options.dart` contains real API keys for all platforms — intentionally tracked in git (client-restricted keys; security enforced by Firestore rules)
- Linux config uses placeholder values — not supported yet

### Firestore security rules
- Rules file: `firestore.rules` — all collections restricted to owning user
- Deploy with: `firebase deploy --only firestore:rules` (project alias set via `firebase use`)
- Indexes file: `firestore.indexes.json` — currently empty; will be populated in Phase 2

### Android emulator noise — safe to ignore
- `GoogleApiManager: Unknown calling package name 'com.google.android.gms'` — GMS internal, harmless
- `Phenotype.API is not available` — GMS feature flags, harmless
- `No AppCheckProvider installed` — App Check not configured; won't block anything in development

### Google Sign-In on Android
- Requires the debug **SHA-1 fingerprint** registered in Firebase Console under the Android app
- Won't work on emulators without Google Play Store (use "Google Play" AVD image or a real device)

### GitHub CLI
- Installed at `C:\Program Files\GitHub CLI\gh.exe` — not on PATH for shell tools
- Always invoke as `"/c/Program Files/GitHub CLI/gh.exe"` in Bash tool calls

### Firebase CLI
- Use `firebase deploy --only firestore:rules` to deploy rules
- Use `firebase deploy --only firestore:indexes` to deploy indexes
- Default project is `flash-me-7a1a2` (set via `firebase use`)

---

## Firestore data model (summary)

```
users/{userId}
  email, displayName, photoUrl, createdAt, lastLoginAt

users/{userId}/studySessions/{sessionId}
  setId, startTime, lastAccessTime, status, cardProgress{}, cardSequence[], currentCardIndex,
  totalCardsStudied, cardsKnown, cardsUnknown, sessionStats{}

cards/{cardId}
  setId, primaryWord, translation, fields[], templateId?, createdAt, updatedAt, createdBy

sets/{setId}
  userId, name, description, cardIds[], cardCount, createdAt, updatedAt, isPublic, tags[], color

templates/{templateId}
  createdBy, name, description, fields_schema[]
```

Field types: `reveal` | `text_input` | `multiple_choice` (constants in `AppConstants`)

---

## Implementation status

| Phase | Status | Notes |
|---|---|---|
| 1 — Setup & Auth | ✅ Complete | Email/password + Google Sign-In wired; profile screen; Firestore rules deployed |
| 2 — Data models | 🔲 Not started | |
| 3 — Cards & Templates | 🔲 Not started | |
| 4 — Card Sets | 🔲 Not started | |
| 5 — Study Mode | 🔲 Not started | Core value proposition |
| 6 — Import/Export | 🔲 Not started | |
| 7 — Polish & Test | 🔲 Not started | |

Remaining Phase 1 items: account linking (deferred), Google Sign-In testing on real device.

---

## Workflow conventions

- **Branch naming**: `feature/<name>`, `chore/<name>`, `fix/<name>`
- **Default branch**: `main`
- **PRs**: squash-merge, delete branch after merge
- **Firestore rules changes**: always deploy after merging (`firebase deploy --only firestore:rules`)
- **Roadmap**: update task checkboxes as work is completed; commit the change in the same branch as the work
