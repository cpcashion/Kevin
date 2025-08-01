// DANGER: This script deletes ALL data from specified Firestore collections.
// Run ONLY after you have run backup_firestore.js and verified the backup folder.
// Usage:
//   1) Ensure GOOGLE_APPLICATION_CREDENTIALS is set to a service account JSON
//   2) npm i firebase-admin
//   3) node scripts/delete_all_collections.js

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Initialize Admin SDK using local service account if available, else ADC
(() => {
  if (admin.apps.length) return;
  const saPath = path.join(__dirname, 'serviceAccount.json');
  if (fs.existsSync(saPath)) {
    console.log('🔐 Using local serviceAccount.json credentials');
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } else {
    console.log('🔐 Using GOOGLE_APPLICATION_CREDENTIALS / Application Default Credentials');
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
})();

const db = admin.firestore();

// Collections to delete (top-level only)
const collections = [
  'businesses',
  'restaurants',
  'locations',
  'issues',
  'workOrders',
  'workorders',
  'workLogs',
  'worklogs',
  'issuePhotos',
  'receipts',
  'quotes',
  'conversations',
  'users',
  'notificationTriggers',
  'debug_logs'
];

// Optionally keep core v2 collections
const KEEP_CORE = process.env.KEEP_CORE === '1' || process.env.KEEP_CORE === 'true';
const CORE_COLLECTIONS = new Set(['businesses', 'maintenance_requests', 'users']);
const targets = KEEP_CORE ? collections.filter((c) => !CORE_COLLECTIONS.has(c)) : collections;

async function deleteCollection(colName, batchSize = 300) {
  console.log(`\n🧨 Deleting collection: ${colName}`);

  while (true) {
    const snapshot = await db.collection(colName).limit(batchSize).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    console.log(`  Deleted ${snapshot.size} docs...`);
  }

  console.log(`✅ Finished deleting ${colName}`);
}

async function main() {
  for (const col of targets) {
    try {
      await deleteCollection(col);
    } catch (err) {
      console.warn(`⚠️  Failed to delete ${col}:`, err.message);
    }
  }
  console.log('\n🎉 All specified collections deleted');
}

main().catch((err) => {
  console.error('❌ Deletion failed:', err);
  process.exit(1);
});
