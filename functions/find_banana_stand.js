const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'kevin-ios-app',
});

const db = admin.firestore();

async function findBananaStand() {
  try {
    console.log('🔍 Specifically searching for The Banana Stand...\n');

    // Search restaurants collection
    const restaurantsSnapshot = await db.collection('restaurants').get();
    console.log(`Checking ${restaurantsSnapshot.size} restaurants...`);

    restaurantsSnapshot.forEach((doc) => {
      const data = doc.data();
      const name = data.name || '';
      console.log(`Restaurant: "${name}" (ID: ${doc.id})`);

      if (name.toLowerCase().includes('banana')) {
        console.log('🍌 FOUND BANANA MATCH!');
        console.log('Full data:', JSON.stringify(data, null, 2));
      }
    });

    // Search businesses collection
    let businessesSnapshot;
    try {
      businessesSnapshot = await db.collection('businesses').get();
      console.log(`\nChecking ${businessesSnapshot.size} businesses...`);

      businessesSnapshot.forEach((doc) => {
        const data = doc.data();
        const name = data.name || '';
        console.log(`Business: "${name}" (ID: ${doc.id})`);

        if (name.toLowerCase().includes('banana')) {
          console.log('🍌 FOUND BANANA MATCH!');
          console.log('Full data:', JSON.stringify(data, null, 2));
        }
      });
    } catch (error) {
      console.log('No businesses collection or error:', error.message);
    }

    // Also check if it might be in locationId field of issues
    console.log('\n🔍 Checking issues for location references...');
    const issuesSnapshot = await db.collection('issues').get();
    console.log(`Checking ${issuesSnapshot.size} issues...`);

    issuesSnapshot.forEach((doc) => {
      const data = doc.data();
      const locationId = data.locationId || '';

      if (locationId.toLowerCase().includes('banana')) {
        console.log('🍌 FOUND BANANA IN ISSUE LOCATION!');
        console.log('Issue data:', JSON.stringify(data, null, 2));
      }
    });
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

findBananaStand();
