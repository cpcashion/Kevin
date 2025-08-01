# 🔔 Notifications Quick Reference Card

## 4 Places to Add Notifications (30 Minutes Total)

---

### 1️⃣ Status Changes (5 min)
**File:** `MaintenanceServiceV2.swift` line ~140

```swift
// In updateStatus() function, after the updateData call:
await sendStatusChangeNotification(requestId: requestId, oldStatus: oldStatus, newStatus: newStatus)
```

---

### 2️⃣ Photo Uploads (5 min)
**File:** `IssueDetailView.swift` after photo upload

```swift
// After photos are successfully uploaded:
Task {
  await sendPhotoUploadNotification(photoCount: uploadedPhotos.count)
}
```

---

### 3️⃣ Quotes (10 min)
**File:** `QuoteAssistantView.swift`

```swift
// After quote is saved:
Task { await sendQuoteNotification(quote: quote) }

// After quote is approved:
Task { await sendQuoteApprovedNotification(quote: quote) }
```

---

### 4️⃣ Invoices (10 min)
**File:** `InvoiceBuilderView.swift`

```swift
// After invoice is saved:
Task { await sendInvoiceNotification(invoice: savedInvoice) }

// After payment is recorded:
Task { await sendInvoicePaidNotification(invoice: invoice) }
```

---

## Testing Checklist

- [ ] Create issue → Admin gets notification
- [ ] Add comment → Participants get notification  
- [ ] Change status → Notification appears
- [ ] Upload photo → Notification appears
- [ ] Send quote → Customer gets notification
- [ ] Badge count increments correctly
- [ ] Tapping notification opens correct screen

---

## Troubleshooting

### No notifications?
```swift
NotificationService.shared.debugNotificationStatus()
```

### Badge count wrong?
```swift
NotificationService.shared.clearBadgeCount()
```

### Check Cloud Function logs:
Firebase Console → Functions → sendNotifications

---

## Full Details

See these files for complete implementation:
- **NOTIFICATION_SYSTEM_AUDIT.md** - Full analysis
- **NOTIFICATION_IMPLEMENTATION_GUIDE.md** - Step-by-step code
- **NOTIFICATION_SYSTEM_SUMMARY.md** - Executive summary
