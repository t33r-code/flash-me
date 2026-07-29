// Security rules tests for #285 — verifies the allow/deny paths for every fix
// in docs/security/firebase-rules-review.md (R1-R6) plus the owner-only
// users/{uid} read from #297.
//
// Run against the local emulator (never touches production):
//   firebase emulators:exec --only firestore,storage "npm --prefix firestore-tests test"
// (see README.md in this directory)
//
// Written as a plain Node script with a minimal manual test runner — no test
// framework dependency, matching the project's existing lean scripts/*.js style.

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, setDoc, updateDoc, deleteDoc, getDoc,
} = require('firebase/firestore');
const {
  ref, uploadBytes, deleteObject,
} = require('firebase/storage');

const PROJECT_ID = 'demo-flash-me-rules-test';

let testEnv;
const tests = [];
function test(name, fn) { tests.push({ name, fn }); }

// ---------------------------------------------------------------------------
// R1 — setCards create must verify ownership of the referenced set and card.
// ---------------------------------------------------------------------------
test('setCards create succeeds when the creator owns both the set and the card', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'sets/aliceSet'), { userId: 'alice', isPublic: false });
    await setDoc(doc(db, 'cards/aliceCard'), { createdBy: 'alice' });
  });
  await assertSucceeds(setDoc(doc(alice, 'setCards/link1'), {
    setId: 'aliceSet', cardId: 'aliceCard', userId: 'alice', cardType: 'flashcard',
  }));
});

test('setCards create fails when the set belongs to another user', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'sets/bobSet'), { userId: 'bob', isPublic: false });
    await setDoc(doc(db, 'cards/aliceCard2'), { createdBy: 'alice' });
  });
  await assertFails(setDoc(doc(alice, 'setCards/link2'), {
    setId: 'bobSet', cardId: 'aliceCard2', userId: 'alice', cardType: 'flashcard',
  }));
});

test('setCards create fails when the flashcard belongs to another user', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'sets/aliceSet3'), { userId: 'alice', isPublic: false });
    await setDoc(doc(db, 'cards/bobCard'), { createdBy: 'bob' });
  });
  await assertFails(setDoc(doc(alice, 'setCards/link3'), {
    setId: 'aliceSet3', cardId: 'bobCard', userId: 'alice', cardType: 'flashcard',
  }));
});

test('setCards create fails when the workbook card belongs to another user', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'sets/aliceSet4'), { userId: 'alice', isPublic: false });
    await setDoc(doc(db, 'workbookCards/bobWbCard'), { createdBy: 'bob' });
  });
  await assertFails(setDoc(doc(alice, 'setCards/link4'), {
    setId: 'aliceSet4', cardId: 'bobWbCard', userId: 'alice', cardType: 'workbook',
  }));
});

test('setCards create succeeds for an owned workbook card', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'sets/aliceSet5'), { userId: 'alice', isPublic: false });
    await setDoc(doc(db, 'workbookCards/aliceWbCard'), { createdBy: 'alice' });
  });
  await assertSucceeds(setDoc(doc(alice, 'setCards/link5'), {
    setId: 'aliceSet5', cardId: 'aliceWbCard', userId: 'alice', cardType: 'workbook',
  }));
});

// ---------------------------------------------------------------------------
// R2 — sets.acquisitionCount: public-only, exactly +1, no other field changes.
// ---------------------------------------------------------------------------
test('sets acquisitionCount +1 succeeds on a PUBLIC set by another user', async () => {
  const bob = testEnv.authenticatedContext('bob').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'sets/publicSet1'), {
      userId: 'alice', isPublic: true, acquisitionCount: 3,
    });
  });
  await assertSucceeds(updateDoc(doc(bob, 'sets/publicSet1'), { acquisitionCount: 4 }));
});

