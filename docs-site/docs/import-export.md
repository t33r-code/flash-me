# Import & Export { #data }

Agora can export your card sets as ZIP files and import them back — useful for backing up your data, moving sets between accounts, or sharing sets with others.

To get to the Import & Export screen: tap the **Profile** tab (:material-account-circle-outline:) and tap **Import & Export**.

---

## Exporting Sets { #export-bulk }

The Import & Export screen lists all your sets with checkboxes.

1. Tick the sets you want to export. Tap **Select all** to tick everything at once.
2. Tap **Export N sets**. Agora builds a single ZIP archive containing all selected sets and opens your device's share sheet so you can save or send it.

The export counter updates as you select: *3 of 7 selected*, and the button label reflects your selection (*Export 3 sets*).

!!! tip "Exporting a single set"
    You can also export one set directly from its detail screen — tap the :material-download-outline: icon in the top-right corner. The result is the same ZIP format.

### Templates in Exports { #export-templates }

Every export automatically includes **all** of your Card Templates and Question Templates (including their Import IDs and option lists) as top-level arrays in the archive. This means:

- When you share an export with another user, they get your full template library alongside the cards.
- When you use an export file as the source for a [hand-authored import](#import-template-shorthand), the template option values are visible in the file so you can look up correct indices without opening the app.

---

## Importing Cards { #import }

### Choosing a File { #import-file }

1. Tap **Choose ZIP file…** at the top of the Import & Export screen.
2. Pick a Agora ZIP file from your device. Agora analyses it immediately and shows the [Import Preview](#import-preview).

### Import Preview { #import-preview }

The preview shows exactly what will change before anything is written. At the top are two options that apply to all sets in the file:

| Option | What it does |
|---|---|
| **Skip card updates** | Only add new cards — cards already in the set are left exactly as they are. |
| **Remove cards not in import** | Cards that exist in your set but are absent from the file are removed from the set (the cards themselves are not deleted from your library). |

If the file contains [templates](#import-templates) that don't yet exist in your account, a **Templates** section appears first showing which card and question templates will be created.

Below that, each set in the file is listed as a collapsible section showing:

- **New** — cards that will be created
- **From library** — cards already in your library that will be linked to the set (no duplicate created)
- **Updated** — cards whose fields have changed since the last export
- **Deleted** — cards that will be removed from the set (only shown when *Remove cards not in import* is on)

Tap **Import** to apply the changes. When the import finishes, a summary shows how many templates, cards, and sets were created, updated, or removed.

### Supported File Format { #import-format }

Agora imports ZIP files that were exported by Agora. The archive contains a `cards.json` file describing the sets and cards, plus a `media/` folder for any attached images or audio. Both single-set and multi-set archives are supported.

Manually created or edited ZIP files are also supported. Agora is lenient about common hand-authoring quirks:

- **Trailing commas** before `]` or `}` are accepted.
- Both `questions` and the legacy `fields` key are recognised.

If Agora can't parse the file, it shows an error and no changes are made.

### Templates in Import Files { #import-templates }

When Agora imports a ZIP, any Card Templates and Question Templates defined in the file are created in your account **before** cards are processed. Templates that already exist (matched by Import ID for Question Templates, by name for Card Templates) are left unchanged — no duplicates are created.

This means you can share a complete learning pack — templates and cards — as a single ZIP, and the recipient gets everything set up automatically.

### Question Template Shorthand { #import-template-shorthand }

If you have a [Question Template](cards.md#question-templates) with an **Import ID** set (e.g. `gender`), you can reference it in a hand-authored import file instead of writing out the full question definition:

```json
{ "template": "##gender", "correctIndex": 2 }
```

The `##` prefix identifies the value as a template reference. The part after `##` must match the Import ID of one of your Question Templates exactly. Any answer fields you include alongside it (`correctIndex`, `correctAnswers`, `correctOrder`, `wordBank`) override the template's defaults for that card.

The template can either already exist in your account **or** be defined in the same import file — Agora resolves `##id` references after processing any templates in the file, so a self-contained pack works without any prior setup.

!!! warning "Unknown template IDs"
    If the referenced Import ID doesn't match any template in your account or in the import file itself, the import fails immediately and no changes are made. Check the spelling of the ID and ensure the template is defined before retrying.

The shorthand and the full question definition can be mixed in the same file — use whichever is more convenient for each question.
