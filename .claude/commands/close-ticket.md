You are closing out a completed piece of work for the Agora app — taking a finished branch through docs, tests, PR, merge, and issue closure. Follow these steps in order. Stop and report if any gate fails; never merge on a red gate.

`$ARGUMENTS` may contain the issue number (e.g. `209`). If empty, infer it from the current branch name (branches follow `type/<ticket>-...`, e.g. `feature/209-...`). Confirm the number before proceeding.

Always invoke GitHub CLI as `"/c/Program Files/GitHub CLI/gh.exe"` (fall back to plain `gh` if that path fails). Repo is `t33r-code/flash-me`.

## Step 1 — Establish context

- `git branch --show-current` — confirm you are on the feature branch, not `main`. If on `main`, stop and ask.
- `git status --short` — note uncommitted changes.
- Determine the issue number (from `$ARGUMENTS` or the branch name) and read it: `gh issue view <N> --repo t33r-code/flash-me --json title,state,labels,milestone`.
- Report the branch, issue number/title, and whether a PR already exists: `gh pr list --repo t33r-code/flash-me --head <branch> --json number,state,url`.

## Step 2 — Documentation-sync gate (per CLAUDE.md)

Verify docs were updated **in this branch** for the work being closed. Do not merge until these are true (update them now if missing, and commit in Step 4):

- **`docs/design.md`** and **`docs/implementation-roadmap.md`** — in sync with the code change (new/changed behaviour, models, renamed concepts). Tick the relevant roadmap checkboxes.
- **`docs-site/docs/*.md`** — updated if the change is user-visible (new screens/features, renamed UI, changed flows, removed functionality). Skip for internal refactors, behaviour-neutral bug fixes, or backend-only changes.
- **Play Store data-safety**: if the change could affect the Google Play Data Safety section or content declarations (payments, ads, new data categories, new SDKs, sharing), **explicitly tell the user to TAKE ACTION** in the Play Console. Flag it every time; do not assume it updates itself.

## Step 3 — Quality gates

Run both; both must be clean before proceeding:

1. **Analyze** (native Windows, fast): `flutter analyze lib/ test/`. Pre-existing warnings unrelated to this branch may be noted and ignored; new issues in changed files must be fixed.
2. **Tests via WSL** (SAC blocks `flutter test` natively — see the WSL memory note):
   ```
   wsl.exe bash -c 'cd /mnt/c/code/flash-me && $HOME/flutter/bin/flutter test 2>&1 | tail -15'
   ```
   Must end in `All tests passed!`. If red, stop and report the failures — do not merge.

## Step 4 — Commit and push

- Stage only files relevant to this work. **Do not stage** unrelated generated churn (e.g. `macos/Flutter/GeneratedPluginRegistrant.swift`) unless it is the point of the change.
- Commit message **must include the issue number**, e.g. `feat: <summary> (#<N>)`. End the body with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
  (Use a message file + `git commit -F` for multi-line messages — the Bash tool is POSIX sh, so PowerShell here-strings won't work.)
- Push: `git push -u origin <branch>`.

## Step 5 — Pull request

If no PR exists for the branch, create one:

```
"/c/Program Files/GitHub CLI/gh.exe" pr create --repo t33r-code/flash-me --base main \
  --head <branch> --title "<type>: <summary> (#<N>)" --body-file <path>
```

The body should include: a Summary, any notable design decision, the acceptance criteria as a checklist, a Tests line (note "full suite green via WSL"), and Smoke-test steps for runtime behaviour CI can't cover. **End the body with** `Closes #<N>` so the issue auto-closes on merge, and:
`🤖 Generated with [Claude Code](https://claude.com/claude-code)`

If a PR already exists, ensure its body still reflects the final scope; update with `gh pr edit <num> --body-file <path>` if it drifted.

## Step 6 — CI gate

`"/c/Program Files/GitHub CLI/gh.exe" pr checks <num> --repo t33r-code/flash-me`

The `analyze-and-test` check must be `pass`. If pending, wait and re-check; if failing, stop and report. Never merge on a non-green check.

## Step 7 — Merge and clean up

```
"/c/Program Files/GitHub CLI/gh.exe" pr merge <num> --repo t33r-code/flash-me --squash --delete-branch
```

Then:
- Confirm the issue closed: `gh issue view <N> --repo t33r-code/flash-me --json state -q .state` → `CLOSED`. If it's still `OPEN` (the PR body lacked `Closes #N`), close it explicitly with a one-line comment referencing the PR.
- Sync local: `git checkout main && git pull --ff-only && git branch -d <branch>`.

## Step 8 — Post-merge actions

- **Firestore/Storage rules**: if `firestore.rules`, `firestore.indexes.json`, or `storage.rules` changed, deploy after merge — `firebase deploy --only firestore:rules --project flash-me-7a1a2` (and/or `firestore:indexes`, `storage`). Remind the user if a deploy is needed.
- If this work spun off follow-up issues, confirm they were created and added to project #1 (Agora Roadmap).

## Step 9 — Report

Tell the user, concisely:
- PR number + merge status; issue number + closed confirmation
- Which quality gates ran and their results (analyze, WSL test count)
- Which docs were updated (or why none were needed)
- Any TAKE ACTION items (Play Console, rules deploy) still owed by the user
- Local `main` synced and branch deleted