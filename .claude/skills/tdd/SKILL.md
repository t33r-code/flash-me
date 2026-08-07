---
name: tdd
description: Test-Driven Development workflow with explicit red-green-refactor cycles, adapted to this Flutter/Dart project. Use when adding a feature, fixing a bug, or changing existing behaviour — write the failing test before any implementation.
---

# TDD in Agora (Flutter / Dart)

Test-Driven Development requires explicit prompting. Left alone, Claude writes the
implementation first and then tests that pass against it. TDD needs the inverse.

This is the Agora-specific version: all commands, layers and conventions below are the
ones this repo actually uses.

---

## TL;DR

```
Red → Green → Refactor

Prompt explicitly:
"Write a FAILING test for [behaviour]. Do NOT write the implementation yet."
```

Verify with (see [Running the tests](#running-the-tests) for why WSL):

```bash
wsl -e bash -lc 'cd /mnt/c/code/flash-me && $HOME/flutter/bin/flutter test'
```

---

## The Problem

Without explicit instruction, Claude will:
1. Write implementation code
2. Then write tests that pass against that implementation

This defeats TDD's purpose: tests should drive design, not validate existing code.

A test written after the implementation also proves less. If it never failed, nothing
demonstrates it can detect the bug it supposedly guards.

---

## Running the tests

### Unit / widget tests — must go through WSL

`flutter test` **does not run natively on this machine**. Smart App Control blocks the
unsigned `flutter_tester.exe`. Always use the Linux SDK inside WSL:

```bash
wsl -e bash -lc 'cd /mnt/c/code/flash-me && $HOME/flutter/bin/flutter test'
```

Single file, while iterating:

```bash
wsl -e bash -lc 'cd /mnt/c/code/flash-me && $HOME/flutter/bin/flutter test test/utils/set_ordering_test.dart'
```

**Use the absolute `$HOME/flutter/bin/flutter`.** The PATH export sits below the
non-interactive early-return in `~/.bashrc`, so `bash -c` falls through to the Windows
SDK, whose CRLF launcher breaks under bash (`$'\r': command not found`).

### Analyze — runs natively, unaffected by SAC

```bash
flutter analyze lib test
```

Prefer this over the CI invocation: `pr_check.yml` only analyzes `lib/`, so analyzing
`lib test` locally is the stricter gate and catches problems in test code that CI misses.

### Integration tests — need the Firebase emulators

```bash
firebase emulators:start --only auth,firestore
flutter test integration_test/all_tests.dart -d windows
```

Two caveats: SAC intermittently blocks the Windows app runner (`flutter clean` + rebuild
fixes it), and these tests do **not** cover media/Storage. CI runs this suite on every PR
touching `lib/repositories/**`, `lib/models/**`, `lib/services/**` or `integration_test/**`.

### Regenerating mocks

Mockito mocks are code-generated from `@GenerateMocks` annotations (see
`test/services/import_service_test.dart`). After changing a mocked interface:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## The Red-Green-Refactor Cycle

### Phase 1: Red — write the failing test

**Prompt**:
```
Write a failing test for [behaviour].
Do NOT write the implementation yet.
```

Then **run it and show the failure**. A red phase that was never executed is an
assumption, not a step. The failure message is the evidence that the test is wired to
the behaviour it claims to cover.

Expected: the test fails because the function/class doesn't exist, or because current
behaviour is genuinely wrong.

### Phase 2: Green — minimal implementation

**Prompt**:
```
Now implement the minimum code to make these tests pass.
Only enough to pass the current tests, nothing more.
```

Run the suite again. Green must be demonstrated, not asserted.

### Phase 3: Refactor — clean up

**Prompt**:
```
Refactor to improve quality. Tests must stay green.
Focus on: [readability / removing duplication / performance]
```

Re-run after each change.

---

## Project conventions

### Test placement
`test/` mirrors `lib/`: `test/models/`, `test/services/`, `test/utils/`, `test/widgets/`,
`test/screens/`. Integration tests live separately in `integration_test/workflows/`.

### Naming — match the existing style
This repo uses lowercase descriptive sentences inside a `group()`, **not** snake_case:

```dart
group('sortSetCardsByPosition', () {
  test('fully positioned links sort by position', () { ... });
  test('does not mutate the input list', () { ... });
});
```

Read as "sortSetCardsByPosition — does not mutate the input list". Don't introduce
`should_return_empty_when_no_items` style; it clashes with every existing test file.

### Extract pure logic to make it testable
When behaviour is buried in a widget or a Firebase repository, pull the pure part into
`lib/utils/` and test that directly — the established pattern here
(`utils/set_ordering.dart`, `AppHelpers.sanitizeFileExtension`). Widget and Firebase
layers are far more expensive to test than a pure function.

### Table-driven cases over a property-testing library
No property-based testing package is in `pubspec.yaml`. For multi-case coverage, loop
over inputs inside one test rather than adding a dependency:

```dart
for (final ext in ['jpg', 'png', 'mp3']) {
  expect(sanitize(ext), ext, reason: '$ext should survive unchanged');
}
```

Use `reason:` — with a loop, the failure output alone won't say which case broke.

### Prove the test can fail
For a regression fix, confirm the new test **fails against the old code** before
committing. Temporarily disable the fix, run the test, watch it fail, restore. A test
that passes both before and after the fix pins nothing. This is cheap and repeatedly
catches assertions that are weaker than they look — e.g. asserting only
`isA<AppException>()` when a neighbouring code path throws the same type.

---

## Verification: the three layers

Report work complete only after all three pass — and only where the layer applies:

1. **`flutter analyze lib test`** — fastest, catches syntax and lint before tests run
2. **`flutter test` (via WSL)** — unit and widget correctness
3. **`integration_test/all_tests.dart -d windows`** — real Firestore/Auth behaviour
   against the emulators

Each catches a different class of failure. Unit tests pass while component boundaries
break; integration tests surface rules violations, stream lifecycle and state
propagation that unit tests cannot see.

**Trust the analyzer over the IDE.** Editing Dart mid-file routinely produces cascades of
false "undefined class/name" diagnostics from the IDE's analysis server, including for
`Archive`, `Icon`, `test` and `expect` in files that clearly import them. `flutter analyze`
is the authority; a stale IDE error is not a reason to change working code. Genuine
errors do occur — e.g. calling a new `.arb` string before running `flutter gen-l10n` — so
confirm with the analyzer rather than assuming either way.

### The Verification Gap

The failure mode where completion is reported before the suite confirms it. Symptoms: a
success message printed before any test command ran; tests run but output not read; only
unit tests pass when the acceptance criteria described end-to-end behaviour.

The evaluation problem is real: whoever just built the feature reads ambiguous output
charitably. Concretely here — a green `flutter test` says nothing about Firestore rules,
and a passing integration suite says nothing about media upload, which it explicitly
excludes.

Report outcomes exactly: if a layer was skipped, say which and why.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Correct Approach |
|--------------|----------------|------------------|
| "Write tests for this feature" | Implementation gets written first | "Write FAILING tests; no implementation yet" |
| "Add tests and implementation" | Loses the test-first benefit | Two separate prompts |
| "Make sure tests pass" | Encourages implementation-first | "Write tests, then implement minimally" |
| Claiming green without running | The Verification Gap | Paste the actual result |
| Skipping refactor | Accumulates debt | Always refactor after green |
| Multiple features at once | Loses focus | One feature per cycle |

### Testing existing code

```
# Wrong
"Write tests for the existing sanitizeFileExtension"

# Right
"Write tests for sanitizeFileExtension's contract as if it didn't exist,
then verify the current implementation satisfies them."
```

### Combining red and green

```
# Wrong
"Implement sanitizeFileExtension with tests"

# Right
"Write failing tests for sanitizeFileExtension. Stop there."
[then]
"Now implement to pass those tests."
```

---

## Where TDD doesn't fit here

Be honest about the boundary instead of faking coverage:

- **Platform-channel code** — `file_picker`, Storage uploads and `google_sign_in` have no
  mocks configured in this repo. Testing them means building that harness first; say so
  rather than skipping quietly.
- **Platform-dependent branches** — code keyed off `defaultTargetPlatform` (Windows vs
  macOS vs web) can't be exercised for every platform from one test run.
- **Real network/CDN timing** — retry and propagation behaviour can't be simulated
  meaningfully in a unit test.

For these, state plainly in the PR that no test was added and why. That is more useful
than a test asserting a mock returns what the mock was told to return.

---

## Workflow integration

- **Branch first.** Every ticket gets its own branch including the issue number
  (`fix/298-...`) before any code is written.
- **Run the WSL suite before opening the PR.** It is the standard pre-PR gate here, not
  just a CI concern — CI runs unit tests on PRs only.
- **Track cycles with TodoWrite** for multi-part work: one RED / GREEN / REFACTOR entry
  per behaviour, so a half-finished cycle is visible.
- **Plan Mode** (Shift+Tab) suits designing the test list before writing any of it.

---

## See Also

- `CLAUDE.md` — coding style, workflow conventions, Firestore data model
- `test/utils/set_ordering_test.dart` — representative pure-logic test style
- `test/services/import_service_test.dart` — mockito `@GenerateMocks` setup
- `integration_test/firebase_test_config.dart` — emulator wiring and per-run test users
- `.github/workflows/pr_check.yml` / `integration_tests.yml` — what CI actually gates on
- [Anthropic: Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices)