test('sets acquisitionCount update fails on a PRIVATE set by another user', async () => {
  const bob = testEnv.authenticatedContext('bob').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'sets/privateSet1'), {
      userId: 'alice', isPublic: false, acquisitionCount: 0,
    });
  });
  await assertFails(updateDoc(doc(bob, 'sets/privateSet1'), { acquisitionCount: 1 }));
});

test('sets acquisitionCount jump (not +1) fails even on a public set', async () => {
  const bob = testEnv.authenticatedContext('bob').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'sets/publicSet2'), {
      userId: 'alice', isPublic: true, acquisitionCount: 0,
    });
  });
  await assertFails(updateDoc(doc(bob, 'sets/publicSet2'), { acquisitionCount: 999 }));
});

test('sets update touching another field alongside acquisitionCount fails for a non-owner', async () => {
  const bob = testEnv.authenticatedContext('bob').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'sets/publicSet3'), {
      userId: 'alice', isPublic: true, acquisitionCount: 0, name: 'Alice Set',
    });
  });
  await assertFails(updateDoc(doc(bob, 'sets/publicSet3'), {
    acquisitionCount: 1, name: 'Hijacked',
  }));
});

test('the owner can still update their own set freely', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'sets/ownSet1'), {
      userId: 'alice', isPublic: false, name: 'Old name',
    });
  });
  await assertSucceeds(updateDoc(doc(alice, 'sets/ownSet1'), { name: 'New name' }));
});

// ---------------------------------------------------------------------------
// R3 — cards/workbookCards: a missing createdBy must fail closed.
// ---------------------------------------------------------------------------
test('cards update fails for ANY user when createdBy is missing (fail-closed)', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'cards/noOwnerCard'), { primaryWord: 'x' });
  });
  await assertFails(updateDoc(doc(alice, 'cards/noOwnerCard'), { primaryWord: 'y' }));
});

test('cards update succeeds for the true owner when createdBy is present', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'cards/ownedCard'), {
      primaryWord: 'x', createdBy: 'alice',
    });
  });
  await assertSucceeds(updateDoc(doc(alice, 'cards/ownedCard'), { primaryWord: 'y' }));
});

test('cards update fails for a non-owner when createdBy is present', async () => {
  const bob = testEnv.authenticatedContext('bob').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'cards/aliceOwnedCard'), {
      primaryWord: 'x', createdBy: 'alice',
    });
  });
  await assertFails(updateDoc(doc(bob, 'cards/aliceOwnedCard'), { primaryWord: 'y' }));
});

test('workbookCards update fails for ANY user when createdBy is missing (fail-closed)', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'workbookCards/noOwnerWb'), { prompt: 'x' });
  });
  await assertFails(updateDoc(doc(alice, 'workbookCards/noOwnerWb'), { prompt: 'y' }));
});

// ---------------------------------------------------------------------------
// R4 — tags.usageCount must move by exactly ±1.
// ---------------------------------------------------------------------------
test('tags update succeeds for a +1 usageCount change', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'tags/spanish'), {
      displayName: 'Spanish', createdBy: 'alice', normalizedName: 'spanish', usageCount: 1,
    });
  });
  await assertSucceeds(updateDoc(doc(alice, 'tags/spanish'), { usageCount: 2 }));
});

test('tags update succeeds for a -1 usageCount change', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'tags/french'), {
      displayName: 'French', createdBy: 'alice', normalizedName: 'french', usageCount: 2,
    });
  });
  await assertSucceeds(updateDoc(doc(alice, 'tags/french'), { usageCount: 1 }));
});

test('tags update fails for an arbitrary (non ±1) usageCount jump', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'tags/german'), {
      displayName: 'German', createdBy: 'alice', normalizedName: 'german', usageCount: 1,
    });
  });
  await assertFails(updateDoc(doc(alice, 'tags/german'), { usageCount: 50 }));
});

test('tags update fails when displayName is changed', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'tags/italian'), {
      displayName: 'Italian', createdBy: 'alice', normalizedName: 'italian', usageCount: 1,
    });
  });
  await assertFails(updateDoc(doc(alice, 'tags/italian'), {
    displayName: 'Renamed', usageCount: 2,
  }));
});

