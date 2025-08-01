const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
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

async function checkBusinesses() {
  console.log('🏢 Checking businesses collection...');
  
  try {
    const businessesSnapshot = await db.collection('businesses').get();
    console.log(`📋 Found ${businessesSnapshot.size} businesses`);
    
    businessesSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`\n🏪 Business: ${data.name}`);
      console.log(`   ID: ${doc.id}`);
      console.log(`   Place ID: ${data.placeId}`);
      console.log(`   Address: ${data.address}`);
      console.log(`   Coordinates: (${data.latitude}, ${data.longitude})`);
    });
    
    // Also check restaurants collection
    console.log('\n🍽️ Checking restaurants collection...');
    const restaurantsSnapshot = await db.collection('restaurants').get();
    console.log(`📋 Found ${restaurantsSnapshot.size} restaurants`);
    
    restaurantsSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`\n🍽️ Restaurant: ${data.name}`);
      console.log(`   ID: ${doc.id}`);
      console.log(`   Place ID: ${data.placeId}`);
      console.log(`   Address: ${data.address}`);
      console.log(`   Coordinates: (${data.latitude}, ${data.longitude})`);
    });
    
  } catch (error) {
    console.error('❌ Error checking businesses:', error);
  }
  
  process.exit(0);
}

checkBusinesses();
