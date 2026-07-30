# Refactoring Review — Agora (#287)

Structured review of the codebase against two focuses: (1) separating business logic
from rendering in the five largest screen files, and (2) a DRY audit for duplicated
logic across the app. Research was split across six parallel passes (one per
candidate file, plus a dedicated cross-cutting DRY sweep) so every finding below is
grounded in specific file:line citations, not general impressions.

**No code has been changed as part of this review.** This is a findings document —
see "Next steps" at the end for how the actual refactors get executed.

## Headline finding — a real (if minor) correctness bug from copy-paste drift

The DRY sweep found that the "question-state" pattern (a controller-backed class
mapping form fields ↔ `CardQuestion`) is duplicated **four ways**, not two as
originally scoped in the ticket:

- `card_form_screen.dart` — `_QuestionState` (has answers)
- `workbook_card_form_screen.dart` — `_QuestionState` (has answers, explicitly
  "mirrors" the above per its own comment)
- `template_form_screen.dart` — `_TplQuestionState` (answer-free, template variant)
- `question_template_form_screen.dart` — `_QuestionState` (answer-free, explicitly
  "mirrors `_TplQuestionState`" per its own comment)

All four independently `switch` over the same 5 `CardQuestion` subtypes. **The two
card editors (flash + workbook) fall back to `AppConstants.fieldTypeTextInput` for
`WordOrderQuestion`/`GridQuestion`/`FillInTheBlanksQuestion`** (types those editors
don't support yet), **while `question_template_form_screen.dart` correctly maps each
to its own constant.** That's not a stylistic inconsistency — it's the kind of
divergence that happens when duplicated code gets fixed in one place and not the
other three. Nothing is broken *today* only because the unsupported-type branches
aren't reachable from the card editors' UI yet — but the next person to wire up
word-order/grid/FIB support in a card editor by copying the template editor's switch
will inherit this exact inconsistency unless it's called out. Flagging as the single
most structurally significant finding, sized as its own large/careful follow-up
rather than a quick fix (see RF-1 below).

---

## Summary table

| ID | Tier | Area | Finding | Effort | Risk |
|----|------|------|---------|--------|------|
| RF-1 | Structural | 4 editors | Question-state duplication (card/workbook/template/question-template) — see headline above | Large | Medium |
| RF-2 | Quick win | 6 files | Language-pair label formatting duplicated 9+ times | Small | Low |
| RF-3 | Quick win | 5 files | Inline tag-normalize-and-filter snippet duplicated 6 times | Small | Low-Med |
| RF-4 | Quick win | 2 files | Progress-dialog boilerplate duplicated 3 times | Small | Low |
| RF-5 | Quick win | 1 file | `withFreshQuestionId` shared helper not used at one call site (workbook) | Small | Low |
| RF-6 | Medium | card_form | `_resolveMediaUrls` media upload/delete orchestration | Medium | Medium |
| RF-7 | Medium | workbook | Four validation loops in `_save()` | Medium | Low |
| RF-8 | Medium | workbook | `_QuestionState.toQuestion()`/`fromQuestion()` Firestore mapping | Small-Med | Low-Med |
| RF-9 | Medium | study_session | Session-stats computation in `_completeSession` | Small | Low |
| RF-10 | Medium | set_detail | Card-bucketing/search-filter logic recomputed every keystroke | Medium | Low-Med |
| RF-11 | Medium | set_detail | Language-pair counting/sorting in the card-library drawer | Medium | Low |
| RF-12 | Medium | data_screen | Import-summary computation buried in dialog state | Small-Med | Low |
| RF-13 | Medium | data_screen | Template-map field-shaping recomputed every rebuild | Medium | Medium |
| RF-14 | Medium | study_session | `_next()`'s missed/requeue orchestration mixed with side effects | Medium | Medium |
| RF-15 | Small | study_session | High-water-mark bump duplicated (initState vs `_next`) | Small | Low |
| RF-16 | Small | study_session | `_loadSessionCards` ID-partitioning inline instead of shared | Small | Low |
| RF-17 | Small | set_detail | Per-rebuild join/resolution mutates instance fields in `build()` | Medium | Medium |
| RF-18 | Small | 2 files | Confirm-delete dialog boilerplate duplicated (card/workbook) | Small | Low |
| RF-19 | Small | 3 files | Dialogs never wrapped in `KeyboardActions` (auth/profile/feedback) | Small | Low |
| RF-20 | Small | workbook | Grid clamping math interleaved with controller lifecycle | Medium | Medium |
| RF-21 | Small | workbook | FIB/grid "add extra word" near-duplicate (2 sites) | Small | Low |
| RF-22 | Small | data_screen | Same-file pop-dialog-then-snackbar error handling (3 sites) | Small | Low |
| RF-23 | Small | data_screen | `_ImportSummaryData` model class defined in the screen file | Small | Low |
| RF-24 | Small | set_detail | Optimistic-order-reconciliation logic untestable without a widget | Small | Low |
| RF-25 | Structural | workbook | File is 2090 lines — per-question-type UI could split into files | Medium | Low |
| RF-26 | Deferred | study_session | Recall/question first-attempt scoring dedup logic | Medium | Medium |
| Info | — | 10+ model files | `Timestamp.fromDate`/`.toDate()` boilerplate — normal Firestore idiom, not worth touching | — | — |

---

## Tier A — Quick, safe wins (do these together, one small PR)

### RF-2 — Language-pair label formatting (9+ sites, 6 files)
The exact expression `'${target.toUpperCase()} → ${native.toUpperCase()}'`, each time
preceded by a `targetLanguage != null && nativeLanguage != null` guard, is hand-rolled
independently in:
- `widgets/add_cards_to_set.dart:98,170` (guards 43,52)
- `screens/sets/clone_confirmation_screen.dart:340` (guard 299)
- `screens/sets/sets_screen.dart:634,932` (guards 527,818)
- `screens/cards/my_cards_screen.dart:718,793` (guards 712,791)
- `screens/sets/set_detail_screen.dart:1534` (guards 1314-15,1441-42,1447-48,1455-56)

One shared `formatLanguagePair(target, native)` (or an extension on `CardSet`/a pair
tuple) removes all of it. Already-noticed drift: at least one site uses a different
separator style around the arrow than the others.

### RF-3 — Inline tag-normalize-and-filter snippet (6 sites)
`tags.map(AppHelpers.normalizeTag).where((t) => t.isNotEmpty).toList()` repeated
verbatim at `card_form_screen.dart:527,662`, `workbook_card_form_screen.dart:853,963`,
`set_form_screen.dart:84`, `widgets/set_actions.dart:61-64`. `utils/helpers.dart`
already has `normalizeTag`/`diffTags` — just missing a list-level convenience
(`AppHelpers.normalizeTags(List<String>)`). A future change to normalization rules
would otherwise need to touch 6 places and could easily miss one.

### RF-4 — Progress-dialog boilerplate (3 sites)
Identical `showDialog(barrierDismissible:false, builder: (_) => AlertDialog(content:
Row([CircularProgressIndicator, SizedBox(width:20), Text(msg)])))` in
`data_screen.dart:193-205,268-280` and `widgets/set_actions.dart:101-113`. One
`showProgressDialog(BuildContext, String message)` helper covers all three.

### RF-5 — `withFreshQuestionId` not used at one call site
`workbook_card_form_screen.dart:486-496`'s `_appendQuestionFromTemplate` hand-rolls
the exact per-type re-keying switch that `CardQuestion.withFreshQuestionId`
(`models/card_question.dart:121`) already provides and that this same file already
calls correctly elsewhere (line 411), as does `card_form_screen.dart:291,357`. This
is the cheapest possible fix in the whole review — swap the local switch for the
existing shared call.

*(RF-2 through RF-5 are small and independent enough to land together in one PR with
straightforward before/after tests — recommended as the first follow-up ticket.)*

---

## Tier B — Medium-effort extractions (real testability payoff, one ticket each)

**RF-6 (card_form_screen.dart:456-488, 391-403)** — `_resolveMediaUrls` (Storage
upload/delete orchestration) and `_mimeForExt` are pure aside from reading `ref`;
most self-contained, most testable chunk in the file. Risk: medium — must preserve
delete-before-upload ordering exactly.

**RF-7 (workbook_card_form_screen.dart:764-842)** — four validation loops (MC/word-
order/FIB/grid) that scan `_questions` and fire a snackbar on first failure. Pure
logic except the snackbar call site; same shape as the existing `study_filters.dart`
pattern.

**RF-8 (workbook_card_form_screen.dart:111-297)** — `_QuestionState.fromQuestion()`/
`toQuestion()`, the Firestore↔form mapping. Note: this is the same logic RF-1 is
about — extracting it here without also addressing the 4-way duplication just moves
the problem, so treat RF-8 as a *prerequisite step toward* RF-1 rather than a
separate final destination.

**RF-9 (study_session_screen.dart:469-509)** — `_completeSession`'s `SessionStats`
computation is pure arithmetic on primitives, sitting next to `Navigator`/route code.

**RF-10 (set_detail_screen.dart:1603-1680)** — search-filter + card-bucketing
(flash/workbook, in-set/not-in-set/word-conflict) recomputed on every rebuild
*and every keystroke* in the library drawer. Same shape as `study_filters.dart`;
the "word conflict" rule (same `primaryWord`, different id) deserves its own unit
tests independent of the widget.

**RF-11 (set_detail_screen.dart:1438-1463)** — language-pair tally + sort for the
library drawer, pure over card lists, currently recomputed every build.

**RF-12 (data_screen.dart:350-390)** — `_runImport()`'s post-import summary
(`cardsAdded`/`cardsUpdated`/`cardsRemoved` etc.) derived by hand from
`ImportAnalysis` + two option flags. Pure; belongs as a method on the model
(pairs naturally with RF-23).

**RF-13 (data_screen.dart:684-719)** — `_TemplateDiffSectionState.build()` pulls raw
map fields and switches on a raw type string to an l10n label, on every rebuild of
that dialog section. Needs care: split the pure field-extraction from the
l10n-dependent label lookup — don't drag `BuildContext`/l10n into the model layer.

**RF-14 (study_session_screen.dart:292-335)** — `_next()`'s missed/requeue
orchestration mixes pure session-state transitions with `setState`/autosave side
effects; core sequencing path exercised by both keyboard shortcuts and nav-bar taps,
so needs solid regression tests before touching.

---

## Tier C — Smaller items (bundle opportunistically, low individual priority)

RF-15 (duplicated high-water-mark comparison, `study_session_screen.dart:116-119`
vs `325-328`), RF-16 (ID-partitioning inline in `_loadSessionCards`, lines 138-143),
RF-17 (`set_detail_screen.dart:704-740` resolves entries *and* mutates
`_orderedIds`/`_typeById` as a build-time side effect — a "build() mutates fields"
smell worth fixing on its own merits), RF-18 (confirm-delete dialog boilerplate
identical between `card_form_screen.dart:628-655` and
`workbook_card_form_screen.dart:933-958` — candidate for a shared
`confirmDeleteDialog(context, title, message)`), RF-19 (three dialogs —
`auth_screen.dart:158`, `profile_screen.dart:182`, `widgets/feedback_dialog.dart:104`
— predate #235 and were never wrapped in `KeyboardActions`; cosmetic/UX-consistency
only), RF-20 (grid clamping math interleaved with `TextEditingController`
allocation in `workbook_card_form_screen.dart:656-751` — only the pure arithmetic
should move, not the controller lifecycle), RF-21 (`_addFibExtraWord`/
`_addGridExtraWord`, lines 611-625/632-649, near-identical bodies), RF-22 (same-file
pop-dialog-then-snackbar repeated 3x in `data_screen.dart`), RF-23
(`_ImportSummaryData`, `data_screen.dart:882-902`, belongs in `models/import_diff.dart`
alongside RF-12), RF-24 (`set_detail_screen.dart:461-483`'s optimistic-order
reconciliation — a natural second citizen of `utils/set_ordering.dart`, which this
screen otherwise already uses correctly for drag-index math).

**RF-25** — `workbook_card_form_screen.dart` is the largest file in the app (2090
lines); roughly 900 lines of it are self-contained per-question-type UI sections
(`_build*Content` methods) that could become separate widget files purely for
navigability, with no logic changes required.

**RF-26 (deferred, not a near-term ticket)** — `study_session_screen.dart`'s
first-attempt-only scoring dedup (`_finalizedPositions`/`_countedQuestions`,
lines 394-407, 622-665) is separable pure bookkeeping, but the scoring semantics for
re-queued visits are subtle (existing comments reference #214's double-counting
history) — flag for a dedicated, carefully-tested pass rather than bundling with
other work.

---

## Verified clean — no action needed

- `study_session_screen.dart`'s `build()`/`_buildCardArea` — no expensive per-rebuild
  work found.
- `card_form_screen.dart`'s `build()` — same; `DateFormat` instantiation in
  `_buildMetadata` is cheap and edit-mode-only.
- `set_detail_screen.dart`'s drag-reorder math — already correctly delegates to
  `utils/set_ordering.dart`; no parallel implementation exists (the ticket's own
  wording worried this might be duplicated — it isn't).
- `data_screen.dart`'s diffing/writing — correctly delegated to
  `ImportService`/`ExportService`; the screen only holds UI glue.
- `set_detail_screen.dart`'s Market publish/export/delete flows — correctly
  delegate to `widgets/set_actions.dart`, per the ticket's own instruction.
- `study_session_screen.dart` already uses `requeueMissedCard`
  (`study_filters.dart`) and `isQuestionExpanded` (`question_reveal.dart`) — direct
  confirmation the target extraction pattern is already working elsewhere in this
  codebase.

---

## Next steps

This review produced ~26 findings across 5 files plus cross-cutting duplication.
Given the volume, execution needs its own scoping decision — see the accompanying
message for options on how to sequence follow-up tickets and how much to fix now
versus file for later.
