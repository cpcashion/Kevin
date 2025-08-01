# App Store Screenshot Checklist for Kevin Maint

## 📱 Required Screenshot Sizes

### iPhone
- **6.9" Display (iPhone 16 Pro Max)**: 1320 x 2868 pixels
- **6.7" Display (iPhone 15 Plus)**: 1290 x 2796 pixels
- **6.5" Display (iPhone 11 Pro Max)**: 1242 x 2688 pixels
- **5.5" Display (iPhone 8 Plus)**: 1242 x 2208 pixels

### iPad
- **13" Display (iPad Pro 6th gen)**: 2048 x 2732 pixels
- **12.9" Display (iPad Pro 5th gen)**: 2048 x 2732 pixels

---

## 🎯 Screenshot Requirements (Per Apple Guidelines)

### ✅ DO:
- Show the app **in use** with real features and functionality
- Display core features: issue reporting, AI analysis, location tracking, messaging
- Use demo account data to show populated screens
- Show both Sign in with Apple AND Google Sign-In on auth screen
- Ensure screenshots are identical across all languages
- Show actual UI controls, menus, and interfaces
- Demonstrate the app's main value proposition

### ❌ DON'T:
- Show only login/splash screens
- Use marketing materials that don't reflect actual UI
- Show empty states or "No data" screens
- Include placeholder or lorem ipsum text
- Show different content for different device sizes

---

## 📸 Recommended Screenshot Sequence

### Screenshot 1: Authentication Screen ⭐ CRITICAL
**Purpose**: Show compliance with Sign in with Apple requirement
**Content**:
- ✅ Sign in with Apple button (PRIMARY - shown first)
- ✅ Sign in with Google button (ALTERNATIVE - shown second)
- ✅ "Try Demo Mode" button
- App logo and tagline: "Restaurant Maintenance Tracker"

**How to Capture**:
1. Launch app in simulator
2. Navigate to AuthView
3. Ensure both sign-in buttons are visible
4. Take screenshot

---

### Screenshot 2: Issues Dashboard
**Purpose**: Show main feature - issue tracking with AI
**Content**:
- List of maintenance issues with different statuses
- Status indicators (Reported, In Progress, Completed)
- Issue cards showing titles, categories, priorities
- Quick stats at top (3 Reported, 2 In Progress, 1 Completed)
- Tab bar at bottom

**How to Capture**:
1. Sign in with demo account
2. Navigate to Issues tab
3. Ensure demo data is loaded
4. Take screenshot

---

### Screenshot 3: AI-Powered Issue Reporting
**Purpose**: Highlight AI analysis feature
**Content**:
- Photo of maintenance issue
- AI analysis results showing:
  - Damage assessment
  - Repair recommendations
  - Estimated cost and time
  - Category classification
- "Report Issue" interface

**How to Capture**:
1. Navigate to Report Issue tab
2. Take/select a photo
3. Wait for AI analysis to complete
4. Show analysis results screen
5. Take screenshot

---

### Screenshot 4: Issue Detail with Timeline
**Purpose**: Show work order tracking and communication
**Content**:
- Issue details with status
- Progress timeline showing:
  - Issue reported
  - Work updates
  - Status changes
- Photos section
- Action buttons (Update Status, Add Work Log, Send Message)

**How to Capture**:
1. Tap on any issue from Issues list
2. Scroll to show timeline
3. Ensure work logs are visible
4. Take screenshot

---

### Screenshot 5: Location Management
**Purpose**: Show location tracking and business management
**Content**:
- List of restaurant locations
- Location cards showing:
  - Business name and address
  - Issue counts
  - Health scores
- Map button in toolbar

**How to Capture**:
1. Navigate to Locations tab
2. Ensure demo location is visible
3. Take screenshot

---

### Screenshot 6: Messaging/Communication
**Purpose**: Show real-time communication feature
**Content**:
- Conversation list or active chat
- Messages between restaurant owner and Kevin
- Issue-specific conversations
- Message input field

**How to Capture**:
1. Navigate to Messages tab
2. Show conversation list or open a conversation
3. Take screenshot

---

### Screenshot 7: Location Map View (Optional)
**Purpose**: Show geographic visualization
**Content**:
- Map with location pins
- Location details overlay
- Health status indicators

**How to Capture**:
1. From Locations tab, tap Map button
2. Ensure demo location pin is visible
3. Take screenshot

---

## 🎨 Screenshot Best Practices

### Visual Quality
- Use highest resolution device simulators
- Ensure dark theme is consistent
- Check for proper text contrast
- Verify all icons and images load correctly

### Content Quality
- Use realistic demo data (no "Test 123" or placeholder text)
- Show meaningful issue descriptions
- Display proper timestamps and dates
- Include realistic names and locations

