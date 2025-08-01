# 🔔 Notification Badge Debugging Guide

## Why Badges Might Not Show

### 1. **Notification Permissions**
Check if badges are enabled:

**Test in app:**
```swift
NotificationService.shared.debugBadgeSettings()
```

**Expected output:**
```
Badge setting: 2 (enabled)
Authorization status: 3 (authorized)
```

**If badge setting is 0 (not allowed):**
- User denied badge permission
- Go to Settings > Kevin > Notifications > Enable "Badges"

### 2. **APNS Configuration**
Badges require APNS (Apple Push Notification Service), not just local notifications.

**Check:**
- Do you have an APNS certificate in Firebase Console?
- Is the app registered for remote notifications?

**Test:**
- Send a real push notification from another device
- Local notifications won't show badges unless manually set

### 3. **Cloud Function Badge Payload**
The Cloud Function MUST include badge in APNS payload.

**Current implementation (CORRECT):**
```javascript
apns: {
  payload: {
    aps: {
      badge: 1,  // ✅ This increments badge
      sound: 'default',
    },
  },
}
```

### 4. **Badge Persistence**
Badge count should persist across app restarts.

**Test:**
1. Receive notification (badge shows "1")
2. Kill app
3. Reopen app
4. Badge should still show "1"

**If badge disappears:**
- Check UserDefaults storage is working
- Run: `NotificationService.shared.debugBadgeSettings()`

---

## Quick Debug Checklist

Run these commands in your app to diagnose:

1. **Check Permission Status**
```swift
NotificationService.shared.debugNotificationStatus()
```

2. **Check FCM Token**
```swift
NotificationService.shared.debugFCMTokenStatus()
```

3. **Check Badge Count**
```swift
print("Current badge: \(UIApplication.shared.applicationIconBadgeNumber)")
print("Stored badge: \(UserDefaults.standard.integer(forKey: "appBadgeCount"))")
```

4. **Test Local Notification with Badge**
```swift
NotificationService.shared.testBadgeNotification()
```

---

## Common Issues & Fixes

### Issue: "Badge is always 0"
**Cause:** App never registered for remote notifications  
**Fix:** Check `UIApplication.shared.registerForRemoteNotifications()` is called

### Issue: "Badge shows but doesn't increment"
**Cause:** Cloud Function not sending badge in payload  
**Fix:** Redeploy Cloud Function with APNS badge config

### Issue: "Badge resets to 0 on app launch"
**Cause:** Badge persistence not working  
**Fix:** Check `syncBadgeCountWithSystem()` restores from UserDefaults

### Issue: "Notifications arrive but no badge"
**Cause:** User has badges disabled in Settings  
**Fix:** User must enable in Settings > Kevin > Notifications > Badges

---

## Manual Test

### Test 1: Local Notification Badge
```swift
let content = UNMutableNotificationContent()
content.title = "Test"
content.body = "Testing badge"
content.badge = 1  // Set badge to 1

let request = UNNotificationRequest(
  identifier: UUID().uuidString,
  content: content,
  trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
)

UNUserNotificationCenter.current().add(request)
```

**Expected:** After 5 seconds, app icon shows badge "1"

### Test 2: Remote Push Notification
1. Create issue from another device/user
2. Check Firebase Console > Cloud Functions logs
3. Look for "Successfully sent X notifications"
4. Badge should appear on your app icon

---

## Production Checklist

✅ APNS certificate configured in Firebase  
✅ App registered for remote notifications  
✅ Cloud Function includes `badge: 1` in APNS payload  
✅ User granted notification permissions with badges  
✅ Badge persistence implemented (UserDefaults)  
✅ Badge clears when notification tapped  

If all checked and badges still don't work, the issue is likely:
1. APNS certificate not configured in Firebase
2. Running on simulator (badges only work on real devices)
3. User disabled badges in system settings
