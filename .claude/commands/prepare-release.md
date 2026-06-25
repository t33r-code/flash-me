You are preparing release notes for the Agora app. Follow these steps exactly.

## Step 1 — Detect the current milestone

Run the following to find the earliest open milestone in the repo:

```bash
"/c/Program Files/GitHub CLI/gh.exe" api repos/t33r-code/flash-me/milestones \
  --jq 'sort_by(.due_on // "9999") | .[] | select(.state=="open") | {number: .number, title: .title, due: .due_on}' 2>/dev/null \
  || gh api repos/t33r-code/flash-me/milestones \
  --jq 'sort_by(.due_on // "9999") | .[] | select(.state=="open") | {number: .number, title: .title, due: .due_on}'
```

Pick the first result as the current milestone. Report its title and number to the user.

## Step 2 — Fetch closed issues for that milestone

```bash
"/c/Program Files/GitHub CLI/gh.exe" issue list \
  --repo t33r-code/flash-me \
  --milestone "<MILESTONE_TITLE>" \
  --state closed \
  --json number,title,labels \
  --jq '.[] | {number: .number, title: .title, labels: [.labels[].name]}'
```

(Substitute `<MILESTONE_TITLE>` with the actual title from Step 1. Fall back to plain `gh` if the full path fails.)

## Step 3 — Categorise the issues

Sort closed issues into three buckets based on their labels:
- **New features**: label contains `feature`, `enhancement`, or `improvement`
- **Bug fixes**: label contains `bug` or `fix`
- **Everything else** (chore, deployment, testing, etc.): omit from user-facing notes unless significant

For each issue include the number and a short plain-English description derived from the title (rephrase to be user-facing — not internal/technical).

## Step 4 — Append the release notes entry

Append a new entry to `docs/release-notes.md` (the running history file, not the template):

```
## v<VERSION> — <MILESTONE_TITLE> — <TODAY'S DATE>

### New features
- <item> (#<N>)

### Bug fixes
- <item> (#<N>)

### Known issues
- None identified
```

Use today's date (YYYY-MM-DD). Leave the version number as a placeholder (`vX.Y`) if you cannot determine it from the milestone title — the user will fill it in.

## Step 5 — Bump the version code in pubspec.yaml

Read the current version from `pubspec.yaml` (format: `version: X.Y.Z+N`).

Increment the build number (`+N`) by 1. Also update the semantic version (`X.Y.Z`) to match the milestone (e.g. Alpha 0.4 → `0.4.0`, Alpha 0.3.1 → `0.3.1`). Write the updated line back.

Show the old and new version strings to the user.

## Step 6 — Write whatsnew/whatsnew-en-US

Overwrite `whatsnew/whatsnew-en-US` with a condensed plain-text summary suitable for the Play Store "What's New" section:
- Maximum 500 characters
- No markdown — plain text only
- Lead with the most user-visible new feature
- Keep bug fixes to one short line if there were any
- Do not mention issue numbers

Show the character count after writing the file.

## Step 7 — Commit release prep changes

Stage and commit `docs/release-notes.md`, `whatsnew/whatsnew-en-US`, and `pubspec.yaml` together:

```
chore: release notes and version bump for <VERSION>
```

## Step 8 — Report back

Tell the user:
- Which milestone was detected
- How many issues were categorised (features / fixes / omitted)
- The old → new version string
- The character count of the whatsnew file
- Ask them to confirm the version, then push the `v*` tag when ready
