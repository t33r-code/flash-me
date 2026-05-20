// One-shot script: sets nativeLanguage='en' + targetLanguage='cs' on every
// card and set document in Firestore.
//
// Prerequisites:
//   1. npm install firebase-admin   (run once in this directory)
//   2. Download a service account key from Firebase Console:
//      Project Settings → Service accounts → Generate new private key
//      Save the file as scripts/serviceAccountKey.json
//   3. node scripts/seed_languages.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Commit a batch and return a fresh one — Firestore limit is 500 ops per batch.
async function flush(batch) {
  await batch.commit();
  return db.batch();
}

async function updateCollection(collectionName) {
  const snapshot = await db.collection(collectionName).get();
  console.log(`${collectionName}: ${snapshot.size} documents found`);

  let batch = db.batch();
  let pending = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, { nativeLanguage: 'en', targetLanguage: 'cs' });
    pending++;
    if (pending === 499) {       // flush before hitting the 500-op limit
      batch = await flush(batch);
      pending = 0;
    }
  }

  if (pending > 0) await flush(batch);
  console.log(`${collectionName}: done`);
}

(async () => {
  await updateCollection('cards');
  await updateCollection('sets');
  console.log('All done.');
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
