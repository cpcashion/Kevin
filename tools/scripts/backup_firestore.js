// Backup all Firestore collections to JSON files
// Usage:
//   1) Ensure GOOGLE_APPLICATION_CREDENTIALS is set to a service account JSON
//   2) npm i firebase-admin
//   3) node scripts/backup_firestore.js

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

// List the collections you want to back up
const collections = [
  'businesses',
  'restaurants', // legacy
  'locations',
  'issues',
  'workOrders', // legacy
  'workorders', // legacy
  'workLogs',   // legacy
  'worklogs',   // legacy
  'issuePhotos',
  'receipts',
  'quotes',
  'conversations',
  'users',
  'notificationTriggers',
  'debug_logs'
];

async function ensureDir(dir) {
  await fs.promises.mkdir(dir, { recursive: true });
}

async function backupCollection(colName, outDir) {
  const filePath = path.join(outDir, `${colName}.json`);
  console.log(`\n📦 Backing up collection: ${colName} -> ${filePath}`);

  const snapshot = await db.collection(colName).get();
  const records = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    // Convert Firestore Timestamps to ISO strings
    const converted = JSON.parse(JSON.stringify(data, (key, value) => {
      if (value && value._seconds !== undefined && value._nanoseconds !== undefined) {
        return new Date(value._seconds * 1000).toISOString();
      }
      return value;
    }));

    records.push({ id: doc.id, ...converted });
  }

  await fs.promises.writeFile(filePath, JSON.stringify(records, null, 2));
  console.log(`✅ Wrote ${records.length} docs`);
}

async function main() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const outDir = path.join(__dirname, '..', 'backups', timestamp);
  await ensureDir(outDir);

  for (const col of collections) {
    try {
      await backupCollection(col, outDir);
    } catch (err) {
      console.warn(`⚠️  Failed to back up ${col}:`, err.message);
    }
  }

  console.log(`\n🎉 Backup completed: ${outDir}`);
}

main().catch(err => {
  console.error('❌ Backup failed:', err);
  process.exit(1);
});
