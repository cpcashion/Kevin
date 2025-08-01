// Firebase Admin Script to Delete All Issues and Work Orders
// Run this with: node delete_all_data.js

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json'); // You'll need to download this from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deleteCollection(collectionPath, batchSize = 100) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(db, query, resolve).catch(reject);
  });
}

async function deleteQueryBatch(db, query, resolve) {
  const snapshot = await query.get();

  const batchSize = snapshot.size;
  if (batchSize === 0) {
    resolve();
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  console.log(`Deleted ${batchSize} documents`);

  // Recurse on the next process tick to avoid stack overflow
  process.nextTick(() => {
    deleteQueryBatch(db, query, resolve);
  });
}

async function deleteAllIssuesAndWorkOrders() {
  console.log('🗑️  Starting deletion process...\n');

  try {
    // 1. Delete all maintenance requests and their subcollections
    console.log('📋 Fetching all maintenance requests...');
    const requestsSnapshot = await db.collection('maintenance_requests').get();
    console.log(`Found ${requestsSnapshot.size} maintenance requests\n`);

    let deletedCount = 0;
    
    for (const requestDoc of requestsSnapshot.docs) {
      const requestId = requestDoc.id;
      console.log(`Processing request: ${requestId}`);

      // Delete subcollections
      const subcollections = ['thread_messages', 'thread_cache', 'work_logs'];
      
      for (const subcollection of subcollections) {
        const subcollectionRef = requestDoc.ref.collection(subcollection);
        const subcollectionSnapshot = await subcollectionRef.get();
        
        if (subcollectionSnapshot.size > 0) {
          console.log(`  - Deleting ${subcollectionSnapshot.size} documents from ${subcollection}`);
          const batch = db.batch();
          subcollectionSnapshot.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
        }
      }

      // Delete the main document
      await requestDoc.ref.delete();
      deletedCount++;
      console.log(`  ✅ Deleted request ${deletedCount}/${requestsSnapshot.size}\n`);
    }

    // 2. Delete all work orders
    console.log('🔧 Deleting work orders...');
    const workOrdersSnapshot = await db.collection('work_orders').get();
    console.log(`Found ${workOrdersSnapshot.size} work orders`);
    
    if (workOrdersSnapshot.size > 0) {
      const batch = db.batch();
      workOrdersSnapshot.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      console.log(`✅ Deleted ${workOrdersSnapshot.size} work orders\n`);
    }

    // 3. Delete issue photos
    console.log('📸 Deleting issue photos...');
    const photosSnapshot = await db.collection('issuePhotos').get();
    console.log(`Found ${photosSnapshot.size} photos`);
    
    if (photosSnapshot.size > 0) {
      const batch = db.batch();
      photosSnapshot.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      console.log(`✅ Deleted ${photosSnapshot.size} photos\n`);
    }

    console.log('✅ All issues and work orders deleted successfully!');
    console.log('\n📊 Summary:');
    console.log(`   - Maintenance Requests: ${requestsSnapshot.size}`);
    console.log(`   - Work Orders: ${workOrdersSnapshot.size}`);
    console.log(`   - Issue Photos: ${photosSnapshot.size}`);
    console.log('\n🎉 Database is now clean and ready for App Store launch!');

  } catch (error) {
    console.error('❌ Error during deletion:', error);
  }

  process.exit(0);
}

// Run the deletion
deleteAllIssuesAndWorkOrders();
