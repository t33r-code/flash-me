// One-shot script: backfills CardSet.authorDisplayName on every already-public
// set that doesn't have it yet, by reading the owner's users/{uid} doc via the
// Admin SDK (which bypasses Firestore rules).
//
// Why this exists: #297 denormalizes the set owner's display name onto the set
// document at publish time, so the client never has to read another user's
// private users/{uid} doc to show a Market creator name. That only covers sets
// published AFTER the client change ships. This script backfills sets that
// were already public before then, so the tightened `users/{uid}` rule
// (owner-only read) doesn't leave old Market listings showing no creator name.
//
// Deploy sequencing (see PR for #297):
//   1. Ship the app code (client writes authorDisplayName going forward).
//   2. Run this script (dry-run first, then --apply) to backfill existing
//      public sets.
//   3. Deploy the tightened firestore.rules.
// Running this script before step 3 is safe either way (it uses the Admin
// SDK, not client rules) — sequencing above is about not tightening the rule
// before the backfill exists, not about this script's own dependencies.
//
// Prerequisites:
//   1. npm install firebase-admin   (run once in this directory)
//   2. serviceAccountKey.json present in this directory
//   3. node scripts/backfill_author_display_names.js            (dry run — logs only)
//      node scripts/backfill_author_display_names.js --apply     (writes changes)

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const apply = process.argv.includes('--apply');

async function run() {
  console.log(apply ? 'Running in APPLY mode.' : 'Running in DRY-RUN mode (pass --apply to write changes).');

  const setsSnap = await db
      .collection('sets')
      .where('isPublic', '==', true)
      .get();
  console.log(`Found ${setsSnap.size} public set(s).`);

  const toBackfill = setsSnap.docs.filter((doc) => !doc.data().authorDisplayName);
  console.log(`${toBackfill.length} of them are missing authorDisplayName.`);

  // Cache displayName lookups — many sets share the same owner.
  const displayNameByUid = new Map();

  let updated = 0;
  let skippedNoUser = 0;
  let skippedNoName = 0;

  for (const doc of toBackfill) {
    const { userId, name } = doc.data();
    if (!userId) {
      console.warn(`  SKIP (no userId): sets/${doc.id} "${name}"`);
      skippedNoUser++;
      continue;
    }

    if (!displayNameByUid.has(userId)) {
      const userDoc = await db.collection('users').doc(userId).get();
      displayNameByUid.set(userId, userDoc.exists ? userDoc.data().displayName ?? null : null);
    }
    const displayName = displayNameByUid.get(userId);

    if (!displayName) {
      console.warn(`  SKIP (owner has no displayName): sets/${doc.id} "${name}" (userId ${userId})`);
      skippedNoName++;
      continue;
    }

    console.log(`  ${apply ? 'SET' : 'WOULD SET'} sets/${doc.id} "${name}": authorDisplayName = "${displayName}"`);
    if (apply) {
      await doc.ref.update({ authorDisplayName: displayName });
    }
    updated++;
  }

  console.log(
      `\nDone. ${apply ? 'Updated' : 'Would update'}: ${updated}, ` +
      `skipped (no userId): ${skippedNoUser}, skipped (owner has no displayName): ${skippedNoName}.`,
  );
  process.exit(0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
