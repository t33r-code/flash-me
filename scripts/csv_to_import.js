// csv_to_import.js
// Convert a Flash Me vocabulary CSV to a cards.json import file.
//
// Usage:
//   node scripts/csv_to_import.js <input.csv> [output.json]
//
// The output JSON must be zipped before importing:
//   Windows: Compress-Archive -Path cards.json -DestinationPath import.zip -Force
//   Mac/Linux: zip -j import.zip cards.json
//
// Prerequisites:
//   - Question templates must exist in the app with these Import IDs:
//       Gender4, ParadigmMA, ParadigmMI, ParadigmF, ParadigmN
//
// Notes:
//   - Duplicates (same czech_word) are deduplicated; first occurrence wins.
//   - Verbs with no first_person_full get no question.
//   - nativeLanguage / targetLanguage are written to the JSON but are not
//     currently read by the import service; they will be applied once that
//     support is added.

'use strict';

const fs   = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const SET_NAME        = 'Czech - Lesson 1';
const NATIVE_LANGUAGE = 'en';
const TARGET_LANGUAGE = 'cs';

const GENDER_TEMPLATE_ID = 'Gender4';

// Gender question correctIndex mapping (matches Gender4 template option order).
const GENDER_INDEX = { MA: 0, MI: 1, F: 2, N: 3 };

// Paradigm templates — one per grammatical gender.
// Options must be listed in the same order as in the app's question template.
const PARADIGM_TEMPLATES = {
  MA: { id: 'ParadigmMA', options: ['Muz',   'Preseda', 'Pan'             ] },
  MI: { id: 'ParadigmMI', options: ['Stroj', 'Hrad'                       ] },
  F:  { id: 'ParadigmF',  options: ['Zena',  'Pisen', 'Kost', 'Ruze'      ] },
  N:  { id: 'ParadigmN',  options: ['Mesto', 'More',  'Kure', 'Staveni'   ] },
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Strip diacritics and lowercase for fuzzy matching of paradigm values.
function normalise(str) {
  return str.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

// Simple CSV parser. Values in this vocabulary format never contain commas,
// but the last column is handled defensively (rejoins any extra splits).
function parseCSV(content) {
  const lines = content.trim().split(/\r?\n/);
  const headers = lines[0].split(',').map(h => h.trim());
  return lines.slice(1)
    .filter(line => line.trim())
    .map(line => {
      const parts = line.split(',');
      const row   = {};
      headers.forEach((h, i) => {
        // For the last column, rejoin any accidental splits.
        const val = i < headers.length - 1
          ? parts[i]
          : parts.slice(i).join(',');
        row[h] = (val ?? '').trim();
      });
      return row;
    });
}

// ---------------------------------------------------------------------------
// Question builders
// ---------------------------------------------------------------------------

function nounQuestions(gender, paradigm) {
  const questions = [];

  // Gender question — ##Gender4 template reference.
  const genderIdx = GENDER_INDEX[gender];
  if (genderIdx === undefined) {
    console.warn(`    ⚠ Unknown gender "${gender}" — skipping gender question`);
  } else {
    questions.push({ template: `##${GENDER_TEMPLATE_ID}`, correctIndex: genderIdx });
  }

  // Paradigm question — gender-specific template reference.
  const tpl = PARADIGM_TEMPLATES[gender];
  if (!tpl) {
    console.warn(`    ⚠ No paradigm template for gender "${gender}" — skipping paradigm question`);
  } else if (!paradigm) {
    console.warn(`    ⚠ Empty paradigm — skipping paradigm question`);
  } else {
    const idx = tpl.options.findIndex(opt => normalise(opt) === normalise(paradigm));
    if (idx < 0) {
      console.warn(`    ⚠ Paradigm "${paradigm}" not found in ${tpl.id} [${tpl.options.join(', ')}] — skipping`);
    } else {
      questions.push({ template: `##${tpl.id}`, correctIndex: idx });
    }
  }

  return questions;
}

function verbQuestions(firstPersonFull) {
  if (!firstPersonFull) return [];
  return [
    {
      prompt: '1st person',
      type: 'text_input',
      content: { correctAnswers: [firstPersonFull], hint: null, exactMatch: false },
    },
  ];
}

// ---------------------------------------------------------------------------
// Card builder
// ---------------------------------------------------------------------------

function buildCard(row) {
  let questions = [];

  switch (row.part_of_speech) {
    case 'noun': questions = nounQuestions(row.gender, row.paradigm);         break;
    case 'verb': questions = verbQuestions(row.first_person_full);             break;
    case 'adj':  /* no questions */                                            break;
    default:
      console.warn(`    ⚠ Unknown part_of_speech "${row.part_of_speech}" — card created with no questions`);
  }

  return {
    primaryWord:      row.czech_word,
    translation:      row.definition,
    primaryImageUrl:  null,
    primaryAudioUrl:  null,
    primaryWordHidden: false,
    nativeLanguage:   NATIVE_LANGUAGE,
    targetLanguage:   TARGET_LANGUAGE,
    tags:             [],
    questions,
  };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const [,, csvPath, outputArg] = process.argv;

  if (!csvPath) {
    console.error('Usage: node csv_to_import.js <input.csv> [output.json]');
    process.exit(1);
  }

  const content = fs.readFileSync(csvPath, 'utf8');
  const rows    = parseCSV(content);

  // Deduplicate by czech_word — first occurrence wins.
  const seen   = new Set();
  const unique = rows.filter(row => {
    if (!row.czech_word) return false;
    if (seen.has(row.czech_word)) {
      console.log(`  Skipping duplicate: "${row.czech_word}"`);
      return false;
    }
    seen.add(row.czech_word);
    return true;
  });

  console.log(`\nProcessing ${unique.length} words (${rows.length - unique.length} duplicates removed):\n`);

  const cards = unique.map(row => {
    const card = buildCard(row);
    const qSummary = card.questions.length === 0
      ? 'no questions'
      : card.questions.map(q => q.template ?? q.prompt ?? q.type).join(', ');
    console.log(`  ${row.part_of_speech.padEnd(5)}  ${row.czech_word.padEnd(20)}  [${qSummary}]`);
    return card;
  });

  const output = {
    version: '1.0',
    set: {
      name:           SET_NAME,
      description:    '',
      nativeLanguage: NATIVE_LANGUAGE,
      targetLanguage: TARGET_LANGUAGE,
      tags:           [],
      cards,
    },
  };

  const dest = outputArg ?? path.join(path.dirname(path.resolve(csvPath)), 'cards.json');
  fs.writeFileSync(dest, JSON.stringify(output, null, 2), 'utf8');

  console.log(`\n✓ Wrote ${cards.length} cards to: ${dest}`);
  console.log('\nNext step — create a ZIP for import:');
  console.log(`  Windows:   Compress-Archive -Path "${dest}" -DestinationPath import.zip -Force`);
  console.log(`  Mac/Linux: zip -j import.zip "${dest}"`);
}

main();
