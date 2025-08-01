# App Store Rejection Fixes - Version 1.2.6

## Issues to Address

### 1. ❌ Guideline 2.1 - Performance - App Completeness
**Issue**: App produced an error when attempting to purchase any of the plans.
**Status**: ✅ FIXED - Removed all subscription/payment functionality

### 2. ❌ Guideline 5.1.1(v) - Data Collection and Storage  
**Issue**: App supports account creation but does not include account deletion option.
**Status**: ✅ FIXED - Added account deletion in Account Settings

### 3. ❌ Guideline 2.1 - Performance - App Completeness
**Issue**: In-app purchase products (Basic Plan, Professional Plan, Enterprise Plan) referenced but not submitted.
**Status**: ✅ FIXED - Removed all subscription/payment references

### 4. ❌ Guideline 1.5 - Safety
**Issue**: Support URL (https://youneedkevin.com) is not functional.
**Status**: ⚠️ NEEDS MANUAL FIX IN APP STORE CONNECT

---

## Changes Made

### Account Deletion Feature
**File**: `Features/Profile/AccountSettingsView.swift`
- Added "Danger Zone" section with account deletion
- Implemented `deleteAccount()` function that:
  - Deletes user document from Firestore
  - Deletes Firebase Auth account
  - Signs out and resets app state
  - Handles re-authentication requirements
- Added confirmation dialog with clear warning message
- Added error handling for failed deletions

### Subscription System Removal
**Files Modified**:
1. `Features/Profile/ProfileView.swift`
   - Removed subscription navigation link from profile menu
   
2. **Files to Delete** (not in use anymore):
   - `Features/Subscription/SubscriptionView.swift`
   - `Features/Subscription/PlanSelectionView.swift`
   - `Features/Subscription/PaymentHistoryView.swift`
   - `Services/StripeService.swift`

3. **Models** (`Models/Entities.swift`):
   - Keep `Subscription`, `Payment`, `SubscriptionPlan` models for now (may be used in future)
   - They won't cause rejection if not actively used in UI

4. **Services** (`Services/FirebaseClient.swift`):
   - Keep subscription-related CRUD methods (commented out or unused won't cause issues)

5. **Health Score Service** (`Services/HealthScoreService.swift`):
   - Made subscription parameter optional
   - Subscription score component can remain (just won't be calculated)

---

## Manual Steps Required

### 1. Update Support URL in App Store Connect
1. Log into App Store Connect
2. Go to your app → App Information
3. Update Support URL to a working URL:
   - Option A: Create a simple support page at `https://youneedkevin.com/support`
   - Option B: Use a mailto link: `mailto:support@youneedkevin.com`
   - Option C: Use a different domain you control with a support page

### 2. Remove Subscription Files from Xcode
1. Open Xcode project
2. Delete these files (Move to Trash):
   - `Features/Subscription/SubscriptionView.swift`
   - `Features/Subscription/PlanSelectionView.swift`  
   - `Features/Subscription/PaymentHistoryView.swift`
   - `Services/StripeService.swift`
3. Delete the empty `Features/Subscription/` folder
4. Build and test to ensure no compilation errors

### 3. Test Account Deletion
1. Run app on device/simulator
2. Sign in with test account
3. Go to Profile → Account Settings
4. Scroll to "Danger Zone"
5. Tap "Delete My Account"
6. Confirm deletion
7. Verify account is deleted and user is signed out

### 4. Increment Version Number
1. In Xcode, select project in navigator
2. Select Kevin target
3. Update version to 1.2.6 (or next appropriate version)
4. Update build number

### 5. Submit New Build
1. Archive the app (Product → Archive)
2. Upload to App Store Connect
3. Submit for review
4. In review notes, mention:
   - "Removed all subscription/payment functionality as we're not charging in-app currently"
   - "Added account deletion feature in Account Settings"
   - "Fixed support URL to [your working URL]"

---

## Testing Checklist

- [ ] App builds without errors
- [ ] No subscription references in UI
- [ ] Account deletion works correctly
- [ ] Account deletion shows proper confirmation
- [ ] Account deletion handles errors gracefully
- [ ] Support URL is functional (check in App Store Connect)
- [ ] App doesn't crash on any screen
- [ ] Profile screen loads correctly
- [ ] Account Settings screen loads correctly

---

## Notes

- Subscription models remain in codebase for future use but are not referenced in UI
- Firebase CRUD methods for subscriptions remain but are unused
- Health score service still has subscription parameter but it's optional
- This approach allows easy re-enablement of subscriptions in future when ready

---

## Estimated Time to Fix
- Code changes: ✅ Complete
- Manual Xcode cleanup: ~5 minutes
- Testing: ~10 minutes  
- App Store Connect updates: ~5 minutes
- Archive and upload: ~15 minutes
- **Total: ~35 minutes**
