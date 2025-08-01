const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'kevin-ios-app',
});

const db = admin.firestore();

async function checkBananaStandWorkOrders() {
  try {
    console.log('🔍 Checking if The Banana Stand has work orders...\n');

    const bananaStandPlaceId = 'ChIJW-CX62ETkFQRWANui6ltZno';

    // Check work orders for The Banana Stand
    const workOrdersSnapshot = await db.collection('workOrders').get();
    console.log(`Checking ${workOrdersSnapshot.size} work orders...`);

    const bananaStandWorkOrders = [];

    workOrdersSnapshot.forEach((doc) => {
      const data = doc.data();

      if (data.restaurantId === bananaStandPlaceId) {
        console.log('🍌 FOUND BANANA STAND WORK ORDER!');
        bananaStandWorkOrders.push({
          id: doc.id,
          data: data,
        });
      }
    });

    console.log(`\nFound ${bananaStandWorkOrders.length} work orders for The Banana Stand:`);

    bananaStandWorkOrders.forEach((workOrder, index) => {
      console.log(`\n[${index + 1}] Work Order ID: ${workOrder.id}`);
      console.log(`    Restaurant ID: ${workOrder.data.restaurantId}`);
      console.log(`    Issue ID: ${workOrder.data.issueId}`);
      console.log(`    Status: ${workOrder.data.status}`);
      console.log(`    Created: ${workOrder.data.createdAt ? workOrder.data.createdAt.toDate() : 'No date'}`);
      console.log(`    Assignee: ${workOrder.data.assigneeId || 'No assignee'}`);
    });

    // Now check what the Locations page is actually looking for
    console.log('\n🔍 Checking what locations the app would show...');

    // The app looks for businesses in restaurants collection with work orders
    const restaurantsSnapshot = await db.collection('restaurants').get();
    console.log(`\nChecking ${restaurantsSnapshot.size} restaurants in database...`);

    // Get unique restaurant IDs from work orders
    const workOrderRestaurantIds = new Set();
    workOrdersSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.restaurantId) {
        workOrderRestaurantIds.add(data.restaurantId);
      }
    });

    console.log(`\nUnique restaurant IDs with work orders: ${workOrderRestaurantIds.size}`);
    console.log('Restaurant IDs:', Array.from(workOrderRestaurantIds));

    // Check which ones exist in restaurants collection
    let foundInRestaurants = 0;
    const missingFromRestaurants = [];

    for (const restaurantId of workOrderRestaurantIds) {
      try {
        const restaurantDoc = await db.collection('restaurants').doc(restaurantId).get();
        if (restaurantDoc.exists) {
          foundInRestaurants++;
          const data = restaurantDoc.data();
          console.log(`✅ Found: ${data.name} (${restaurantId})`);
        } else {
          missingFromRestaurants.push(restaurantId);
          console.log(`❌ Missing: ${restaurantId}`);
        }
      } catch (error) {
        missingFromRestaurants.push(restaurantId);
        console.log(`❌ Error checking: ${restaurantId}`);
      }
    }

    console.log('\n📊 SUMMARY:');
    console.log(`- Total work order restaurant IDs: ${workOrderRestaurantIds.size}`);
    console.log(`- Found in restaurants collection: ${foundInRestaurants}`);
    console.log(`- Missing from restaurants collection: ${missingFromRestaurants.length}`);

    if (missingFromRestaurants.length > 0) {
      console.log('\n❌ MISSING RESTAURANTS:');
      missingFromRestaurants.forEach((id) => {
        console.log(`   ${id}`);
      });

      console.log('\n🔧 THE PROBLEM:');
      console.log('The Locations page only shows businesses that exist in the \'restaurants\' collection.');
      console.log('But some work orders reference Google Place IDs that don\'t have restaurant records.');
      console.log('This is why The Banana Stand (and others) don\'t appear in the Locations page.');
    }
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkBananaStandWorkOrders();
