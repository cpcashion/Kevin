# APNs Certificate Setup Guide for Kevin Maint

## Current Status ✅
- ✅ FCM code enabled in NotificationService.swift
- ✅ FirebaseMessaging dependency added to Xcode project
- ✅ Cloud Functions deployed and ready
- ✅ App initialization updated to setup notifications
- ⚠️ **MISSING: APNs certificates in Firebase Console**

## Step 1: Configure APNs in Firebase Console

### Go to Firebase Console
1. Open: https://console.firebase.google.com/project/kevin-ios-app/overview
2. Click the gear icon ⚙️ → "Project settings"
3. Click the "Cloud Messaging" tab
4. Scroll to "iOS app configuration"

### Option A: APNs Authentication Key (Recommended - Easier)

1. **Create APNs Key in Apple Developer Console:**
   - Go to: https://developer.apple.com/account/resources/authkeys/list
   - Click "+" to create a new key
   - Enter name: "Kevin Maint APNs Key"
   - Check "Apple Push Notifications service (APNs)"
   - Click "Continue" → "Register"
   - **Download the .p8 file immediately** (you can't download it again)
   - Note the Key ID (10-character string)

2. **Upload to Firebase:**
   - In Firebase Console → Cloud Messaging → iOS app configuration
   - Click "Upload" under "APNs authentication key"
   - Upload the .p8 file
   - Enter Key ID (from step 1)
   - Enter Team ID (find in Apple Developer Account → Membership)

### Option B: APNs Certificates (Alternative)

1. **Create Certificate Signing Request:**
   - Open Keychain Access on Mac
   - Keychain Access → Certificate Assistant → Request Certificate from CA
   - Enter your email, name, leave CA blank
   - Save to disk

2. **Create APNs Certificate:**
   - Go to: https://developer.apple.com/account/resources/certificates/list
   - Click "+" → "Apple Push Notification service SSL (Sandbox & Production)"
   - Select your Kevin Maint app ID
   - Upload the CSR file
   - Download the certificate

3. **Export and Upload:**
   - Double-click certificate to install in Keychain
   - Right-click → Export as .p12 file
   - Set a password
   - Upload .p12 to Firebase Console

## Step 2: Test Push Notifications

After configuring APNs certificates:

1. **Build and run the app on a physical device** (push notifications don't work in simulator)
2. **Grant notification permissions** when prompted
3. **Check console logs** for FCM token registration
4. **Test messaging feature** - send a message to trigger notifications

## Step 3: Verify Setup

Look for these console logs when app starts:
```
🔔 [NotificationService] Setting up notifications
🔔 [NotificationService] Permission granted: true
✅ [NotificationService] FCM token retrieved: [long token string]
✅ [NotificationService] FCM token registered for user: [user_id]
```

## Troubleshooting

### No FCM Token
- Ensure APNs certificates are uploaded to Firebase
- Check that app is running on physical device
- Verify notification permissions are granted

### Notifications Not Received
- Check Firebase Console → Cloud Messaging for any errors
- Verify Cloud Functions are deployed: `firebase deploy --only functions`
- Check Firestore rules allow notification triggers

### Build Errors
- Clean build folder: Product → Clean Build Folder
- Ensure FirebaseMessaging is properly linked in Xcode

## Next Steps After APNs Setup

1. Test end-to-end messaging with push notifications
2. Verify notifications work when app is backgrounded
3. Test notification tap handling (should open conversation)
4. Deploy to TestFlight for broader testing

---

**Important:** Push notifications only work on physical devices, not in the iOS Simulator. Make sure to test on a real iPhone/iPad.
