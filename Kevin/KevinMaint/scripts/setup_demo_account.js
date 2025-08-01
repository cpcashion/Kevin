/**
 * Complete Demo Account Setup Script
 * Creates Firebase Auth user AND populates demo data
 * 
 * Usage:
 * 1. Make sure you have a service account key file
 * 2. Run: node setup_demo_account.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
// You'll need to download your service account key from Firebase Console
// Firebase Console → Project Settings → Service Accounts → Generate New Private Key
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

// Demo data constants
const DEMO_EMAIL = 'demo@kevinmaint.app';
const DEMO_PASSWORD = 'DemoKevin2025!';
let DEMO_USER_ID = 'demo-user-id'; // Use let so we can update it if user already exists
const DEMO_RESTAURANT_ID = 'demo-restaurant-id';
const DEMO_LOCATION_ID = 'demo-location-1';

async function setupDemoAccount() {
  console.log('🎭 Starting complete demo account setup...\n');

  try {
    // Step 1: Create or Update Firebase Auth User
    console.log('👤 Setting up Firebase Auth user...');
    try {
      // Try to get the existing user by email
      const existingUser = await auth.getUserByEmail(DEMO_EMAIL);
      console.log(`⚠️  User already exists with UID: ${existingUser.uid}`);
      
      // Update the existing user
      await auth.updateUser(existingUser.uid, {
        password: DEMO_PASSWORD,
        displayName: 'Demo Restaurant Owner'
      });
      console.log('✅ Updated existing user password');
      
      // Use the existing UID instead of our custom one
      const actualUserId = existingUser.uid;
      console.log(`ℹ️  Using existing UID: ${actualUserId}`);
      
      // Update all references to use the actual UID
      DEMO_USER_ID = actualUserId;
      
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        // User doesn't exist, create new one
        await auth.createUser({
          uid: DEMO_USER_ID,
          email: DEMO_EMAIL,
          password: DEMO_PASSWORD,
          displayName: 'Demo Restaurant Owner'
        });
        console.log('✅ Firebase Auth user created successfully');
      } else {
        throw error;
      }
    }

    // Step 2: Create Firestore User Document
    console.log('\n📝 Creating Firestore user document...');
    await db.collection('users').doc(DEMO_USER_ID).set({
      id: DEMO_USER_ID,
      role: 'owner',
      name: 'Demo Restaurant Owner',
      phone: '+1 (555) 123-4567',
      email: DEMO_EMAIL,
      restaurantId: DEMO_RESTAURANT_ID,  // Link user to demo restaurant
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ User document created with restaurantId: ' + DEMO_RESTAURANT_ID);

    // Step 3: Create Demo Restaurant
    console.log('\n🏪 Creating demo restaurant...');
    await db.collection('restaurants').doc(DEMO_RESTAURANT_ID).set({
      id: DEMO_RESTAURANT_ID,
      name: 'The Demo Bistro',
      address: '123 Main Street, San Francisco, CA 94102',
      phone: '+1 (555) 987-6543',
      email: 'contact@demobistro.com',
      website: 'https://demobistro.com',
      businessType: 'restaurant',
      cuisineType: 'American',
      operatingHours: 'Mon-Sun: 11:00 AM - 10:00 PM',
      ownerId: DEMO_USER_ID,
      latitude: 37.7749,
      longitude: -122.4194,
      placeId: 'demo-place-id',
      rating: 4.5,
      totalReviews: 234,
      verificationStatus: 'verified',
      verificationMethod: 'phone',
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Restaurant created');

    // Step 4: Create Demo Location
    console.log('\n📍 Creating demo location...');
    await db.collection('locations').doc(DEMO_LOCATION_ID).set({
      id: DEMO_LOCATION_ID,
      name: 'The Demo Bistro - Main Location',
      address: '123 Main Street, San Francisco, CA 94102',
      restaurantId: DEMO_RESTAURANT_ID,
      latitude: 37.7749,
      longitude: -122.4194,
      phone: '+1 (555) 987-6543',
      email: 'contact@demobistro.com',
      managerName: 'Demo Manager',
      operatingHours: 'Mon-Sun: 11:00 AM - 10:00 PM',
      timezone: 'America/Los_Angeles',
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Location created');

    // Step 5: Create Demo Issues
    console.log('\n🔧 Creating demo issues...');
    
    const issues = [
      {
        id: 'demo-issue-1',
        title: 'Walk-in Freezer Temperature Rising',
        description: 'The walk-in freezer temperature has been gradually rising over the past few hours. Currently reading 38°F instead of the normal 0°F. Food safety concern.',
        status: 'reported',
        priority: 'high',
        type: 'HVAC',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        businessId: DEMO_RESTAURANT_ID,  // Changed from restaurantId to businessId
        locationId: DEMO_LOCATION_ID,
        photoUrls: [],
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000)),
        updatedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000))
      },
      {
        id: 'demo-issue-2',
        title: 'Leaking Faucet in Kitchen Prep Area',
        description: 'Main prep sink faucet has a steady drip. Wasting water and creating puddles on the floor. Needs immediate attention.',
        status: 'in_progress',
        priority: 'medium',
        type: 'Plumbing',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        businessId: DEMO_RESTAURANT_ID,  // Changed from restaurantId to businessId
        locationId: DEMO_LOCATION_ID,
        photoUrls: [],
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000)),
        updatedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 6 * 60 * 60 * 1000))
      },
      {
        id: 'demo-issue-3',
        title: 'Broken Door Handle on Main Entrance',
        description: 'The main entrance door handle came loose and is difficult to open. Customers are having trouble entering the restaurant.',
        status: 'completed',
        priority: 'high',
        type: 'Door/Window',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        businessId: DEMO_RESTAURANT_ID,  // Changed from restaurantId to businessId
        locationId: DEMO_LOCATION_ID,
        photoUrls: [],
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)),
        updatedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 24 * 60 * 60 * 1000))
      },
      {
        id: 'demo-issue-4',
        title: 'Flickering Lights in Dining Area',
        description: 'Several LED lights in the main dining area are flickering intermittently. Creating an unpleasant dining experience.',
        status: 'reported',
        priority: 'low',
        type: 'Electrical',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        businessId: DEMO_RESTAURANT_ID,  // Changed from restaurantId to businessId
        locationId: DEMO_LOCATION_ID,
        photoUrls: [],
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 4 * 60 * 60 * 1000)),
        updatedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 4 * 60 * 60 * 1000))
      },
      {
        id: 'demo-issue-5',
        title: 'Grease Trap Needs Cleaning',
        description: 'Kitchen grease trap is overdue for cleaning. Starting to smell and could cause drainage issues if not addressed soon.',
        status: 'in_progress',
        priority: 'medium',
        type: 'Kitchen Equipment',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        businessId: DEMO_RESTAURANT_ID,  // Changed from restaurantId to businessId
        locationId: DEMO_LOCATION_ID,
        photoUrls: [],
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)),
        updatedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000))
      }
    ];

    for (const issue of issues) {
      await db.collection('maintenance_requests').doc(issue.id).set(issue);
      console.log(`  ✅ Created: ${issue.title}`);
      console.log(`     - ID: ${issue.id}`);
      console.log(`     - businessId: ${issue.businessId}`);
      console.log(`     - reporterId: ${issue.reporterId}`);
    }

    console.log('\n🎉 Demo account setup complete!\n');
    console.log('📧 Demo Credentials:');
    console.log(`   Email: ${DEMO_EMAIL}`);
    console.log(`   Password: ${DEMO_PASSWORD}`);
    console.log(`\n📊 Summary:`);
    console.log(`   User ID: ${DEMO_USER_ID}`);
    console.log(`   Restaurant ID: ${DEMO_RESTAURANT_ID}`);
    console.log(`   Location ID: ${DEMO_LOCATION_ID}`);
    console.log(`   Issues created: ${issues.length}`);
    console.log('\n✅ You can now tap "Try Demo Mode" in the app!\n');

  } catch (error) {
    console.error('❌ Error setting up demo account:', error);
  } finally {
    process.exit();
  }
}

// Run the script
setupDemoAccount();
