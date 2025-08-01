# Demo Account Setup Instructions

## Quick Setup (5 minutes)

### Step 1: Download Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your Kevin Maint project
3. Click the **gear icon** → **Project settings**
4. Go to **Service accounts** tab
5. Click **"Generate new private key"**
6. Save the downloaded file as `serviceAccountKey.json` in this `scripts` folder

### Step 2: Run the Setup Script

```bash
cd "/Users/cash/Library/Mobile Documents/com~apple~CloudDocs/Kevin/Kevin/KevinMaint/scripts"
npm install
node setup_demo_account.js
```

This will:
- ✅ Create Firebase Auth user (`demo@kevinmaint.app`)
- ✅ Create user document in Firestore
- ✅ Create demo restaurant
- ✅ Create demo location
- ✅ Create 5 demo maintenance issues

### Step 3: Test It!

1. Build and run the app
2. Tap **"Try Demo Mode"** button
3. App loads with demo data! 🎉

---

## What Gets Created

**Firebase Auth User:**
- Email: `demo@kevinmaint.app`
- Password: `DemoKevin2025!`
- UID: `demo-user-id`

**Demo Data:**
- Restaurant: "The Demo Bistro" (San Francisco)
- 5 Issues: Various statuses (reported, in_progress, completed)
- Location data with coordinates
- Realistic timestamps

---

## Troubleshooting

**Error: "Cannot find module './serviceAccountKey.json'"**
- You need to download the service account key (see Step 1)

**Error: "Permission denied"**
- Make sure your service account has Admin privileges

**Error: "auth/uid-already-exists"**
- Script will automatically update the existing user

---

## Security Note

⚠️ **NEVER commit `serviceAccountKey.json` to git!**

It's already in `.gitignore` but double-check before committing.
