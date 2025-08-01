# 🚀 Notification System Implementation Guide

## Quick Start - Hook Up Notifications

This guide shows you exactly where to add notification calls in your existing code.

---

## 1. Status Change Notifications ✅ READY TO IMPLEMENT

### Where: `MaintenanceServiceV2.swift`

**Current Code (line ~140):**
```swift
func updateStatus(requestId: String, to newStatus: RequestStatus) async throws {
  try await requestDoc(requestId).updateData([
    "status": newStatus.rawValue,
    "updatedAt": Timestamp(date: Date())
  ])
}
```

**Add This:**
```swift
func updateStatus(requestId: String, to newStatus: RequestStatus) async throws {
  // Get old status first
  let snap = try await requestDoc(requestId).getDocument()
  guard let data = snap.data(),
        let oldStatusRaw = data["status"] as? String,
        let oldStatus = RequestStatus(rawValue: oldStatusRaw) else {
    throw NSError(domain: "MaintenanceServiceV2", code: 404, userInfo: nil)
  }
  
  // Update status
  try await requestDoc(requestId).updateData([
    "status": newStatus.rawValue,
    "updatedAt": Timestamp(date: Date())
  ])
  
  // Send notification if status actually changed
  if oldStatus != newStatus {
    await sendStatusChangeNotification(
      requestId: requestId,
      oldStatus: oldStatus,
      newStatus: newStatus
    )
  }
}

private func sendStatusChangeNotification(
  requestId: String,
  oldStatus: RequestStatus,
  newStatus: RequestStatus
) async {
  guard let request = try? await getRequest(id: requestId) else { return }
  
  // Get all participants
  var recipients: Set<String> = [request.reporterId]
  
  // Add admin users
  if let adminIds = try? await FirebaseClient.shared.getAdminUserIds() {
    recipients.formUnion(adminIds)
  }
  
  // Remove current user
  if let currentUserId = Auth.auth().currentUser?.uid {
    recipients.remove(currentUserId)
  }
  
  // Get restaurant name
  let restaurantName = request.businessId // TODO: Resolve to actual name
  
  await NotificationService.shared.sendIssueStatusChangeNotification(
    to: Array(recipients),
    issueTitle: request.title,
    restaurantName: restaurantName,
    oldStatus: oldStatus.rawValue,
    newStatus: newStatus.rawValue,
    issueId: requestId,
    updatedBy: Auth.auth().currentUser?.displayName ?? "Someone"
  )
}
```

---

## 2. Photo Upload Notifications ✅ READY TO IMPLEMENT

### Where: `IssueDetailView.swift` (after photo upload success)

**Find the photo upload success handler (around line 800-900):**

**Add This After Photo Upload:**
```swift
// After successful photo upload
Task {
  await sendPhotoUploadNotification(photoCount: uploadedPhotos.count)
}

// Add this function to IssueDetailView
private func sendPhotoUploadNotification(photoCount: Int) async {
  guard let currentUser = appState.currentAppUser else { return }
  
  // Get all participants
  var recipients: Set<String> = [issue.reporterId]
  
  // Add admins
  if let adminIds = try? await FirebaseClient.shared.getAdminUserIds() {
    recipients.formUnion(adminIds)
  }
  
  // Remove current user
  recipients.remove(currentUser.id)
  
  await NotificationService.shared.sendPhotoUploadNotification(
    to: Array(recipients),
    issueTitle: issue.title,
    restaurantName: getLocationDisplayName(),
    photoCount: photoCount,
    issueId: issue.id,
    uploadedBy: currentUser.name.isEmpty ? (currentUser.email ?? "User") : currentUser.name
  )
}
```

---

## 3. Quote Notifications ✅ READY TO IMPLEMENT

### Where: `QuoteAssistantView.swift` (when quote is sent)

**Find the sendQuote() function:**

**Add This After Quote is Saved:**
```swift
// After successfully saving quote to Firebase
Task {
  await sendQuoteNotification(quote: quote)
}

// Add this function to QuoteAssistantView
private func sendQuoteNotification(quote: Quote) async {
  // Send to issue reporter
  guard let issue = try? await FirebaseClient.shared.fetchIssue(id: quote.issueId) else { return }
  
  let formattedAmount = String(format: "$%.2f", quote.total)
  
  await NotificationService.shared.sendQuoteNotification(
    to: [issue.reporterId],
    quoteAmount: formattedAmount,
    issueTitle: issue.title,
    restaurantName: issue.restaurantId, // TODO: Resolve to name
    quoteId: quote.id,
    issueId: quote.issueId
  )
}
```

### When Quote is Approved:

**Add This When User Approves Quote:**
```swift
// After quote approval is saved
Task {
  await sendQuoteApprovedNotification(quote: quote)
}

private func sendQuoteApprovedNotification(quote: Quote) async {
  guard let currentUser = appState.currentAppUser,
        let issue = try? await FirebaseClient.shared.fetchIssue(id: quote.issueId) else { return }
  
  // Notify admins
  if let adminIds = try? await FirebaseClient.shared.getAdminUserIds() {
    let formattedAmount = String(format: "$%.2f", quote.total)
    
    await NotificationService.shared.sendQuoteApprovedNotification(
      to: adminIds,
      quoteAmount: formattedAmount,
      issueTitle: issue.title,
      restaurantName: issue.restaurantId,
      approvedBy: currentUser.name.isEmpty ? (currentUser.email ?? "User") : currentUser.name,
      issueId: quote.issueId
    )
  }
}
```

---

## 4. Invoice Notifications ✅ READY TO IMPLEMENT

### Where: `InvoiceBuilderView.swift` (when invoice is created)

**Find the saveInvoice() function:**

