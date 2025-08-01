const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'kevin-ios-app',
});

const db = admin.firestore();

async function searchSpecificBusinesses() {
  try {
    console.log('🔍 Searching for Banana Stand, 7-Eleven, and Summit Coffee...\n');

    const searchTerms = ['banana stand', '7-eleven', '7 eleven', 'summit coffee'];

    // Search in restaurants collection
    console.log('📊 Searching restaurants collection...');
    const restaurantsSnapshot = await db.collection('restaurants').get();

    // Search in businesses collection
    console.log('📊 Searching businesses collection...');
    let businessesSnapshot;
    try {
      businessesSnapshot = await db.collection('businesses').get();
    } catch (error) {
      businessesSnapshot = {docs: []};
    }

    const foundBusinesses = [];

    // Search restaurants
    restaurantsSnapshot.forEach((doc) => {
      const data = doc.data();
      const name = (data.name || '').toLowerCase();

      for (const term of searchTerms) {
        if (name.includes(term)) {
          foundBusinesses.push({
            id: doc.id,
            name: data.name || 'Unknown',
            address: data.address || 'No address',
            phone: data.phone || 'No phone',
            ownerId: data.ownerId || 'No owner',
            collection: 'restaurants',
            createdAt: data.createdAt ? data.createdAt.toDate() : new Date(),
          });
          break;
        }
      }
    });

    // Search businesses
    if (businessesSnapshot.docs) {
      businessesSnapshot.docs.forEach((doc) => {
        const data = doc.data();
        const name = (data.name || '').toLowerCase();

        for (const term of searchTerms) {
          if (name.includes(term)) {
            foundBusinesses.push({
              id: doc.id,
              name: data.name || 'Unknown',
              address: data.address || 'No address',
              phone: data.phone || 'No phone',
              ownerId: data.ownerId || 'No owner',
              collection: 'businesses',
              createdAt: data.createdAt ? data.createdAt.toDate() : new Date(),
            });
            break;
          }
        }
      });
    }

    // Also search all business names for partial matches
    console.log('📊 Searching all business names for partial matches...');
    const allBusinesses = [];

    restaurantsSnapshot.forEach((doc) => {
      const data = doc.data();
      allBusinesses.push({
        id: doc.id,
        name: data.name || 'Unknown',
        address: data.address || 'No address',
        collection: 'restaurants',
      });
    });

    if (businessesSnapshot.docs) {
      businessesSnapshot.docs.forEach((doc) => {
        const data = doc.data();
        allBusinesses.push({
          id: doc.id,
          name: data.name || 'Unknown',
          address: data.address || 'No address',
          collection: 'businesses',
        });
      });
    }

    console.log('\n' + '=' .repeat(60));
    console.log('🔍 SEARCH RESULTS');
    console.log('=' .repeat(60));

    if (foundBusinesses.length > 0) {
      console.log(`Found ${foundBusinesses.length} matching businesses:\n`);

      foundBusinesses.forEach((business, index) => {
        console.log(`[${index + 1}] ${business.name}`);
        console.log(`    Collection: ${business.collection}`);
        console.log(`    ID: ${business.id}`);
        console.log(`    Address: ${business.address}`);
        console.log(`    Owner ID: ${business.ownerId}`);
        console.log('');
      });
    } else {
      console.log('❌ No exact matches found for Banana Stand, 7-Eleven, or Summit Coffee');
      console.log('\n📋 Here are all businesses in the database for reference:');
      console.log('=' .repeat(60));

      allBusinesses.sort((a, b) => a.name.localeCompare(b.name));
      allBusinesses.forEach((business, index) => {
        console.log(`[${index + 1}] ${business.name} (${business.collection})`);
        console.log(`    Address: ${business.address}`);
        console.log('');
      });
    }

    console.log('=' .repeat(60));

    return foundBusinesses;
  } catch (error) {
    console.error('❌ Error:', error);
    throw error;
  }
}

// Run the search
searchSpecificBusinesses().then((businesses) => {
  console.log('✅ Search completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});
