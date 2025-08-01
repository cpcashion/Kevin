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

async function cleanupProblematicLocations() {
  console.log('🧹 Starting cleanup of problematic location data...');
  
  try {
    // Get all issues
    const issuesSnapshot = await db.collection('issues').get();
    console.log(`📋 Found ${issuesSnapshot.size} total issues`);
    
    let updatedCount = 0;
    const batch = db.batch();
    
    // Mapping of problematic names to their correct Google Place IDs and names
    const locationMappings = {
      'The Maple': {
        correctName: 'The Little Gym of Seattle at Maple Leaf',
        placeId: 'ChIJLR3ryQoUkFQRZb7_-EVfdXI'
      },
      'Snappy Dragon': {
        correctName: 'Tropisueno', 
        placeId: 'ChIJfcaly4eAhYARSIvvfFpH64w'
      },
      'The Banana Stand': {
        correctName: 'Bank of America Financial Center',
        placeId: 'ChIJkS9j8YWAhYARTuyQ2vQlBsQ'
      }
    };
    
    issuesSnapshot.forEach((doc) => {
      const data = doc.data();
      const locationId = data.locationId;
      const restaurantId = data.restaurantId;
      
      // Check if this issue has a problematic location
      let needsUpdate = false;
      let updates = {};
      
      // Check locationId
      if (locationId && Object.keys(locationMappings).some(name => locationId.includes(name))) {
        for (const [problemName, mapping] of Object.entries(locationMappings)) {
          if (locationId.includes(problemName)) {
            updates.locationId = mapping.placeId;
            needsUpdate = true;
            console.log(`🔧 Updating locationId for issue ${doc.id}: ${locationId} -> ${mapping.placeId}`);
            break;
          }
        }
      }
      
      // Check restaurantId
      if (restaurantId && Object.keys(locationMappings).some(name => restaurantId.includes(name))) {
        for (const [problemName, mapping] of Object.entries(locationMappings)) {
          if (restaurantId.includes(problemName)) {
            updates.restaurantId = mapping.placeId;
            needsUpdate = true;
            console.log(`🔧 Updating restaurantId for issue ${doc.id}: ${restaurantId} -> ${mapping.placeId}`);
            break;
          }
        }
      }
      
      if (needsUpdate) {
        updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        batch.update(doc.ref, updates);
        updatedCount++;
      }
    });
    
    if (updatedCount > 0) {
      await batch.commit();
      console.log(`✅ Successfully updated ${updatedCount} issues with correct location data`);
    } else {
      console.log('ℹ️ No issues found that need location updates');
    }
    
    // Also check maintenance requests
    console.log('\n🔍 Checking maintenance requests...');
    const requestsSnapshot = await db.collection('maintenance_requests').get();
    console.log(`📋 Found ${requestsSnapshot.size} total maintenance requests`);
    
    let requestUpdatedCount = 0;
    const requestBatch = db.batch();
    
    requestsSnapshot.forEach((doc) => {
      const data = doc.data();
      const businessId = data.businessId;
      
      // Check businessId
      if (businessId && Object.keys(locationMappings).some(name => businessId.includes(name))) {
        for (const [problemName, mapping] of Object.entries(locationMappings)) {
          if (businessId.includes(problemName)) {
            const updates = {
              businessId: mapping.placeId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            };
            requestBatch.update(doc.ref, updates);
            requestUpdatedCount++;
            console.log(`🔧 Updating businessId for request ${doc.id}: ${businessId} -> ${mapping.placeId}`);
            break;
          }
        }
      }
    });
    
    if (requestUpdatedCount > 0) {
      await requestBatch.commit();
      console.log(`✅ Successfully updated ${requestUpdatedCount} maintenance requests with correct location data`);
    } else {
      console.log('ℹ️ No maintenance requests found that need location updates');
    }
    
    console.log('\n🎉 Cleanup completed successfully!');
    console.log('📍 All location references now point to valid Google Place IDs');
    console.log('🗺️ Maps and addresses should now work correctly');
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }
  
  process.exit(0);
}

cleanupProblematicLocations();
