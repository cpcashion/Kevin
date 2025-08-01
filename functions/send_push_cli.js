/*
Usage examples:

1) Send by email (looks up users/{uid}.fcmToken):
   node send_push_cli.js --email chris.cashion@gmail.com --badge 7 --title "CLI Test" --body "Badge 7 test" --project kevin-ios-app

2) Send by token directly:
   node send_push_cli.js --token <FCM_TOKEN> --badge 3 --title "CLI Test" --body "Badge 3 test" --project kevin-ios-app

Environment:
- Requires GOOGLE_APPLICATION_CREDENTIALS set to a service account JSON, OR application-default credentials configured via `gcloud auth application-default login`.
*/

const admin = require('firebase-admin');

// Simple argv parser
function parseArgv() {
  const out = {};
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg.startsWith('--')) {
      const key = arg.replace(/^--/, '');
      const next = args[i + 1];
      if (next && !next.startsWith('--')) {
        out[key] = next;
        i++;
      } else {
        out[key] = true;
      }
    }
  }
  return out;
}

(async () => {
  const argv = parseArgv();
  const projectId = argv.project || 'kevin-ios-app';
  const email = argv.email;
  const directToken = argv.token;
  const badge = Number.isFinite(parseInt(argv.badge, 10)) ? parseInt(argv.badge, 10) : 1;
  const title = argv.title || 'CLI Test Notification';
  const body = argv.body || 'Badge test from CLI';

  // Initialize Admin SDK with ADC
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId,
    });
  } catch (e) {
    console.error('❌ Failed to initialize Firebase Admin SDK.');
    console.error('   Ensure GOOGLE_APPLICATION_CREDENTIALS is set, or run: gcloud auth application-default login');
    console.error(e);
    process.exit(1);
  }

  const db = admin.firestore();

  let token = directToken;
  if (!token) {
    if (!email) {
      console.error('❌ Provide either --token <FCM_TOKEN> or --email <user email>');
      process.exit(1);
    }
    console.log(`🔍 Looking up user by email: ${email}`);
    const snap = await db.collection('users').where('email', '==', email).limit(1).get();
    if (snap.empty) {
      console.error(`❌ No user found with email: ${email}`);
      process.exit(1);
    }
    const doc = snap.docs[0];
    const data = doc.data() || {};
    token = data.fcmToken;
    if (!token) {
      console.error(`❌ User ${doc.id} has no fcmToken field`);
      console.error('   Document fields:', Object.keys(data));
      process.exit(1);
    }
    console.log(`✅ Found user ${doc.id}. Using fcmToken: ${token.substring(0, 24)}... (length ${token.length})`);
  }

  const message = {
    token,
    notification: {
      title,
      body,
    },
    data: {
      type: 'cli_test',
      timestamp: Date.now().toString(),
    },
    apns: {
      payload: {
        aps: {
          badge,
          sound: 'default',
        },
      },
    },
  };

  console.log('📤 Sending message:', JSON.stringify({title, body, badge}, null, 2));
  try {
    const res = await admin.messaging().send(message);
    console.log('✅ FCM send result:', res);
    console.log('👉 If no notification appeared: ensure the device has notifications enabled for the app, the token is current, and the app build uses the correct APNs environment matching Firebase Console credentials.');
  } catch (err) {
    console.error('❌ Error sending FCM message:', err.code, err.message);
    if (err.errorInfo) console.error('   errorInfo:', err.errorInfo);
    process.exit(1);
  }
})();
