# Cards { #cards }

Agora has two card types:

- **Flash Cards** — a primary word, its translation, and optional extra fields. The classic flashcard format.
- **Workbook Cards** — a prompt followed by one or more structured questions (text input, multiple choice, word order, fill in the blanks, or complete the grid). Good for grammar exercises, reading comprehension, and drills.

Both types can be added to sets and studied in the same session.

---

## Flash Cards { #flash-cards }

### Creating a Flash Card { #create-flash-card }

1. Tap the **Cards** tab (:material-cards-outline:).
2. Tap the **+** button and choose **Flash Card**.
3. Enter the **Foreign word** (e.g. *hablar*) and its **Translation** (e.g. *to speak*).
4. Optionally add [fields](#card-fields), [languages](#card-languages), or [tags](#card-tags).
5. Tap **Save**.

### Additional Fields { #card-fields }

Fields add extra practice layers to a card. Tap **Add field** to add as many as you need. Each field has a **name** (e.g. *Gender*, *Conjugation*) and a **type**:

#### Reveal on Click { #field-reveal }

Shows a label; the answer is hidden until the learner taps it. Good for grammar notes, example sentences, or supplementary information.

- **Field name** — the label shown before the answer is revealed (e.g. *Example sentence*).
- **Answer** — the text that appears on tap.

#### Text Input { #field-text-input }

The learner types an answer and Agora checks it.

- **Field name** — the prompt shown above the input (e.g. *Conjugation — yo form*).
- **Correct answers** — one or more accepted answers, comma-separated (e.g. *hablo, Hablo*). Useful for allowing accent variants.
- **Hint** *(optional)* — shown below the input field as a nudge.
- **Exact match** — when on, the answer must match capitalisation and accents exactly. Off by default.

#### Multiple Choice { #field-multiple-choice }

The learner picks from a list of options.

- **Field name** — the question or prompt (e.g. *Noun gender*).
- **Options** — add each choice; tap the tick on one option to mark it as correct.

### Image & Audio { #card-media }

A Flash Card can have an optional image and audio clip attached to the primary field. These are shown during study alongside (or instead of) the foreign word.

- **Image** — tap the image area or **Add image** to pick an image file from your device. A thumbnail is shown in the form. Tap **Replace image** to swap it, or **Remove** to clear it.
- **Audio clip** — tap **Add audio** to pick an audio file. The form shows whether a clip is attached. Tap **Replace** or the delete icon to change or remove it.

!!! tip "Hide the word"
    When a card has media, you can configure a template with **Hide primary word by default** so that the word stays hidden until the learner taps *Show Word* — useful for listening or image-recognition drills. Apply the template to the card to inherit this behaviour.

### Languages { #card-languages }

Tap the **Native language** or **Target language** pickers to tag a card with its language pair (e.g. English → Spanish). When creating a card inside a set, the language pair is inherited from the set automatically.

### Tags { #card-tags }

Tags help you organise and filter cards. Start typing in the tags field and Agora suggests matching tags that you or other users have already used — tap a suggestion to add it. To create a brand-new tag, type it and press **Enter** (or tap the **+** button). You can paste several comma-separated tags at once, and a card can have any number of tags.

Tags are stored in a simplified form — lowercased with spaces turned into hyphens (e.g. *Spanish Verbs* becomes *spanish-verbs*) — so the same tag always matches regardless of how it was typed.

### Searching & Filtering Cards { #card-search }

The **My Cards** screen has a search bar and tag filter row at the top.

- **Search** — type any part of a card's primary word, translation, or prompt to narrow the list instantly.
- **Tag filter** — tap a tag chip to show only cards with that tag. Tap it again (or tap **All**) to clear the filter.

Search and tag filter work together — you can, for example, search for "hab" while filtered to "spanish-verbs".

### Editing a Flash Card { #edit-card }

Tap any card in the **Cards** list to open it in the editor. All fields, languages, and tags can be changed. Tap **Save** to confirm.

### Deleting a Flash Card { #delete-card }

Open the card for editing, then tap the :material-delete-outline: **delete icon** in the top-right corner. You'll be asked to confirm. Deleting a card removes it from all sets it belongs to; the sets themselves are unaffected.

---

## Templates { #templates }

The Templates tab (:material-file-multiple-outline:) holds two types of reusable templates: **Card Templates** and **Question Templates**. Both tabs are shown in the Templates screen.

### Card Templates { #card-templates }

A Card Template defines the full question structure for a Flash Card — the complete set of questions a card should have, without any of the answers filled in. If you create many cards with the same shape (e.g. every noun card has a *Gender* and a *Plural form* question), save that structure once and apply it to new cards with a single tap.

#### Creating a Card Template { #create-template }

1. Tap the **Templates** tab (:material-file-multiple-outline:) and select **Card Templates**.
2. Tap **+** and give the template a **name** and optional **description**.
3. Add questions the same way as on a card — the structure is defined here, but answers are left blank.
4. Tap **Save**.

!!! tip "Hide primary word"
    Card Templates have a **Hide primary word by default** toggle. When on, cards created from this template will hide the foreign word until the learner taps *Show Word* — useful for media-recognition drills.

#### Applying a Card Template { #apply-template }

When creating or editing a Flash Card, tap **Use Template** in the *Additional Questions* section, then choose the **Card Templates** tab. Pick a template — its full question structure is applied to the card instantly, with answers blank for you to fill in.

!!! note
    If the card already has questions, you'll be asked to confirm before they are replaced.

#### Saving a Card as a Template { #save-as-template }

If you've already built a card with the right question structure, you can turn it into a template without rebuilding from scratch.

1. Open the card for editing.
2. Tap the **⋮** menu in the top-right corner and choose **Save as Template**.
3. Give the template a name and tap **Save**. The question structure is copied; all answers are cleared.

---

### Question Templates { #question-templates }

A Question Template defines a single reusable question — its type, label, options (for multiple choice), hint (for text input), and other config. Unlike Card Templates, applying a Question Template *appends* the question to the card; nothing is replaced and no confirmation is needed.

Question Templates are useful when the same question recurs across many cards — for example, a *Gender* multiple-choice question with the same four options on every noun card.

#### Creating a Question Template { #create-question-template }

1. Tap the **Templates** tab and select **Question Templates**.
2. Tap **+**, give the template a **name** and optional **description**.
3. Choose the **question type** (Text input, Multiple choice, or Word order) and fill in the structure — options, hint, display mode, etc. No answers are stored here.
4. Optionally set an **Import ID** — a short slug (e.g. `gender`) used to reference this template in hand-authored import files as `##gender`. Must be unique across your question templates.
5. Tap **Save**.

#### Applying a Question Template { #apply-question-template }

**From a Flash Card or Workbook Card:** tap **Use Template** in the questions section, then choose the **Question Templates** tab. Tap a template — the question is appended to the card's existing questions.

**From a Card Template:** tap **Use Template** alongside the *Add Question* button. The question is appended to the template's question list.

---

## Workbook Cards { #workbook-cards }

### Creating a Workbook Card { #create-workbook-card }

1. Tap the **Cards** tab (:material-cards-outline:).
2. Tap **+** and choose **Workbook Card**.
3. Enter a **Prompt** — the text or instruction the learner reads before answering (e.g. *Read the passage and answer the questions below.*).
4. Tap **Add question** to add your first question.
5. Choose a [question type](#question-types), fill in the details, and repeat for additional questions.
6. Optionally add [tags](#card-tags) — the same autocomplete tag field as on Flash Cards.
7. Tap **Save**.

### Question Types { #question-types }

#### Text Input { #question-text-input }

The learner types a free-text answer.

- **Question label** *(optional)* — a prompt above the input (e.g. *Translate the underlined word*).
- **Correct answers** — comma-separated accepted answers (e.g. *runs, run*).
- **Hint** *(optional)* — shown below the input field.
- **Exact match** — requires the answer to match capitalisation exactly. Off by default.

#### Multiple Choice { #question-multiple-choice }

The learner selects from a set of options.

- **Question label** *(optional)* — the question text (e.g. *Choose the correct article*).
- **Options** — add each choice; tap the tick on one to mark it correct.
- **Display** — choose **List** (one option per row) or **Chips** (compact inline chips). Chips work best for short options like single words.
- **Explanation** *(optional)* — shown after the learner answers; good for grammar rules or context.

#### Word Order { #question-word-order }

The learner reconstructs a sentence by tapping words into the correct order.

1. In the **Word bank** section, add each word or phrase as a separate tile (e.g. *el*, *perro*, *corre*).
2. In the **Correct order** section, tap the tiles in the right sequence to set the expected answer.
- **Question label** *(optional)* — shown above the word bank (e.g. *Put the sentence in order*).

#### Fill in the Blanks { #question-fill-in-blanks }

The learner completes a sentence with one or more missing words, chosen from a pool of word pills.

1. Type the full **Sentence** (e.g. *The cat sat on the mat*) and tap **Tokenize** to split it into words.
2. Tap the words that may be blanked out — these are highlighted as **eligible**.
3. Set the **Number of blanks** — each time the question is shown, that many eligible words are hidden at random.
4. Optionally add **distractor words** — extra pills added to the pool to make it harder.
- **Question label** *(optional)* — shown above the sentence.

When studying, the learner taps a blank to select it, then taps a word pill to fill it in. Each card shuffles which eligible words are hidden, so the same question stays fresh on repeat.

#### Complete the Grid { #question-grid }

The learner fills in missing cells of a table — handy for conjugation tables, pronoun grids, or declension charts.

1. Set the number of **Rows** and **Columns** with the steppers. You can increase or decrease these at any time — growing the grid keeps everything you've already typed, so a miscount is a one-tap fix, not a restart.
2. Optionally turn on **Column headers** and/or **Row headers** to add a labelled top row or left column.
3. Fill in every cell of the table (the grid scrolls sideways if it's wide).
4. Set **Cells to leave empty** — each time the question is shown, that many cells are hidden at random for the learner to complete.
- **Question label** *(optional)* — shown above the grid.

All cells must be filled before you can save. When studying, the learner taps an empty cell, then taps a word pill to fill it in.
