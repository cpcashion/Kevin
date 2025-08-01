/**
 * Firebase Script to Populate Demo Data for App Store Review
 * 
 * Usage:
 * 1. Install Firebase CLI: npm install -g firebase-tools
 * 2. Login: firebase login
 * 3. Run: node populate_demo_data.js
 * 
 * Demo Account Credentials:
 * Email: demo@kevinmaint.app
 * Password: DemoKevin2025!
 */

const admin = require('firebase-admin');
const serviceAccount = require('../GoogleService-Info.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Demo data constants
const DEMO_USER_ID = 'demo-user-id';
const DEMO_RESTAURANT_ID = 'demo-restaurant-id';
const DEMO_LOCATION_ID = 'demo-location-1';

async function populateDemoData() {
  console.log('🎭 Starting demo data population...\n');

  try {
    // 1. Create Demo User
    console.log('👤 Creating demo user...');
    await db.collection('users').doc(DEMO_USER_ID).set({
      id: DEMO_USER_ID,
      role: 'owner',
      name: 'Demo Restaurant Owner',
      phone: '+1 (555) 123-4567',
      email: 'demo@kevinmaint.app',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Demo user created\n');

    // 2. Create Demo Restaurant
    console.log('🏪 Creating demo restaurant...');
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
    console.log('✅ Demo restaurant created\n');

    // 3. Create Demo Location
    console.log('📍 Creating demo location...');
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
    console.log('✅ Demo location created\n');

    // 4. Create Demo Issues
    console.log('🔧 Creating demo issues...');
    
    const issues = [
      {
        id: 'demo-issue-1',
        title: 'Walk-in Freezer Temperature Rising',
        description: 'The walk-in freezer temperature has been gradually rising over the past few hours. Currently reading 38°F instead of the normal 0°F. Food safety concern.',
        status: 'reported',
        priority: 'high',
        category: 'HVAC',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        restaurantId: DEMO_RESTAURANT_ID,
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
        category: 'Plumbing',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        restaurantId: DEMO_RESTAURANT_ID,
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
        category: 'Door/Window',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        restaurantId: DEMO_RESTAURANT_ID,
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
        category: 'Electrical',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        restaurantId: DEMO_RESTAURANT_ID,
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
        category: 'Kitchen Equipment',
        reporterId: DEMO_USER_ID,
        reporterName: 'Demo Restaurant Owner',
        restaurantId: DEMO_RESTAURANT_ID,
        locationId: DEMO_LOCATION_ID,
        photoUrls: [],
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)),
        updatedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000))
      }
    ];

    for (const issue of issues) {
      await db.collection('issues').doc(issue.id).set(issue);
      console.log(`  ✅ Created: ${issue.title}`);
    }
    console.log('✅ All demo issues created\n');

    // 5. Create Demo Work Logs
    console.log('📝 Creating demo work logs...');
    
    const workLogs = [
      {
        id: 'demo-worklog-1',
        issueId: 'demo-issue-2',
        userId: DEMO_USER_ID,
        userName: 'Kevin (Maintenance)',
        message: 'Arrived on site. Inspecting the faucet and checking for loose connections.',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 6 * 60 * 60 * 1000))
      },
      {
        id: 'demo-worklog-2',
        issueId: 'demo-issue-2',
        userId: DEMO_USER_ID,
        userName: 'Kevin (Maintenance)',
        message: 'Replaced worn O-ring and tightened valve seat. Testing for leaks.',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 60 * 60 * 1000))
      },
      {
        id: 'demo-worklog-3',
        issueId: 'demo-issue-3',
        userId: DEMO_USER_ID,
        userName: 'Kevin (Maintenance)',
        message: 'Replaced door handle assembly. Tested multiple times - working perfectly now.',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 24 * 60 * 60 * 1000))
      }
    ];

    for (const log of workLogs) {
      await db.collection('workLogs').doc(log.id).set(log);
      console.log(`  ✅ Created work log for: ${log.issueId}`);
    }
    console.log('✅ All demo work logs created\n');

    // 6. Create Demo AI Analysis
    console.log('🤖 Creating demo AI analysis...');
    
    const aiAnalyses = [
      {
        id: 'demo-ai-1',
        issueId: 'demo-issue-1',
        summary: 'Critical HVAC issue requiring immediate attention. Temperature rise in walk-in freezer indicates potential compressor failure or refrigerant leak.',
        damageAssessment: 'High priority - food safety risk. Current temperature of 38°F is above safe storage threshold.',
        repairRecommendations: [
          'Check compressor operation and refrigerant levels',
          'Inspect door seals for air leaks',
          'Verify thermostat calibration',
          'Consider temporary food storage relocation'
        ],
        estimatedCost: '$500-$2000',
        estimatedTime: '2-4 hours',
        urgency: 'high',
        category: 'HVAC',
        confidence: 0.92,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000))
      },
      {
        id: 'demo-ai-2',
        issueId: 'demo-issue-2',
        summary: 'Standard plumbing repair. Faucet leak likely caused by worn washers or O-rings.',
        damageAssessment: 'Medium priority - water waste and slip hazard. No structural damage detected.',
        repairRecommendations: [
          'Replace faucet washers and O-rings',
          'Check valve seat for corrosion',
          'Tighten mounting nuts if loose',
          'Consider faucet replacement if parts unavailable'
        ],
        estimatedCost: '$75-$200',
        estimatedTime: '30-60 minutes',
        urgency: 'medium',
        category: 'Plumbing',
        confidence: 0.88,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000))
      }
    ];

    for (const analysis of aiAnalyses) {
      await db.collection('issues').doc(analysis.issueId).collection('aiAnalysis').doc(analysis.id).set(analysis);
      console.log(`  ✅ Created AI analysis for: ${analysis.issueId}`);
    }
    console.log('✅ All demo AI analyses created\n');

    console.log('🎉 Demo data population complete!\n');
    console.log('📧 Demo Account Credentials:');
    console.log('   Email: demo@kevinmaint.app');
    console.log('   Password: DemoKevin2025!\n');
    console.log('⚠️  Note: You still need to create the Firebase Auth user manually:');
    console.log('   1. Go to Firebase Console → Authentication');
    console.log('   2. Add user with email: demo@kevinmaint.app');
    console.log('   3. Set password: DemoKevin2025!');
    console.log('   4. Set UID to: demo-user-id\n');

  } catch (error) {
    console.error('❌ Error populating demo data:', error);
  } finally {
    process.exit();
  }
}

// Run the script
populateDemoData();
