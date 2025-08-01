const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'kevin-ios-app',
});

const db = admin.firestore();

async function getBusinessesWithWorkOrders() {
  try {
    console.log('🔍 Finding businesses that have created work orders...\n');

    // Get all work orders
    const workOrdersSnapshot = await db.collection('workOrders').get();
    console.log(`Found ${workOrdersSnapshot.size} work orders`);

    // Get unique restaurant IDs from work orders
    const restaurantIds = new Set();
    workOrdersSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.restaurantId) {
        restaurantIds.add(data.restaurantId);
      }
    });

    console.log(`Found ${restaurantIds.size} unique restaurant IDs with work orders`);

    // Get restaurant details for each ID
    const businesses = [];
    for (const restaurantId of restaurantIds) {
      try {
        const restaurantDoc = await db.collection('restaurants').doc(restaurantId).get();
        if (restaurantDoc.exists) {
          const data = restaurantDoc.data();
          businesses.push({
            id: restaurantId,
            name: data.name || 'Unknown',
            address: data.address || 'No address',
            phone: data.phone || 'No phone',
            ownerId: data.ownerId || 'No owner',
            createdAt: data.createdAt ? data.createdAt.toDate() : new Date(),
          });
        } else {
          console.log(`⚠️  Restaurant ${restaurantId} not found in restaurants collection`);
        }
      } catch (error) {
        console.log(`❌ Error fetching restaurant ${restaurantId}:`, error.message);
      }
    }

    // Sort by name
    businesses.sort((a, b) => a.name.localeCompare(b.name));

    console.log('\n' + '=' .repeat(60));
    console.log('📋 BUSINESSES WITH WORK ORDERS');
    console.log('=' .repeat(60));
    console.log(`Total: ${businesses.length} businesses\n`);

    businesses.forEach((business, index) => {
      console.log(`[${index + 1}] ${business.name}`);
      console.log(`    ID: ${business.id}`);
      console.log(`    Address: ${business.address}`);
      if (business.phone !== 'No phone') console.log(`    Phone: ${business.phone}`);
      console.log(`    Owner ID: ${business.ownerId}`);
      console.log(`    Created: ${business.createdAt.toLocaleDateString()}`);
      console.log('');
    });

    console.log('=' .repeat(60));

    return businesses;
  } catch (error) {
    console.error('❌ Error:', error);
    throw error;
  }
}

// Run the query
getBusinessesWithWorkOrders().then((businesses) => {
  console.log(`✅ Found ${businesses.length} businesses with work orders`);
  process.exit(0);
}).catch((error) => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});
