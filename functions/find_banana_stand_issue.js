const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'kevin-ios-app',
});

const db = admin.firestore();

async function findBananaStandIssue() {
  try {
    console.log('🔍 Looking for issues with The Banana Stand Google Place ID...\n');

    const bananaStandPlaceId = 'ChIJW-CX62ETkFQRWANui6ltZno';

    // Search issues for this Google Place ID
    const issuesSnapshot = await db.collection('issues').get();
    console.log(`Checking ${issuesSnapshot.size} issues...`);

    const foundIssues = [];

    issuesSnapshot.forEach((doc) => {
      const data = doc.data();

      // Check restaurantId field
      if (data.restaurantId === bananaStandPlaceId) {
        console.log('🍌 FOUND BANANA STAND ISSUE BY RESTAURANT ID!');
        foundIssues.push({
          id: doc.id,
          data: data,
          matchField: 'restaurantId',
        });
      }

      // Check locationId field
      if (data.locationId === bananaStandPlaceId) {
        console.log('🍌 FOUND BANANA STAND ISSUE BY LOCATION ID!');
        foundIssues.push({
          id: doc.id,
          data: data,
          matchField: 'locationId',
        });
      }

      // Check if locationId contains "banana" (case insensitive)
      if (data.locationId && data.locationId.toLowerCase().includes('banana')) {
        console.log('🍌 FOUND BANANA STAND ISSUE BY LOCATION NAME!');
        foundIssues.push({
          id: doc.id,
          data: data,
          matchField: 'locationId (name match)',
        });
      }
    });

    console.log(`\nFound ${foundIssues.length} issues related to The Banana Stand:`);

    foundIssues.forEach((issue, index) => {
      console.log(`\n[${index + 1}] Issue ID: ${issue.id}`);
      console.log(`    Match Field: ${issue.matchField}`);
      console.log(`    Title: ${issue.data.title || 'No title'}`);
      console.log(`    Restaurant ID: ${issue.data.restaurantId || 'No restaurant ID'}`);
      console.log(`    Location ID: ${issue.data.locationId || 'No location ID'}`);
      console.log(`    Reporter ID: ${issue.data.reporterId || 'No reporter ID'}`);
      console.log(`    Status: ${issue.data.status || 'No status'}`);
      console.log(`    Created: ${issue.data.createdAt ? issue.data.createdAt.toDate() : 'No date'}`);
      console.log(`    Description: ${issue.data.description || 'No description'}`);
    });

    return foundIssues;
  } catch (error) {
    console.error('❌ Error:', error);
    throw error;
  }
}

findBananaStandIssue();
