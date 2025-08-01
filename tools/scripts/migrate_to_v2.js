// Firestore migration: legacy -> v2 unified architecture
// Usage:
//   1) Ensure GOOGLE_APPLICATION_CREDENTIALS is set or place serviceAccount.json next to this file
//   2) npm i (firebase-admin installed)
//   3) node migrate_to_v2.js

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

function ts(date) {
  return date ? admin.firestore.Timestamp.fromDate(new Date(date)) : null;
}

function mapPriority(p) {
  if (!p) return 'medium';
  const s = String(p).toLowerCase();
  if (s.includes('crit')) return 'critical';
  if (s.includes('high')) return 'high';
  if (s.includes('low')) return 'low';
  return 'medium';
}

function mapStatus(s) {
  if (!s) return 'reported';
  const v = String(s).toLowerCase();
  if (v.includes('progress')) return 'in_progress';
  if (v.includes('complete') || v.includes('resolved')) return 'completed';
  return 'reported';
}

function mapCategory(c) {
  if (!c) return 'other';
  const v = String(c).toLowerCase();
  if (v.includes('hvac') || v.includes('ac') || v.includes('air')) return 'hvac';
  if (v.includes('elect')) return 'electrical';
  if (v.includes('plumb')) return 'plumbing';
  if (v.includes('kitchen')) return 'kitchen';
  if (v.includes('door') || v.includes('window')) return 'doors_windows';
  if (v.includes('refrig') || v.includes('walk-in') || v.includes('cooler')) return 'refrigeration';
  if (v.includes('floor')) return 'flooring';
  if (v.includes('paint')) return 'painting';
  if (v.includes('clean')) return 'cleaning';
  return 'other';
}

async function upsertBusinessesFromRestaurants() {
  const snap = await db.collection('restaurants').get();
  let count = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    const out = {
      name: d.name || '',
      businessType: 'restaurant',
      address: d.address || null,
      phone: d.phone || null,
      website: d.website || null,
      logoUrl: d.logoUrl || null,
      placeId: d.placeId || null,
      latitude: d.latitude || null,
      longitude: d.longitude || null,
      businessHours: d.businessHours || null,
      category: d.cuisine || d.category || null,
      priceLevel: d.priceLevel || null,
      rating: d.rating || null,
      totalRatings: d.totalRatings || null,
      ownerId: d.ownerId || null,
      createdAt: d.createdAt || admin.firestore.Timestamp.now(),
      isActive: d.isActive ?? true,
      verificationStatus: d.verificationStatus || 'pending',
      verificationMethod: d.verificationMethod || null,
      verifiedAt: d.verifiedAt || null,
      verificationData: d.verificationData || null,
    };
    await db.collection('businesses').doc(doc.id).set(out, { merge: true });
    count++;
  }
  console.log(`🏪 Migrated/merged ${count} restaurants into businesses`);
}

async function migrateIssuesToRequests() {
  const issuesSnap = await db.collection('issues').get();
  let reqCount = 0;

  for (const issueDoc of issuesSnap.docs) {
    const i = issueDoc.data();
    const id = i.id || issueDoc.id;

    // Base request doc
    const requestData = {
      id,
      businessId: i.restaurantId || i.businessId || 'default',
      locationId: i.locationId || null,
      reporterId: i.reporterId || null,
      assigneeId: i.assigneeId || null,
      title: i.title || 'Untitled',
      description: i.description || '',
      category: mapCategory(i.type || i.category),
      priority: mapPriority(i.priority),
      status: mapStatus(i.status),
      createdAt: i.createdAt || admin.firestore.Timestamp.now(),
      updatedAt: i.updatedAt || i.createdAt || admin.firestore.Timestamp.now(),
    };

    // Try to merge workOrder status/timestamps for same issue
    const workOrdersSnap = await db.collection('workOrders').where('issueId', '==', id).orderBy('createdAt', 'desc').limit(1).get();
    if (!workOrdersSnap.empty) {
      const wo = workOrdersSnap.docs[0].data();
      if (wo.scheduledAt) requestData.scheduledAt = wo.scheduledAt;
      if (wo.startedAt) requestData.startedAt = wo.startedAt;
      if (wo.completedAt) requestData.completedAt = wo.completedAt;
      if (wo.status) requestData.status = mapStatus(wo.status);
      if (wo.assigneeId) requestData.assigneeId = wo.assigneeId;
    }

    // Gather photo URLs for convenience on doc
    const photosSnap = await db.collection('issuePhotos').where('issueId', '==', id).get();
    const photoUrls = [];
    for (const p of photosSnap.docs) {
      const pd = p.data();
      if (pd.url) photoUrls.push(pd.url);
    }
    if (photoUrls.length) requestData.photoUrls = photoUrls;

    // Write request doc
    const reqRef = db.collection('maintenance_requests').doc(id);
    await reqRef.set(requestData, { merge: true });

    // Write photos subcollection
    for (const p of photosSnap.docs) {
      const pd = p.data();
      const photoId = pd.id || p.id;
      const out = {
        id: photoId,
        requestId: id,
        url: pd.url || '',
        thumbUrl: pd.thumbUrl || pd.url || null,
        uploaderId: pd.uploaderId || null,
        takenAt: pd.takenAt || pd.uploadedAt || admin.firestore.Timestamp.now(),
      };
      await reqRef.collection('photos').doc(photoId).set(out, { merge: true });
    }

    // Write updates (work logs) subcollection
    const logsSnap = await db.collection('workLogs').where('issueId', '==', id).orderBy('createdAt', 'asc').get();
    for (const l of logsSnap.docs) {
      const ld = l.data();
      const updId = ld.id || l.id;
      const out = {
        id: updId,
        requestId: id,
        authorId: ld.authorId || null,
        message: ld.message || '',
        createdAt: ld.createdAt || admin.firestore.Timestamp.now(),
      };
      await reqRef.collection('updates').doc(updId).set(out, { merge: true });
    }

    reqCount++;
  }

  console.log(`🛠️ Migrated ${reqCount} issues into maintenance_requests`);
}

async function main() {
  console.log('🚀 Starting migration to v2...');
  await upsertBusinessesFromRestaurants();
  await migrateIssuesToRequests();
  console.log('🎉 Migration complete.');
}

main().catch((err) => {
  console.error('❌ Migration failed:', err);
  process.exit(1);
});
