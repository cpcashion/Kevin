# Kevin Maint - Quick Submission Checklist

## ⚡ 30-Minute Action Plan

### Step 1: Create Demo Account in Firebase (5 min) ⭐ CRITICAL
```
1. Go to Firebase Console → Authentication → Users
2. Click "Add User"
3. Email: demo@kevinmaint.app
4. Password: DemoKevin2025!
5. Click "Add User"

⚠️ IMPORTANT: After creating, click on the user and set:
   User UID: demo-user-id
   (This must match the demo data)
```

### Step 2: Populate Demo Data (5 min)
```bash
cd Kevin/KevinMaint/scripts
npm install firebase-admin
node populate_demo_data.js
```

**What this creates:**
- Demo restaurant: "The Demo Bistro"
- 5 maintenance issues (various statuses)
- Work logs and AI analyses
- Location data

### Step 3: Take Screenshots (15 min)
```
1. Build app in Xcode
2. Run iPhone 16 Pro Max simulator
3. Capture 6 screenshots:
   ✅ Auth (with Apple + Google)
   ✅ Issues dashboard
   ✅ AI analysis
   ✅ Issue detail
   ✅ Locations
   ✅ Messaging
4. Repeat for iPad Pro 13"
```

### Step 4: Update App Store Connect (5 min)
```
1. Upload new screenshots
2. Add demo credentials to App Review Info:
   Email: demo@kevinmaint.app
   Password: DemoKevin2025!
3. Reply to rejection explaining fixes
4. Submit for review
```

---

## ✅ Pre-Submit Verification

Quick test before submitting:
- [ ] Login with demo@kevinmaint.app works
- [ ] "Try Demo Mode" button visible
- [ ] 5 demo issues appear in Issues tab
- [ ] Screenshots show BOTH sign-in options
- [ ] iPad screenshots show app features (not just login)

---

## 📧 Demo Credentials (Copy/Paste Ready)

**For App Store Connect → App Review Information:**

```
EASIEST METHOD - Just tap "Try Demo Mode" button:
The app has a "Try Demo Mode" button on the sign-in screen that 
automatically signs in with demo credentials and loads demo data.

ALTERNATIVE - Manual sign-in:
Email: demo@kevinmaint.app
Password: DemoKevin2025!
Use either Google Sign-In or Apple Sign-In with these credentials.

The demo account includes:
- 5 sample maintenance issues (various statuses)
- AI analysis results  
- Location data (The Demo Bistro, San Francisco)
- Work logs and timeline
- All features fully functional

HOW IT WORKS:
The "Try Demo Mode" button automatically signs into Firebase with
the demo account, so all data is real and persisted in the database.
No mock data - everything works exactly like production.
```

---

## 🎯 What Changed Since Last Rejection

**Guideline 4.8 - Sign in with Apple**
✅ Already implemented (just needed better screenshots)

**Guideline 2.1 - Demo Account**
✅ Created demo@kevinmaint.app + demo mode

**Guideline 2.3.3 - Screenshots**
✅ New screenshots showing app features (not just login)

---

## 🚨 Common Mistakes to Avoid

❌ Forgetting to set UID to "demo-user-id" in Firebase Auth
❌ Not running demo data script before taking screenshots
❌ Taking iPad screenshots that only show login screen
❌ Uploading screenshots without Sign in with Apple visible
❌ Forgetting to add demo credentials to App Review Info

---

## 📱 Screenshot Order (CRITICAL)

1. **Auth Screen** - Shows Apple + Google sign-in ⭐
2. **Issues Dashboard** - Shows app in use
3. **AI Analysis** - Shows key feature
4. **Issue Detail** - Shows workflow
5. **Locations** - Shows management
6. **Messaging** - Shows communication

---

**Ready to submit?** Follow the 30-minute action plan above! 🚀