**Add This After Invoice is Saved:**
```swift
// After successfully saving invoice
Task {
  await sendInvoiceNotification(invoice: savedInvoice)
}

// Add this function to InvoiceBuilderView
private func sendInvoiceNotification(invoice: Invoice) async {
  guard let issue = try? await FirebaseClient.shared.fetchIssue(id: invoice.issueId) else { return }
  
  await NotificationService.shared.sendInvoiceNotification(
    to: [issue.reporterId],
    invoiceNumber: invoice.invoiceNumber,
    amount: invoice.total,
    restaurantName: business?.name ?? "Unknown Business",
    issueTitle: issue.title,
    invoiceId: invoice.id,
    issueId: invoice.issueId
  )
}
```

### When Invoice is Paid:

**Add This When Payment is Recorded:**
```swift
// After payment is recorded
Task {
  await sendInvoicePaidNotification(invoice: invoice)
}

private func sendInvoicePaidNotification(invoice: Invoice) async {
  guard let currentUser = appState.currentAppUser else { return }
  
  // Notify admins
  if let adminIds = try? await FirebaseClient.shared.getAdminUserIds() {
    await NotificationService.shared.sendInvoicePaidNotification(
      to: adminIds,
      invoiceNumber: invoice.invoiceNumber,
      amount: invoice.total,
      restaurantName: business?.name ?? "Unknown Business",
      paidBy: currentUser.name.isEmpty ? (currentUser.email ?? "User") : currentUser.name,
      invoiceId: invoice.id,
      issueId: invoice.issueId
    )
  }
}
```

---

## 5. Assignment Notifications (Future Feature)

**When you add assignment functionality, use this:**

```swift
func assignIssue(issueId: String, to userId: String) async {
  guard let currentUser = appState.currentAppUser,
        let issue = try? await FirebaseClient.shared.fetchIssue(id: issueId) else { return }
  
  // Update assignment in Firebase
  try? await FirebaseClient.shared.updateIssue(issueId, data: ["assignedTo": userId])
  
  // Send notification
  await NotificationService.shared.sendAssignmentNotification(
    to: [userId],
    issueTitle: issue.title,
    restaurantName: issue.restaurantId,
    issueId: issueId,
    assignedBy: currentUser.name.isEmpty ? (currentUser.email ?? "User") : currentUser.name
  )
}
```

---

## Testing Checklist

### 1. Status Change Notifications
- [ ] Create an issue
- [ ] Change status from "reported" to "in_progress"
- [ ] Verify notification appears
- [ ] Tap notification → Opens issue detail
- [ ] Badge count increments

### 2. Photo Upload Notifications
- [ ] Open an issue
- [ ] Upload a photo
- [ ] Verify other participants get notification
- [ ] Tap notification → Opens issue with photos visible

### 3. Quote Notifications
- [ ] Create a quote
- [ ] Send quote
- [ ] Verify customer gets notification
- [ ] Approve quote
- [ ] Verify admin gets approval notification

### 4. Invoice Notifications
- [ ] Create an invoice
- [ ] Send invoice
- [ ] Verify customer gets notification
- [ ] Mark invoice as paid
- [ ] Verify admin gets payment notification

### 5. Badge Management
- [ ] Receive multiple notifications
- [ ] Verify badge count is accurate
- [ ] Open app
- [ ] Verify badge clears
- [ ] Close app and receive notification
- [ ] Verify badge persists across app launches

---

## Troubleshooting

### Notifications Not Appearing

**Check 1: FCM Token**
```swift
NotificationService.shared.debugFCMTokenStatus()
```

**Check 2: Permissions**
```swift
NotificationService.shared.debugNotificationStatus()
```

**Check 3: Cloud Function Logs**
- Go to Firebase Console → Functions
- Check logs for `sendNotifications` function
- Look for errors or "No FCM tokens found"

**Check 4: Notification Triggers**
- Go to Firebase Console → Firestore
- Check `notificationTriggers` collection
- Verify `processed: true` and `successCount > 0`

### Badge Count Wrong

**Reset Badge:**
```swift
NotificationService.shared.clearBadgeCount()
```

**Check Stored Count:**
```swift
let count = UserDefaults.standard.integer(forKey: "appBadgeCount")
print("Stored badge count: \(count)")
```

### Deep Links Not Working

**Verify Delegate:**
```swift
NotificationService.shared.verifyDelegateSetup()
```

**Check Notification UserInfo:**
- Look for `type` and `issueId` fields
- Verify they're strings, not numbers

---

## Performance Considerations

### Batch Notifications
If sending to many users, the Cloud Function handles batching automatically.

### Notification Frequency
- Don't send more than 1 notification per user per issue per minute
- Group related notifications (e.g., "3 new updates" instead of 3 separate)

### Badge Count Sync
- Badge count syncs on app launch
- Persists across app kills
- Clears when user opens notification

---

## Next Steps

1. **Implement status change notifications** (highest priority)
2. **Test thoroughly** with multiple devices
3. **Monitor Cloud Function logs** for errors
4. **Gather user feedback** on notification frequency
5. **Implement notification preferences** (Phase 2)
6. **Add notification grouping** (Phase 2)
7. **Add action buttons** (Phase 2)

---

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Firebase Console logs
3. Verify FCM tokens are being stored
4. Test on a real device (not simulator)
5. Check notification permissions in iOS Settings

---

## Summary

✅ **Notification functions are ready** - Just need to call them  
✅ **Cloud Functions are deployed** - Push delivery works  
✅ **Deep linking works** - Tapping notifications opens correct screens  
✅ **Badge management works** - Counts increment and clear properly  

**You just need to add the function calls in the 4 places above!**