// ---------------------------------------------------------------------------
// R5 — templates/questionTemplates: createdBy must be immutable on update.
// ---------------------------------------------------------------------------
test('templates update succeeds when createdBy is unchanged', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'templates/tpl1'), {
      createdBy: 'alice', name: 'Old',
    });
  });
  await assertSucceeds(updateDoc(doc(alice, 'templates/tpl1'), { name: 'New' }));
});

test('templates update fails when createdBy is reassigned', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'templates/tpl2'), {
      createdBy: 'alice', name: 'Old',
    });
  });
  await assertFails(updateDoc(doc(alice, 'templates/tpl2'), { createdBy: 'bob' }));
});

test('questionTemplates update fails when createdBy is reassigned', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'questionTemplates/qtpl1'), {
      createdBy: 'alice', name: 'Old',
    });
  });
  await assertFails(updateDoc(doc(alice, 'questionTemplates/qtpl1'), { createdBy: 'bob' }));
});

// ---------------------------------------------------------------------------
// #297 regression — users/{uid} must stay owner-only read.
// ---------------------------------------------------------------------------
test('users/{uid} read succeeds for the owner', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), { email: 'alice@example.com' });
  });
  await assertSucceeds(getDoc(doc(alice, 'users/alice')));
});

test('users/{uid} read fails for another authenticated user (#297 regression)', async () => {
  const bob = testEnv.authenticatedContext('bob').firestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice2'), { email: 'alice2@example.com' });
  });
  await assertFails(getDoc(doc(bob, 'users/alice2')));
});

// ---------------------------------------------------------------------------
// R6 — Storage: size cap, content-type restriction, delete unaffected.
// ---------------------------------------------------------------------------
const smallPng = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]); // PNG magic bytes

test('storage upload succeeds under the 10MB cap with an image content type', async () => {
  const alice = testEnv.authenticatedContext('alice').storage();
  await assertSucceeds(uploadBytes(
    ref(alice, 'users/alice/cards/ok.png'), smallPng, { contentType: 'image/png' },
  ));
});

test('storage upload fails over the 10MB cap', async () => {
  const alice = testEnv.authenticatedContext('alice').storage();
  const big = Buffer.alloc(11 * 1024 * 1024, 1);
  await assertFails(uploadBytes(
    ref(alice, 'users/alice/cards/big.png'), big, { contentType: 'image/png' },
  ));
});

test('storage upload fails for a disallowed content type', async () => {
  const alice = testEnv.authenticatedContext('alice').storage();
  await assertFails(uploadBytes(
    ref(alice, 'users/alice/cards/evil.html'), smallPng, { contentType: 'text/html' },
  ));
});

test('storage upload fails when uid does not match the path owner', async () => {
  const bob = testEnv.authenticatedContext('bob').storage();
  await assertFails(uploadBytes(
    ref(bob, 'users/alice/cards/intruder.png'), smallPng, { contentType: 'image/png' },
  ));
});

test('storage delete still succeeds under the owner path (no request.resource on delete)', async () => {
  const alice = testEnv.authenticatedContext('alice').storage();
  await uploadBytes(
    ref(alice, 'users/alice/cards/toDelete.png'), smallPng, { contentType: 'image/png' },
  );
  await assertSucceeds(deleteObject(ref(alice, 'users/alice/cards/toDelete.png')));
});

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------
async function main() {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8'),
    },
  });

  let passed = 0;
  let failed = 0;
  for (const { name, fn } of tests) {
    await testEnv.clearFirestore();
    try {
      await fn();
      console.log(`  PASS  ${name}`);
      passed++;
    } catch (err) {
      console.log(`  FAIL  ${name}`);
      console.log(`        ${err.message.split('\n')[0]}`);
      failed++;
    }
  }

  await testEnv.cleanup();
  console.log(`\n${passed} passed, ${failed} failed (${tests.length} total).`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
