# Quick Actions - Admin Only Access

## ✅ Changes Implemented

**Requirement:** Only admin users should be able to change issue status via Quick Actions buttons. Restaurant owners/operators should not see these buttons since they don't perform the actual work.

---

## 🔧 What Was Changed

### 1. **RequestCardV2 Component**

**File:** `Features/IssuesList/IssuesListView.swift`

**Changes:**
- Added `isAdmin: Bool` parameter to component
- Modified `quickStatusActions` to check `isAdmin` before displaying
- Updated initializer to accept `isAdmin` parameter with default value `false`

**Before:**
```swift
struct RequestCardV2: View {
  @Binding var request: MaintenanceRequest
  let onStatusUpdate: ((MaintenanceRequest, RequestStatus) -> Void)?
  let hasUnread: Bool
  
  init(request: Binding<MaintenanceRequest>, onStatusUpdate: ((MaintenanceRequest, RequestStatus) -> Void)? = nil, hasUnread: Bool = false) {
    // ...
  }
}
```

**After:**
```swift
struct RequestCardV2: View {
  @Binding var request: MaintenanceRequest
  let onStatusUpdate: ((MaintenanceRequest, RequestStatus) -> Void)?
  let hasUnread: Bool
  let isAdmin: Bool  // NEW
  
  init(request: Binding<MaintenanceRequest>, onStatusUpdate: ((MaintenanceRequest, RequestStatus) -> Void)? = nil, hasUnread: Bool = false, isAdmin: Bool = false) {
    // ...
    self.isAdmin = isAdmin  // NEW
  }
}
```

**Quick Actions Logic:**
```swift
private var quickStatusActions: some View {
  let nextStatuses = getNextStatusActions()
  return Group {
    // Only show Quick Actions for admin users
    if isAdmin && !nextStatuses.isEmpty {  // CHANGED: Added isAdmin check
      VStack(alignment: .leading, spacing: 8) {
        Text("Quick Actions")
        // ... buttons
      }
    }
  }
}
```

---

### 2. **IssueCard Component**

**File:** `Features/IssuesList/IssuesListView.swift`

**Changes:**
- Added `isAdmin: Bool` parameter to component
- Modified `quickStatusActions` to check `isAdmin` before displaying
- Updated both initializers to handle `isAdmin` parameter

**Legacy Initializer:**
```swift
// Legacy initializer for backward compatibility
init(issue: Issue) {
  self._issue = .constant(issue)
  self.onStatusUpdate = nil
  self.isAdmin = false  // NEW: Defaults to false for safety
}
```

---

### 3. **IssuesListView - Passing Admin Status**

**File:** `Features/IssuesList/IssuesListView.swift`

**Changes:**
- Pass `appState.currentAppUser?.role == .admin` to `RequestCardV2`

**Implementation:**
```swift
RequestCardV2(
  request: Binding(
    get: { filtered[index] },
    set: { newValue in
      if let originalIndex = requests.firstIndex(where: { $0.id == newValue.id }) {
        requests[originalIndex] = newValue
      }
    }
  ),
  onStatusUpdate: { request, newStatus in
    updateRequestStatus(request, to: newStatus)
  },
  hasUnread: unreadRequestIds.contains(request.id),
  isAdmin: appState.currentAppUser?.role == .admin  // NEW
)
```

---

## 👥 User Experience

### **Admin Users (Chris, Kevin)**
✅ See Quick Actions buttons:
- "In Progress"
- "Completed"

Can change issue status directly from the issues list.

### **Restaurant Owners/Operators**
❌ Do NOT see Quick Actions buttons

Must view issue details to see status (read-only).

---

## 🔍 How It Works

1. **IssuesListView** has access to `@EnvironmentObject var appState: AppState`
2. When rendering each issue card, it checks: `appState.currentAppUser?.role == .admin`
3. Passes this boolean to the card component as `isAdmin` parameter
4. Card component only renders Quick Actions if `isAdmin == true`

---

## 🎯 Status Change Workflow

### **For Admins:**
```
Issues List → See Quick Actions → Tap "In Progress" → Status updates immediately
```

### **For Owners:**
```
Issues List → No Quick Actions visible → Must open issue detail → View status (read-only)
```

---

## 📱 UI Changes

### Before (All Users Saw This):
```
┌─────────────────────────────────┐
│ Issue Title            Reported │
│ Description text...             │
│                                 │
│ QUICK ACTIONS                   │
│ [In Progress] [Completed]       │
└─────────────────────────────────┘
```

### After (Non-Admin Users):
```
┌─────────────────────────────────┐
│ Issue Title            Reported │
│ Description text...             │
│                                 │
│ (No Quick Actions shown)        │
└─────────────────────────────────┘
```

### After (Admin Users):
```
┌─────────────────────────────────┐
│ Issue Title            Reported │
│ Description text...             │
│                                 │
│ QUICK ACTIONS                   │
│ [In Progress] [Completed]       │
└─────────────────────────────────┘
```

---

## ✅ Testing

### Test Case 1: Admin User
1. Log in as Chris (chris.cashion@gmail.com) or Kevin (kevind.cashion@gmail.com)
2. Navigate to Issues tab
3. **Expected:** See "QUICK ACTIONS" section with status buttons

### Test Case 2: Restaurant Owner
1. Log in as restaurant owner (non-admin)
2. Navigate to Issues tab
3. **Expected:** NO "QUICK ACTIONS" section visible

### Test Case 3: Status Changes
1. Admin taps "In Progress" button
2. **Expected:** Issue status updates immediately
3. Owner views same issue
4. **Expected:** Sees updated status but no buttons to change it

---

## 🔒 Security Note

This is a **UI-only restriction**. The actual Firestore security rules should also prevent non-admin users from updating issue status fields. This UI change provides better UX by hiding controls that users don't have permission to use.

**Recommended Firestore Rule:**
```javascript
match /maintenance_requests/{requestId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow update: if request.auth != null && (
    // Allow admins to update status
    (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin') ||
    // Allow owners to update their own requests (but not status)
    (resource.data.reporterId == request.auth.uid && 
     request.resource.data.status == resource.data.status)
  );
}
```

---

## 📝 Files Modified

1. **Features/IssuesList/IssuesListView.swift**
   - `RequestCardV2`: Added `isAdmin` parameter and conditional rendering
   - `IssueCard`: Added `isAdmin` parameter and conditional rendering
   - `IssuesListView`: Pass admin status when creating cards

---

## 🎯 Business Logic

**Why admins only?**
- Admins (Kevin and team) are the ones actually doing the maintenance work
- They need to update status as they progress through jobs
- Restaurant owners just need to report issues and view progress
- Prevents confusion and accidental status changes by owners

**Status Flow:**
1. **Reported** - Owner creates issue → Kevin sees it
2. **In Progress** - Kevin starts work → Owner sees progress
3. **Completed** - Kevin finishes → Owner confirms work is done

Only Kevin (admin) should control the "In Progress" and "Completed" transitions.

---

**Status:** ✅ Implemented and ready for testing

**Expected Result:** Restaurant owners will no longer see Quick Actions buttons on the issues list page.
