# Import & Export { #data }

Flash Me can export your card sets as ZIP files and import them back — useful for backing up your data, moving sets between accounts, or sharing sets with others.

To get to the Import & Export screen: tap the **Profile** tab (:material-account-circle-outline:) and tap **Import & Export**.

---

## Exporting Sets { #export-bulk }

The Import & Export screen lists all your sets with checkboxes.

1. Tick the sets you want to export. Tap **Select all** to tick everything at once.
2. Tap **Export N sets**. Flash Me builds a single ZIP archive containing all selected sets and opens your device's share sheet so you can save or send it.

The export counter updates as you select: *3 of 7 selected*, and the button label reflects your selection (*Export 3 sets*).

!!! tip "Exporting a single set"
    You can also export one set directly from its detail screen — tap the :material-download-outline: icon in the top-right corner. The result is the same ZIP format.

---

## Importing Cards { #import }

### Choosing a File { #import-file }

1. Tap **Choose ZIP file…** at the top of the Import & Export screen.
2. Pick a Flash Me ZIP file from your device. Flash Me analyses it immediately and shows the [Import Preview](#import-preview).

### Import Preview { #import-preview }

The preview shows exactly what will change before anything is written. At the top are two options that apply to all sets in the file:

| Option | What it does |
|---|---|
| **Skip card updates** | Only add new cards — cards already in the set are left exactly as they are. |
| **Remove cards not in import** | Cards that exist in your set but are absent from the file are removed from the set (the cards themselves are not deleted from your library). |

Below the options, each set in the file is listed as a collapsible section showing:

- **New** — cards that will be created
- **From library** — cards already in your library that will be linked to the set (no duplicate created)
- **Updated** — cards whose fields have changed since the last export
- **Deleted** — cards that will be removed from the set (only shown when *Remove cards not in import* is on)

Tap **Import** to apply the changes. When the import finishes, a summary shows how many cards were created, updated, linked, and removed.

### Supported File Format { #import-format }

Flash Me imports ZIP files that were exported by Flash Me. The archive contains a `cards.json` file describing the sets and cards, plus a `media/` folder for any attached images or audio. Both single-set and multi-set archives are supported.

!!! note
    Manually created or edited ZIP files are supported as long as they match the expected JSON structure. If Flash Me can't parse the file, it shows an error and no changes are made.
