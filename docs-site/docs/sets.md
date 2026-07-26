# Sets { #sets }

Sets are collections of cards that you study together. A card can belong to multiple sets, and removing a card from a set never deletes the card itself.

On a **wide window** (desktop, or a tablet/phone in landscape), the **My Sets** list and the set you pick appear **side by side** — choose a set on the left and its cards show in a pane on the right. On a phone, tapping a set opens it full-screen as before.

On a wide window, creating or editing a card also happens right in that pane: tap **Add card** in the toolbar, or open an existing card by **double-clicking** its row (or hovering it and tapping the **edit icon** next to the reorder handle), and the pane switches to an editor with **Cancel** / **Save** in place of the usual set actions. Saving or cancelling returns you to the card list. On a phone, tapping the same edit icon opens the card in the full-screen editor instead. (Deleting a card entirely is only available from the **Cards** tab — the set pane can only add or remove-from-set.)

---

## Creating a Set { #create-set }

1. Tap the **Sets** tab (:material-book-multiple-outline:).
2. Tap the **+** button.
3. Enter a **Set name** (required) and an optional **Description**.
4. Choose a [colour](#set-details) and add any [tags](#set-details) if you like.
5. Tap **Save**.

---

## Colour, Tags & Languages { #set-details }

These options are available on the create and edit screens:

- **Colour** — pick from a predefined palette. The colour appears as an accent bar on the set tile in your Sets list, making sets easy to tell apart at a glance. On desktop you can Tab to the swatches and press **Enter** or **Space** to choose one — the focused swatch shows a ring.
- **Tags** — start typing to see suggestions from tags already in use; tap one to add it, or press **Enter** to create a new tag. Tags are lowercased with spaces turned into hyphens so the same tag always matches. Tags help you filter and organise sets.
- **Native language / Target language** — tag the set with its language pair. Cards created directly within this set will inherit these languages automatically.
- **Enforce card order** — when on, the set is always studied in the order its cards are arranged, and learners can't shuffle it. Leave it off (the default) to let anyone studying the set randomise the order. Turn it on for sets that tell a story or build up step by step.

---

## Adding Cards to a Set { #add-cards }

1. Open the set by tapping it in the Sets list.
2. Add a card:
    - On a **phone**, tap the **+** button at the bottom of the screen. A sheet offers **Flash Card**, **Workbook Card**, or **Add existing cards**.
    - On a **wide window**, tap the **+** in the set's toolbar for a small menu with **Flash Card** / **Workbook Card**; adding cards you already have is the separate :material-library-plus-outline: **library button** next to it (see [Adding existing cards](#add-existing)).
3. Choosing **Flash Card** or **Workbook Card** creates a brand-new card right here. The editor opens seeded with the set's language pair, and when you save, the card is created **and** added to the set in one step.

### Adding existing cards { #add-existing }

Choosing **Add existing cards** opens the card library:

1. The library shows all your cards — Flash Cards and Workbook Cards — grouped into sections. Cards already in the set appear greyed out at the bottom.
2. Tap a card to select it (a tick appears). You can select as many as you like.
3. Tap **Add** to add the selected cards to the set.

On a **wide window** the library opens as a panel docked beside the card list rather than a bottom sheet, and it stays open so you can add several batches in a row. You can open it directly with the :material-library-plus-outline: **library button** in the set's toolbar (no need to go through the **+** menu) — the same button closes it again, as does the **✕** in the panel. As well as selecting cards and tapping **Add**, you can **drag** a card — or a whole selection — from the library and **drop** it onto the card list to add it. The list highlights while a card is hovering over it. On a narrower (roughly square) window there isn't room to show the list and the panel side by side, so opening the library covers the card list entirely — you can still multi-select and tap **Add**, but drag-and-drop isn't available until you widen the window.

### Finding cards in the picker { #picker-search }

When your library is large, use the tools at the top of the picker to narrow the list:

- **Search** — type any part of a word to filter instantly. Flash Cards match on their word, translation, or tags; Workbook Cards match on their prompt. Search ignores accents and capitalisation.
- **Language filter chips** — a scrollable row of language pairs found in your cards (for example `ES → EN`). Tap one to show only cards in that language, or **All** to show everything. If the set already has a language, that pair is selected by default.

### Keeping a set to one language { #picker-language-check }

Sets work best with a single language pair. When you add cards, Agora checks the languages involved:

- **The set already has a language** and a selected card is in a different one — you're warned before adding, and can choose to add anyway.
- **The set has no language yet** and every selected card shares one pair — you're offered to make that pair the set's default language as part of adding. (Cards with no language set are added as-is.)
- **The set has no language yet** and the selection spans more than one pair — you're warned that the cards are mixed, and can choose to add anyway.

---

## Removing Cards from a Set { #remove-cards }

In the set detail screen, **swipe left** on any card row (or, on a wide window, tap the **remove icon** that appears next to the reorder handle when you hover the row). Either way the card is removed from the set but is not deleted from your library. A brief **Undo** appears if you change your mind — it puts the card back in the same spot.

On a wide window, card rows also show a **clone icon** next to Edit and Remove when you hover — see [Cloning a Card](cards.md#clone-card). Cloning from here automatically adds the new card to this same set.

---

## Reordering Cards { #reorder-cards }

Cards in a set have an order that you control. In the set detail screen, **drag the handle** on the right of a card row and drop it where you want — the new order is saved automatically. Flash Cards and Workbook Cards share a single order, so you can interleave them however you like.

This order is what learners follow when they study the set. If you've turned on [Enforce card order](#set-details), the set is always studied in exactly this order and can't be shuffled; otherwise it's the default order and learners can still choose to [shuffle](study.md#session-setup).

---

## Selecting Several Cards in a Set { #set-multi-select }

Just like [in the card library](cards.md#card-multi-select), you can select several cards in a set at once and act on all of them together.

**To start selecting:** **long-press** a card (phone or tablet), **Ctrl+click** it (**⌘+click** on a Mac), or tap **Select** — on a wide window it's its own button in the toolbar; on a phone it's in the **⋮** menu.

While selecting, each row shows a checkbox instead of its icon, and dragging to reorder or swiping to remove is turned off for the moment — tap the **✕** to leave selection mode and get them back. Tapping, Shift+clicking, and Select all all work the same way as in the card library.

With a selection made, the toolbar offers:

- :material-label-outline: **Tag** and :material-translate: **Set language** — the same bulk edits described for the card library.
- :material-minus-circle-outline: **Remove from set** — takes all the selected cards out of this set after a single confirmation. The cards themselves aren't deleted.

There's no bulk Delete here — deleting a card entirely is only available from the **Cards** tab.

On a wide window, hovering over a card row highlights it, and **right-clicking** it opens a menu with **Edit**, **Clone**, and **Remove from set** — the same actions as the row's hover icons, just reachable without hovering first.

---

## Studying a Set { #study-from-set }

Tap the :material-play-circle-outline: **play icon** in the top-right corner of the set detail screen. This opens the study setup screen directly, bypassing the Study tab set picker.

See [Study Mode](study.md) for a full walkthrough of sessions.

---

## Searching, Filtering & Sorting Sets { #set-search }

The **My Sets** screen has a search bar, tag filter chips, and a sort menu.

- **Search** — type any part of a set name to narrow the list instantly.
- **Tag filter** — tap a tag chip to show only sets with that tag. Tap again (or tap **All**) to clear.
- **Sort** — tap the :material-sort: icon in the top-right corner to choose:
    - **Last updated** (default) — most recently changed first.
    - **Name** — alphabetical A → Z.
    - **Card count** — most cards first.

The active sort order is shown as a small label below the tag chips.

### Right-Click a Set { #set-context-menu }

On a wide window, hovering over a set in the list highlights it, and **right-clicking** it opens a menu with **Study**, **Offer in Market** / **Remove from Market**, **Export**, **Edit**, and **Delete** — the same actions available from inside the set, without opening it first.

---

## Editing a Set { #edit-set }

Tap the :material-pencil-outline: **edit icon** in the top-right corner of the set detail screen to change the name, description, colour, tags, languages, or the [Enforce card order](#set-details) setting.

---

## Deleting a Set { #delete-set }

Tap the :material-delete-outline: **delete icon** in the top-right corner of the set detail screen and confirm. This removes the set and all its card memberships. Cards themselves are not deleted — they remain in your library and in any other sets they belong to.

---

## Exporting a Set { #export-set }

Tap the :material-download-outline: **download icon** in the top-right corner of the set detail screen. Agora builds a ZIP archive containing all the cards in the set (including any attached images or audio) and opens your device's share sheet so you can save or send it.

See [Import & Export](import-export.md) for how to import a ZIP file and the full export format details.

---

## The Market Tab { #market-tab }

The **Market** tab (next to My Sets) shows sets that other users have published. Each tile displays the set name, creator, card count, language pair, tags, and how many times the set has been acquired.

Use the search bar and tag filter chips to narrow the list — these work the same way as on the My Sets tab.

Sets you have already cloned show a **Cloned** badge with the date.

---

## Cloning a Set from the Market { #clone-set }

Cloning copies a market set into your library as a new set that you own and can edit freely.

1. Tap a set tile in the **Market** tab.
2. Review the details on the confirmation screen.
3. Tap **Clone to My Sets**.

The cloned set appears in your **My Sets** tab. It is fully independent — changes to the original set are not automatically reflected in your copy, and your edits do not affect the original.

Each card in the set is copied into your library. If a card from the same source already exists in your library (from a previous clone of a different set), your existing copy is reused and no duplicate is created.

---

## Updating a Cloned Set { #update-cloned-set }

If the creator has added or updated cards since you cloned a set, you can pull those changes into your copy without creating a new set.

1. Tap the set tile in the **Market** tab. Because you have already cloned it, Agora shows the **update screen** instead of the clone confirmation.
2. Agora checks the source set for changes. This takes a moment.
3. One of two outcomes:
    - **Updates available** — the screen shows how many new cards have been added and how many existing cards have been updated. Tap **Update My Copy** to apply them.
    - **Up to date** — your copy already matches the current source. Tap **OK** to dismiss.

**What "Update My Copy" does:**

- New cards are added to your existing set.
- Updated cards have their content refreshed to match the current source version.
- Cards **removed** from the source set are left in your copy — your set is yours to control.
- No new set is created.
