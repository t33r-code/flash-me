// One-shot migration: rename the 'fields' array to 'questions' in all cards
// and templates, and normalise the key names within each question entry.
//
// Transforms:
//   fields[]           → questions[]
//   question.fieldId   → question.questionId
//   question.name      → question.prompt
//   questions with type == 'reveal' are deleted entirely
//
// Safe to re-run: docs that already use 'questions' and have no 'fields' are
// skipped. Only modified docs are written.
//
// Prerequisites:
//   1. npm install firebase-admin   (run once in this directory)
//   2. serviceAccountKey.json present in this directory
//   3. node scripts/migrate_questions.js [--dry-run]
//      --dry-run  logs what would change without writing anything

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const dryRun = process.argv.includes('--dry-run');
if (dryRun) console.log('DRY RUN — no writes will be performed.\n');

// Transform one raw question map from the old CardField shape to the new
// CardQuestion shape. Returns null if the question should be dropped.
function migrateQuestion(q) {
  if (q.type === 'reveal') return null; // reveal type removed from the model

  const out = { ...q };

  // fieldId → questionId (keep whichever already exists if both somehow present)
  if (!out.questionId && out.fieldId) {
    out.questionId = out.fieldId;
  }
  delete out.fieldId;

  // name → prompt
  if (!out.prompt && out.name !== undefined) {
    out.prompt = out.name;
  }
  delete out.name;

  return out;
}

// Migrate one Firestore document. Returns true if it was (or would be) updated.
async function migrateDoc(collection, doc) {
  const data = doc.data();

  // Skip docs that have already been migrated (no legacy 'fields' key).
  if (!data.fields) return false;

  const rawFields = Array.isArray(data.fields) ? data.fields : [];
  const questions = rawFields.map(migrateQuestion).filter(Boolean);

  console.log(
    `  ${collection}/${doc.id}: ${rawFields.length} field(s) → ${questions.length} question(s)` +
      (rawFields.length !== questions.length
        ? ` (${rawFields.length - questions.length} reveal removed)`
        : '')
  );

  if (!dryRun) {
    await doc.ref.update({
      questions,
      fields: admin.firestore.FieldValue.delete(),
    });
  }

  return true;
}

async function migrateCollection(name) {
  const snap = await db.collection(name).get();
  console.log(`\n${name}/ — ${snap.size} document(s)`);

  let updated = 0;
  let skipped = 0;

  for (const doc of snap.docs) {
    const changed = await migrateDoc(name, doc);
    changed ? updated++ : skipped++;
  }

  console.log(`  updated: ${updated}, already migrated/skipped: ${skipped}`);
}

async function run() {
  await migrateCollection('cards');
  await migrateCollection('templates');

  console.log('\nMigration complete.');
  if (dryRun) console.log('(dry run — no writes performed)');
  process.exit(0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
