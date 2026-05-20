// One-shot script: for every card that is linked to a user's set via setCards
// but whose createdBy field doesn't match that user, updates createdBy to the
// set owner's userId.
//
// This fixes cards that were created under a different account (e.g. a previous
// dev/test UID) and later linked to sets owned by the current account.
//
// Prerequisites:
//   1. npm install firebase-admin   (run once in this directory)
//   2. serviceAccountKey.json present in this directory
//   3. node scripts/fix_card_createdby.js [optional: userId]
//      - If userId is supplied, only repairs cards in that user's sets.
//      - If omitted, repairs ALL users.

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const targetUserId = process.argv[2] ?? null;

async function run() {
  // Fetch all setCards (optionally scoped to one user).
  let query = db.collection('setCards');
  if (targetUserId) {
    query = query.where('userId', '==', targetUserId);
    console.log(`Scoped to userId: ${targetUserId}`);
  }

  const setCardsSnap = await query.get();
  console.log(`Found ${setCardsSnap.size} setCards document(s).`);

  // Collect unique cardId → userId mappings.
  // If the same card appears in sets owned by different users that's
  // ambiguous — we skip it and log a warning.
  const cardToUser = new Map();
  const ambiguous = new Set();

  for (const doc of setCardsSnap.docs) {
    const { cardId, userId } = doc.data();
    if (!cardId || !userId) continue;
    if (ambiguous.has(cardId)) continue;
    if (cardToUser.has(cardId) && cardToUser.get(cardId) !== userId) {
      ambiguous.add(cardId);
      cardToUser.delete(cardId);
      console.warn(`  SKIP (ambiguous owner): card ${cardId}`);
    } else {
      cardToUser.set(cardId, userId);
    }
  }

  console.log(`Unique card IDs to check: ${cardToUser.size}`);

  let fixed = 0;
  let skipped = 0;

  // Check each card and patch createdBy if it doesn't match.
  for (const [cardId, userId] of cardToUser.entries()) {
    const ref = db.collection('cards').doc(cardId);
    const snap = await ref.get();

    if (!snap.exists) {
      console.warn(`  SKIP (not found): cards/${cardId}`);
      skipped++;
      continue;
    }

    const current = snap.data().createdBy;
    if (current === userId) {
      skipped++;
      continue; // already correct
    }

    console.log(`  FIX cards/${cardId}: createdBy "${current}" → "${userId}"`);
    await ref.update({ createdBy: userId });
    fixed++;
  }

  console.log(`\nDone. Fixed: ${fixed}, Skipped/OK: ${skipped}.`);
  process.exit(0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