### Device Coverage
- Prioritize iPhone 6.9" and iPad 13" (required)
- Include at least one smaller iPhone size for compatibility
- Ensure UI scales properly on all sizes

---

## 🚀 Screenshot Capture Workflow

### 1. Prepare Demo Environment
```bash
# Run demo data population script
cd Kevin/KevinMaint/scripts
npm install firebase-admin
node populate_demo_data.js
```

### 2. Configure Simulator
- Open Xcode
- Select target device (e.g., iPhone 16 Pro Max)
- Build and run app
- Sign in with demo account OR use Demo Mode

### 3. Capture Screenshots
- Use Xcode: Debug → View Debugging → Capture View Hierarchy
- OR use Simulator: File → New Screen Shot (⌘S)
- Save to organized folder structure

### 4. Organize Files
```
Screenshots/
├── iPhone-6.9/
│   ├── 1-auth.png
│   ├── 2-issues-dashboard.png
│   ├── 3-ai-analysis.png
│   ├── 4-issue-detail.png
│   ├── 5-locations.png
│   └── 6-messaging.png
├── iPhone-6.7/
│   └── [same structure]
└── iPad-13/
    └── [same structure]
```

### 5. Upload to App Store Connect
1. Go to App Store Connect → My Apps → Kevin Maint
2. Select version → App Store tab
3. Scroll to "Previews and Screenshots"
4. Click "View All Sizes in Media Manager"
5. Upload screenshots for each device size
6. Arrange in proper order (Auth first, then features)

---

## ✅ Pre-Submission Checklist

Before uploading screenshots:
- [ ] All screenshots show Sign in with Apple button
- [ ] No screenshots are just login/splash screens
- [ ] Demo data is realistic and professional
- [ ] All device sizes covered (iPhone 6.9", iPad 13" minimum)
- [ ] Screenshots demonstrate core features
- [ ] UI is consistent across all screenshots
- [ ] No placeholder text or empty states
- [ ] Dark theme is properly applied
- [ ] Text is readable and properly contrasted
- [ ] All images and icons load correctly

---

## 📧 Demo Account Information

**For App Store Review Information Section:**

```
Demo Account Credentials:
Email: demo@kevinmaint.app
Password: DemoKevin2025!

Demo Account Details:
- Role: Restaurant Owner
- Restaurant: The Demo Bistro
- Location: San Francisco, CA
- Pre-populated with 5 sample issues (various statuses)
- Includes AI analysis, work logs, and location data

Features Accessible:
✅ Issue reporting with AI analysis
✅ Location management and mapping
✅ Real-time messaging
✅ Work order tracking
✅ Status updates and timeline
✅ Photo upload and management

Alternative Access:
Users can also tap "Try Demo Mode" button on login screen
to explore the app without signing in.
```

---

## 🎯 Key Messages for Each Screenshot

### Screenshot 1 (Auth)
**Message**: "Sign in securely with Apple or Google"
**Highlights**: Privacy-focused authentication options

### Screenshot 2 (Issues Dashboard)
**Message**: "Track all maintenance issues in one place"
**Highlights**: Status tracking, priority management

### Screenshot 3 (AI Analysis)
**Message**: "AI-powered instant maintenance analysis"
**Highlights**: GPT-4 Vision analysis, cost estimates

### Screenshot 4 (Issue Detail)
**Message**: "Complete work order management"
**Highlights**: Timeline, updates, communication

### Screenshot 5 (Locations)
**Message**: "Manage multiple restaurant locations"
**Highlights**: Location tracking, health scores

### Screenshot 6 (Messaging)
**Message**: "Real-time communication with maintenance team"
**Highlights**: Issue-specific conversations, notifications

---

## 📝 Notes for App Review Team

Include this in App Review Information section:

```
App Review Notes:

This app provides AI-powered maintenance management for restaurants.
Key features demonstrated in screenshots:

1. Sign in with Apple (primary) and Google Sign-In (alternative)
2. AI-powered maintenance issue analysis using GPT-4 Vision
3. Real-time issue tracking and work order management
4. Location-based restaurant management
5. In-app messaging and notifications

Demo Mode:
- Tap "Try Demo Mode" on login screen for instant access
- OR use demo credentials: demo@kevinmaint.app / DemoKevin2025!

All features are fully functional in demo mode with realistic sample data.

The app uses standard iOS encryption and Firebase backend.
No custom encryption algorithms are implemented.
```

---

## 🔄 After Approval

Once approved, consider:
- Updating screenshots with real customer testimonials
- Adding video preview showing AI analysis in action
- Localizing screenshots for international markets
- A/B testing different screenshot orders for conversion

---

**Last Updated**: January 2025
**App Version**: 1.0
**Prepared for**: App Store Submission
