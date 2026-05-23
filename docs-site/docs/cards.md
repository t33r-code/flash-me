# Cards { #cards }

Flash Me has two card types:

- **Flash Cards** — a primary word, its translation, and optional extra fields. The classic flashcard format.
- **Workbook Cards** — a prompt followed by one or more structured questions (text input, multiple choice, or word order). Good for grammar exercises, reading comprehension, and drills.

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

The learner types an answer and Flash Me checks it.

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

Tags help you organise and filter cards. Type a tag in the tags field and press **Enter** to add it. A card can have multiple tags.

### Editing a Flash Card { #edit-card }

Tap any card in the **Cards** list to open it in the editor. All fields, languages, and tags can be changed. Tap **Save** to confirm.

### Deleting a Flash Card { #delete-card }

Open the card for editing, then tap the :material-delete-outline: **delete icon** in the top-right corner. You'll be asked to confirm. Deleting a card removes it from all sets it belongs to; the sets themselves are unaffected.

---

## Templates { #templates }

A template defines a reusable field structure — the set of extra fields a card should have, without any of the answers filled in. If you create many cards with the same shape (e.g. every verb card has a *Conjugation* and a *Gender* field), save that structure as a template once and apply it to new cards with a single tap.

### Creating a Template { #create-template }

1. Tap the **Templates** tab (:material-file-multiple-outline:).
2. Tap **+** and give the template a **name** and optional **description**.
3. Add fields the same way as on a card — the field structure is defined here, but answers are left blank.
4. Tap **Save**.

!!! tip "Hide primary word"
    Templates have a **Hide primary word by default** toggle. When on, cards created from this template will hide the foreign word until the learner taps *Show Word* — useful when you want to practise recall from media (image or audio) before reading the word.

### Applying a Template { #apply-template }

When creating or editing a Flash Card, tap **Use Template** in the *Additional Fields* section. Pick a template from the list — its fields are added to the card instantly, with the structure pre-filled and answers blank for you to fill in.

!!! note
    If the card already has fields, you'll be asked to confirm before they are replaced.

### Saving a Card as a Template { #save-as-template }

If you've already built a card with the right field structure, you can turn it into a template without rebuilding it from scratch.

1. Open the card for editing.
2. Tap the **⋮** menu in the top-right corner and choose **Save as Template**.
3. Give the template a name and tap **Save**. The field structure is copied; all answers are cleared.

---

## Workbook Cards { #workbook-cards }

### Creating a Workbook Card { #create-workbook-card }

1. Tap the **Cards** tab (:material-cards-outline:).
2. Tap **+** and choose **Workbook Card**.
3. Enter a **Prompt** — the text or instruction the learner reads before answering (e.g. *Read the passage and answer the questions below.*).
4. Tap **Add question** to add your first question.
5. Choose a [question type](#question-types), fill in the details, and repeat for additional questions.
6. Tap **Save**.

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
