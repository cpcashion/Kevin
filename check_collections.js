const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin using the same pattern as existing scripts
(() => {
  if (admin.apps.length) return;
  const saPath = path.join(__dirname, 'tools/scripts/serviceAccount.json');
  if (fs.existsSync(saPath)) {
    console.log('🔐 Using local serviceAccount.json credentials');
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } else {
    console.log('🔐 Using GOOGLE_APPLICATION_CREDENTIALS / Application Default Credentials');
    admin.initializeApp({ 
      credential: admin.credential.applicationDefault(),
      projectId: 'kevin-ios-app'
    });
  }
})();

const db = admin.firestore();

async function checkCollections() {
  console.log('🔍 Checking available collections...');
  
  try {
    // List all collections
    const collections = await db.listCollections();
    console.log(`📋 Found ${collections.length} collections:`);
    
    for (const collection of collections) {
      console.log(`  - ${collection.id}`);
      
      // Get a sample document from each collection
      const snapshot = await collection.limit(1).get();
      if (!snapshot.empty) {
        const doc = snapshot.docs[0];
        console.log(`    Sample doc ID: ${doc.id}`);
        const data = doc.data();
        console.log(`    Sample fields: ${Object.keys(data).join(', ')}`);
      } else {
        console.log(`    (empty collection)`);
      }
    }
    
    // Specifically check maintenance_requests
    console.log('\n🔍 Checking maintenance_requests collection...');
    const requestsSnapshot = await db.collection('maintenance_requests').limit(5).get();
    console.log(`📋 Found ${requestsSnapshot.size} maintenance requests`);
    
    requestsSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`  - ${doc.id}: businessId=${data.businessId}, status=${data.status}`);
    });
    
    // Also check issues collection
    console.log('\n🔍 Checking issues collection...');
    const issuesSnapshot = await db.collection('issues').limit(10).get();
    console.log(`📋 Found ${issuesSnapshot.size} issues`);
    
    issuesSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`  - ${doc.id}: locationId=${data.locationId}, restaurantId=${data.restaurantId}, status=${data.status}`);
    });
    
  } catch (error) {
    console.error('❌ Error checking collections:', error);
  }
  
  process.exit(0);
}

checkCollections();
