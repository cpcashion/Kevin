const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin SDK
const serviceAccount = require('./functions/service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://kevin-ios-app-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function listAllBusinesses() {
  try {
    console.log('🔍 Querying Firebase for all businesses...\n');
    
    // Query restaurants collection
    const restaurantsSnapshot = await db.collection('restaurants').orderBy('name').get();
    
    // Query businesses collection (if it exists)
    let businessesSnapshot;
    try {
      businessesSnapshot = await db.collection('businesses').orderBy('name').get();
    } catch (error) {
      console.log('ℹ️  No businesses collection found, only checking restaurants');
      businessesSnapshot = { docs: [] };
    }
    
    const allBusinesses = [];
    
    // Process restaurants
    restaurantsSnapshot.forEach(doc => {
      const data = doc.data();
      allBusinesses.push({
        id: doc.id,
        name: data.name || 'Unknown',
        type: 'restaurant',
        address: data.address || 'No address',
        phone: data.phone || 'No phone',
        website: data.website || 'No website',
        ownerId: data.ownerId || 'No owner',
        isActive: data.isActive !== false,
        verificationStatus: data.verificationStatus || 'pending',
        placeId: data.placeId || 'No Google Place ID',
        latitude: data.latitude || 'No coordinates',
        longitude: data.longitude || 'No coordinates',
        createdAt: data.createdAt ? data.createdAt.toDate() : new Date(),
        collection: 'restaurants'
      });
    });
    
    // Process businesses
    businessesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      allBusinesses.push({
        id: doc.id,
        name: data.name || 'Unknown',
        type: data.businessType || 'other',
        address: data.address || 'No address',
        phone: data.phone || 'No phone',
        website: data.website || 'No website',
        ownerId: data.ownerId || 'No owner',
        isActive: data.isActive !== false,
        verificationStatus: data.verificationStatus || 'pending',
        placeId: data.placeId || 'No Google Place ID',
        latitude: data.latitude || 'No coordinates',
        longitude: data.longitude || 'No coordinates',
        createdAt: data.createdAt ? data.createdAt.toDate() : new Date(),
        collection: 'businesses'
      });
    });
    
    // Sort by name
    allBusinesses.sort((a, b) => a.name.localeCompare(b.name));
    
    console.log('=' .repeat(80));
    console.log('📋 ALL BUSINESSES IN FIREBASE DATABASE');
    console.log('=' .repeat(80));
    console.log(`Total: ${allBusinesses.length} businesses\n`);
    
    allBusinesses.forEach((business, index) => {
      console.log(`[${index + 1}] ${business.name}`);
      console.log(`    Type: ${business.type.charAt(0).toUpperCase() + business.type.slice(1)}`);
      console.log(`    Collection: ${business.collection}`);
      console.log(`    ID: ${business.id}`);
      console.log(`    Address: ${business.address}`);
      console.log(`    Phone: ${business.phone}`);
      console.log(`    Website: ${business.website}`);
      console.log(`    Owner ID: ${business.ownerId}`);
      console.log(`    Status: ${business.isActive ? 'Active' : 'Inactive'}`);
      console.log(`    Verification: ${business.verificationStatus.charAt(0).toUpperCase() + business.verificationStatus.slice(1)}`);
      console.log(`    Google Place ID: ${business.placeId}`);
      console.log(`    Coordinates: ${business.latitude}, ${business.longitude}`);
      console.log(`    Created: ${business.createdAt.toLocaleDateString()} ${business.createdAt.toLocaleTimeString()}`);
      console.log('');
    });
    
    console.log('=' .repeat(80));
    console.log('📊 SUMMARY BY TYPE:');
    const typeGroups = allBusinesses.reduce((acc, business) => {
      acc[business.type] = (acc[business.type] || 0) + 1;
      return acc;
    }, {});
    
    Object.entries(typeGroups)
      .sort(([a], [b]) => a.localeCompare(b))
      .forEach(([type, count]) => {
        console.log(`  ${type.charAt(0).toUpperCase() + type.slice(1)}: ${count}`);
      });
    
    console.log('\n📊 SUMMARY BY STATUS:');
    const activeCount = allBusinesses.filter(b => b.isActive).length;
    const inactiveCount = allBusinesses.length - activeCount;
    console.log(`  Active: ${activeCount}`);
    console.log(`  Inactive: ${inactiveCount}`);
    
    console.log('\n📊 SUMMARY BY VERIFICATION:');
    const verificationGroups = allBusinesses.reduce((acc, business) => {
      acc[business.verificationStatus] = (acc[business.verificationStatus] || 0) + 1;
      return acc;
    }, {});
    
    Object.entries(verificationGroups)
      .sort(([a], [b]) => a.localeCompare(b))
      .forEach(([status, count]) => {
        console.log(`  ${status.charAt(0).toUpperCase() + status.slice(1)}: ${count}`);
      });
    
    console.log('\n📊 SUMMARY BY COLLECTION:');
    const collectionGroups = allBusinesses.reduce((acc, business) => {
      acc[business.collection] = (acc[business.collection] || 0) + 1;
      return acc;
    }, {});
    
    Object.entries(collectionGroups).forEach(([collection, count]) => {
      console.log(`  ${collection}: ${count}`);
    });
    
    console.log('=' .repeat(80));
    
  } catch (error) {
    console.error('❌ Error listing businesses:', error);
    console.error('Error details:', error.message);
  }
}

// Run the query
listAllBusinesses().then(() => {
  console.log('✅ Query completed');
  process.exit(0);
}).catch(error => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});
