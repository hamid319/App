'use strict';

// One-off: copies name, photo and PayPal handle from /users/{uid} to
// /publicProfiles/{uid} for accounts that have not opened the app since
// publicProfiles was added (2026-11-15). Without it, trip members see
// "Member N" for them. Existing public profiles are left alone: the app
// keeps those up to date.
//
//   cd functions
//   node scripts/backfill-public-profiles.js            # dry run, writes nothing
//   node scripts/backfill-public-profiles.js --write    # writes
//
// Uses Application Default Credentials (gcloud auth application-default login).

// Same fields and limits as match /publicProfiles in firestore.rules.
const LIMITS = { displayName: 100, photoUrl: 2048, paypalHandle: 64 };

/** The public part of a /users document, or null when there is nothing to show. */
function publicFields(user) {
  const out = {};
  for (const [field, max] of Object.entries(LIMITS)) {
    const value = user[field];
    if (typeof value === 'string' && value.trim() && value.length <= max) out[field] = value;
  }
  return Object.keys(out).length ? out : null;
}

async function main() {
  const { initializeApp } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  const write = process.argv.includes('--write');
  initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'travelapp-31255' });
  const db = getFirestore();

  const [users, existing] = await Promise.all([
    db.collection('users').get(),
    db.collection('publicProfiles').select().get(),
  ]);
  const have = new Set(existing.docs.map((d) => d.id));

  const todo = [];
  for (const doc of users.docs) {
    if (have.has(doc.id)) continue;
    const fields = publicFields(doc.data());
    if (fields) todo.push([doc.id, fields]);
  }
  console.log(`${users.size} users, ${have.size} public profiles, ${todo.length} to create.`);
  for (const [uid, fields] of todo) console.log(`  ${uid}: ${fields.displayName ?? '(no name)'}`);

  if (!write) {
    console.log('Dry run. Run again with --write to create them.');
    return;
  }
  for (let i = 0; i < todo.length; i += 400) {
    const batch = db.batch();
    for (const [uid, fields] of todo.slice(i, i + 400)) {
      // create(): fails instead of overwriting if the app wrote one meanwhile.
      batch.create(db.collection('publicProfiles').doc(uid), fields);
    }
    await batch.commit();
  }
  console.log(`Created ${todo.length} public profiles.`);
}

module.exports = { publicFields };

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
