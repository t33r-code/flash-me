# Firestore/Storage rules tests (#285)

Security rules unit tests for `firestore.rules` and `storage.rules`, run against
the local Firebase emulator suite via [`@firebase/rules-unit-testing`](https://github.com/firebase/firebase-tools/tree/master/firebase-vscode). Never touches
production — the emulator is a fully local, in-memory simulation.

See `docs/security/firebase-rules-review.md` for the findings each test covers.

## Setup (once)

```
cd firestore-tests
npm install
```

## Run

From the repo root (the emulator needs `firebase.json`'s emulator config):

```
firebase emulators:exec --only firestore,storage "npm --prefix firestore-tests test"
```

This starts the Firestore + Storage emulators, runs `rules.test.js` against them,
and tears the emulators down afterward regardless of pass/fail. Output is a
`PASS`/`FAIL` line per test plus a final `N passed, N failed` summary; the process
exits non-zero if anything failed.

## Adding a test

Each `test('name', async () => { ... })` call in `rules.test.js` gets its own clean
Firestore state (`testEnv.clearFirestore()` runs between tests). Use
`testEnv.withSecurityRulesDisabled(...)` to seed fixture documents (bypassing the
rules you're about to test), then `assertSucceeds(...)` / `assertFails(...)` on the
actual operation under test via an `authenticatedContext(uid)`.
