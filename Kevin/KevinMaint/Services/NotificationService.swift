import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import UIKit

// MARK: - Notification Names for Deep Linking
extension Notification.Name {
  static let navigateToIssue = Notification.Name("navigateToIssue")
  static let openConversation = Notification.Name("openConversation")
  static let openIssueDetail = Notification.Name("openIssueDetail")
  static let openReceiptDetail = Notification.Name("openReceiptDetail")
  static let refreshIssuesList = Notification.Name("refreshIssuesList")
}

class NotificationService: NSObject, ObservableObject {
  static let shared = NotificationService()
  
  @Published var fcmToken: String?
  @Published var hasNotificationPermission = false
  @Published var unreadNotificationCount = 0
  
  private var isFetchingToken = false
  private let tokenFetchLock = NSLock()
  
  private override init() {
    super.init()
  }
  
  // MARK: - Setup and Permissions
  
  func setupNotifications() {
    print("🔔 [NotificationService] Setting up notifications")
    
    // CRITICAL: Set notification center delegate FIRST
    UNUserNotificationCenter.current().delegate = self
    print("🔔 [NotificationService] Set UNUserNotificationCenter delegate")
    
    // Verify delegate is set correctly
    verifyDelegateSetup()
    
    requestNotificationPermission()
    
    // Set FCM delegate
    Messaging.messaging().delegate = self
    
    // Force registration for remote notifications to get APNS token
    DispatchQueue.main.async {
      UIApplication.shared.registerForRemoteNotifications()
      print("🔔 [NotificationService] Forced registration for remote notifications")
    }
    
    // Check current permission status
    checkNotificationPermissionStatus()
    
    // Get current FCM token
    getCurrentFCMToken()
    
    // Sync badge count with system
    syncBadgeCountWithSystem()
  }
  
  func verifyDelegateSetup() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      let delegate = UNUserNotificationCenter.current().delegate
      if delegate != nil {
        print("✅ [NotificationService] Delegate is set: \(String(describing: delegate))")
        print("✅ [NotificationService] Delegate is NotificationService: \(delegate is NotificationService)")
      } else {
        print("❌❌❌ [NotificationService] CRITICAL: Delegate is NIL!")
        print("❌ [NotificationService] Notification taps will NOT work!")
        print("❌ [NotificationService] Re-setting delegate...")
        UNUserNotificationCenter.current().delegate = self
      }
    }
  }
  
  private func checkNotificationPermissionStatus() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        print("🔔 [NotificationService] Current notification settings:")
        print("🔔 [NotificationService] - Authorization status: \(settings.authorizationStatus.rawValue)")
        print("🔔 [NotificationService] - Alert setting: \(settings.alertSetting.rawValue)")
        print("🔔 [NotificationService] - Badge setting: \(settings.badgeSetting.rawValue)")
        print("🔔 [NotificationService] - Sound setting: \(settings.soundSetting.rawValue)")
        
        self.hasNotificationPermission = settings.authorizationStatus == .authorized
        
        if settings.authorizationStatus == .denied {
          print("❌ [NotificationService] Notifications are DENIED - user needs to enable in Settings")
        } else if settings.authorizationStatus == .notDetermined {
          print("⚠️ [NotificationService] Notifications not determined - will request permission")
        }
      }
    }
  }
  
  private func requestNotificationPermission() {
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { [weak self] granted, error in
      DispatchQueue.main.async {
        self?.hasNotificationPermission = granted
        print("🔔 [NotificationService] Permission granted: \(granted)")
        
        if let error = error {
          print("❌ [NotificationService] Permission error: \(error)")
        }
        
        if granted {
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
        }
      }
    }
  }
  
  private func getCurrentFCMToken() {
    Messaging.messaging().token { [weak self] token, error in
      if let error = error {
        print("❌ [NotificationService] Error fetching FCM token: \(error)")
        
        // Check if this is a simulator issue
        #if targetEnvironment(simulator)
        print("⚠️ [NotificationService] Running in simulator - FCM tokens not available")
        print("💡 [NotificationService] Push notifications will work on real devices")
        #else
        print("❌ [NotificationService] FCM token error on real device - check APNS configuration")
        #endif
      } else if let token = token {
        print("✅ [NotificationService] FCM token retrieved: \(token)")
        Task { @MainActor in
          self?.fcmToken = token
          self?.registerTokenWithServer(token)
        }
      }
    }
  }
  
  // MARK: - Token Management
  
  @MainActor
  private func registerTokenWithServer(_ token: String) {
    // PERFORMANCE: Make FCM token registration completely non-blocking
    // Register in background with low priority to not block app launch
    guard let userId = Auth.auth().currentUser?.uid else {
      return
    }
    
    Task.detached(priority: .background) {
      do {
        try await FirebaseClient.shared.updateUserFCMToken(userId: userId, fcmToken: token)
      } catch {
        // Silent failure - FCM token registration is not critical for app launch
      }
    }
  }
  
  // MARK: - Badge Management
  
  func clearBadgeCount() {
    DispatchQueue.main.async {
      self.unreadNotificationCount = 0
      UIApplication.shared.applicationIconBadgeNumber = 0
      UserDefaults.standard.set(0, forKey: "appBadgeCount")
      print("🔔 [NotificationService] Badge count cleared")
    }
  }
  
  func setBadgeCount(_ count: Int) {
    DispatchQueue.main.async {
      self.unreadNotificationCount = count
      UIApplication.shared.applicationIconBadgeNumber = count
      UserDefaults.standard.set(count, forKey: "appBadgeCount")
      print("🔔 [NotificationService] Badge count set to: \(count)")
    }
  }
  
  private func incrementBadgeCount() {
    DispatchQueue.main.async {
      self.unreadNotificationCount += 1
      UIApplication.shared.applicationIconBadgeNumber = self.unreadNotificationCount
      UserDefaults.standard.set(self.unreadNotificationCount, forKey: "appBadgeCount")
      print("🔔 [NotificationService] Badge count incremented to: \(self.unreadNotificationCount)")
    }
  }
  
  private func syncBadgeCountWithSystem() {
    DispatchQueue.main.async {
      // First try to restore from UserDefaults (persisted across app launches)
      let savedCount = UserDefaults.standard.integer(forKey: "appBadgeCount")
      
      if savedCount > 0 {
        // Restore saved badge count
        self.unreadNotificationCount = savedCount
        UIApplication.shared.applicationIconBadgeNumber = savedCount
        print("🔔 [NotificationService] Restored badge count from storage: \(savedCount)")
      } else {
        // Fallback to system badge if no saved count
        let currentBadgeCount = UIApplication.shared.applicationIconBadgeNumber
        self.unreadNotificationCount = currentBadgeCount
        print("🔔 [NotificationService] Synced badge count with system: \(currentBadgeCount)")
      }
    }
  }
  
  // MARK: - Debug Functions
  
  func debugNotificationStatus() {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔔 [NOTIFICATION DEBUG] Full Status Report")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        print("📱 Authorization Status: \(self.authorizationStatusString(settings.authorizationStatus))")
        print("🔔 Alert Setting: \(self.settingString(settings.alertSetting))")
        print("🔵 Badge Setting: \(self.settingString(settings.badgeSetting))")
        print("🔊 Sound Setting: \(self.settingString(settings.soundSetting))")
        print("🎯 Current Badge Count: \(UIApplication.shared.applicationIconBadgeNumber)")
        print("💾 Stored Badge Count: \(UserDefaults.standard.integer(forKey: "appBadgeCount"))")
        print("📲 FCM Token: \(Messaging.messaging().fcmToken ?? "Not available")")
        print("✅ Has Permission: \(self.hasNotificationPermission)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Recommendations
        if settings.authorizationStatus != .authorized {
          print("⚠️ ISSUE: Notifications not authorized")
          print("💡 FIX: User needs to grant permission in Settings")
        }
        
        if settings.badgeSetting == .disabled {
          print("⚠️ ISSUE: Badges are disabled")
          print("💡 FIX: User needs to enable badges in Settings > Kevin > Notifications")
        }
        
        if Messaging.messaging().fcmToken == nil {
          print("⚠️ ISSUE: No FCM token available")
          print("💡 FIX: App may not be registered for remote notifications")
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      }
    }
  }
  
  private func authorizationStatusString(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "Not Determined (user hasn't been asked)"
    case .denied: return "DENIED (user rejected)"
    case .authorized: return "✅ Authorized"
    case .provisional: return "Provisional"
    case .ephemeral: return "Ephemeral"
    @unknown default: return "Unknown"
    }
  }
  
  private func settingString(_ setting: UNNotificationSetting) -> String {
    switch setting {
    case .notSupported: return "Not Supported"
    case .disabled: return "❌ DISABLED"
    case .enabled: return "✅ Enabled"
    @unknown default: return "Unknown"
    }
  }
  
  func testBadgeNotification() {
    print("🔔 [NotificationService] Testing badge notification")
    showLocalNotification(
      title: "Test Badge Notification",
      body: "This should show a badge on the app icon",
      userInfo: ["type": "test"]
    )
  }
  
  func debugBadgeSettings() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        print("🔔 [NotificationService] ===== BADGE DEBUG =====")
        print("🔔 [NotificationService] Authorization: \(settings.authorizationStatus.rawValue)")
        print("🔔 [NotificationService] Badge Setting: \(settings.badgeSetting.rawValue)")
        print("🔔 [NotificationService] Alert Setting: \(settings.alertSetting.rawValue)")
        print("🔔 [NotificationService] Sound Setting: \(settings.soundSetting.rawValue)")
        print("🔔 [NotificationService] Current Badge Count: \(self.unreadNotificationCount)")
        print("🔔 [NotificationService] System Badge Count: \(UIApplication.shared.applicationIconBadgeNumber)")
        
        // Badge setting values: 0 = notSupported, 1 = disabled, 2 = enabled
        switch settings.badgeSetting {
        case .enabled:
          print("✅ [NotificationService] Badge is ENABLED")
        case .disabled:
          print("❌ [NotificationService] Badge is DISABLED - User must enable in Settings > Kevin > Notifications > Badges")
        case .notSupported:
          print("⚠️ [NotificationService] Badge not supported on this device")
        @unknown default:
          print("❓ [NotificationService] Unknown badge setting")
        }
      }
    }
  }
  
  // MARK: - Debug Functions for FCM Token
  
  func debugFCMTokenStatus() {
    print("🔍 [NotificationService] ===== FCM TOKEN DEBUG =====")
    print("🔍 [NotificationService] Current FCM Token: \(fcmToken ?? "❌ NO TOKEN")")
    print("🔍 [NotificationService] Has notification permission: \(hasNotificationPermission)")
    
    if let currentUser = Auth.auth().currentUser {
      print("🔍 [NotificationService] Current user ID: \(currentUser.uid)")
      print("🔍 [NotificationService] Current user email: \(currentUser.email ?? "nil")")
      
      // Check if this user is in Firebase with FCM token
      Task {
        do {
          let userDoc = try await Firestore.firestore().collection("users").document(currentUser.uid).getDocument()
          if userDoc.exists {
            let userData = userDoc.data()
            let storedToken = userData?["fcmToken"] as? String
            print("🔍 [NotificationService] Stored FCM token in Firebase: \(storedToken?.prefix(20) ?? "❌ NO TOKEN")...")
            
            if let tokenDate = userData?["tokenUpdatedAt"] as? Timestamp {
              print("🔍 [NotificationService] Token last updated: \(tokenDate.dateValue())")
            }
          } else {
            print("❌ [NotificationService] User document not found in Firebase")
          }
        } catch {
          print("❌ [NotificationService] Error checking Firebase token: \(error)")
        }
      }
    } else {
      print("🔍 [NotificationService] No authenticated user")
    }
    
    // Check current notification settings
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        print("🔍 [NotificationService] Notification authorization: \(settings.authorizationStatus.rawValue)")
        print("🔍 [NotificationService] Badge setting: \(settings.badgeSetting.rawValue)")
        
        // Authorization status meanings:
        // 0 = notDetermined, 1 = denied, 2 = authorized, 3 = provisional, 4 = ephemeral
        switch settings.authorizationStatus {
        case .notDetermined:
          print("🔍 [NotificationService] Status: Not Determined - Need to request permission")
        case .denied:
          print("❌ [NotificationService] Status: DENIED - User must enable in Settings")
        case .authorized:
          print("✅ [NotificationService] Status: AUTHORIZED - Notifications enabled")
        case .provisional:
          print("⚠️ [NotificationService] Status: PROVISIONAL - Quiet notifications only")
        case .ephemeral:
          print("⚠️ [NotificationService] Status: EPHEMERAL - App Clips only")
        @unknown default:
          print("❓ [NotificationService] Status: Unknown")
        }
      }
    }
  }
  
  func testNotificationFlow() async {
    print("🧪 [NotificationService] ===== TESTING NOTIFICATION FLOW =====")
    
    // Test admin user lookup
    do {
      let adminEmails = AdminConfig.adminEmails
      print("🧪 [NotificationService] Admin emails to lookup: \(adminEmails)")
      
      let adminUserIds = try await FirebaseClient.shared.getAdminUserIds(adminEmails: adminEmails)
      print("🧪 [NotificationService] Found admin user IDs: \(adminUserIds)")
      
      // Check if admin users have FCM tokens
      for adminId in adminUserIds {
        do {
          let userDoc = try await Firestore.firestore().collection("users").document(adminId).getDocument()
          if userDoc.exists {
            let userData = userDoc.data()
            let fcmToken = userData?["fcmToken"] as? String
            print("🧪 [NotificationService] Admin \(adminId) FCM token: \(fcmToken?.prefix(20) ?? "❌ NO TOKEN")...")
          } else {
            print("❌ [NotificationService] Admin user document not found: \(adminId)")
          }
        } catch {
          print("❌ [NotificationService] Error checking admin user \(adminId): \(error)")
        }
      }
      
      if !adminUserIds.isEmpty {
        // Test sending a notification
        await sendWorkUpdateNotification(
          to: adminUserIds,
          issueTitle: "🧪 TEST NOTIFICATION",
          restaurantName: "Test Restaurant",
          updateType: "test",
          issueId: "test-issue-id",
          updatedBy: "Test User"
        )
        print("🧪 [NotificationService] Test notification sent - Check Firebase logs!")
      } else {
        print("⚠️ [NotificationService] No admin users found")
      }
    } catch {
      print("❌ [NotificationService] Test failed: \(error)")
    }
  }
  
  // MARK: - FCM Token Management
  
  func registerFCMTokenAfterAPNS() {
    print("🔔 [NotificationService] APNS token received, registering FCM token...")
    
    // Prevent concurrent token fetches
    tokenFetchLock.lock()
    if isFetchingToken {
      print("⏭️ [NotificationService] Token fetch already in progress, skipping...")
      tokenFetchLock.unlock()
      return
    }
    isFetchingToken = true
    tokenFetchLock.unlock()
    
    Task {
      await fetchFCMToken()
      tokenFetchLock.lock()
      isFetchingToken = false
      tokenFetchLock.unlock()
    }
  }
  
  func fetchFCMToken() async {
    do {
      let token = try await Messaging.messaging().token()
      
      await MainActor.run {
        fcmToken = token
      }
      
      print("✅ [NotificationService] FCM token: \(token)")
      
      // Store token for current user
      if Auth.auth().currentUser?.uid != nil {
        await MainActor.run {
          registerTokenWithServer(token)
        }
      }
    } catch {
      print("❌ [NotificationService] Error fetching FCM token: \(error)")
    }
  }
  
  // MARK: - Notification Sending
  
  // MARK: - Issue Status Change Notifications
  func sendIssueStatusChangeNotification(
    to userIds: [String],
    issueTitle: String,
    restaurantName: String,
    oldStatus: String,
    newStatus: String,
    issueId: String,
    updatedBy: String
  ) async {
    print("🔔 [NotificationService] Sending status change notification")
    print("🔔 [NotificationService] - Issue: \(issueTitle)")
    print("🔔 [NotificationService] - Restaurant: \(restaurantName)")
    print("🔔 [NotificationService] - Status: \(oldStatus) → \(newStatus)")
    
    let title = "Issue Status Updated"
    let body = "\(restaurantName): '\(issueTitle)' is now \(newStatus)"
    
    let notificationData: [String: Any] = [
      "type": "issue_status_change",
      "issueId": issueId,
      "restaurantName": restaurantName,
      "oldStatus": oldStatus,
      "newStatus": newStatus,
      "updatedBy": updatedBy,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  // MARK: - Work Update Notifications
  func sendWorkUpdateNotification(
    to userIds: [String],
    issueTitle: String,
    restaurantName: String,
    updateType: String,
    issueId: String,
    updatedBy: String
  ) async {
    print("🔔 [NotificationService] Sending work update notification")
    print("🔔 [NotificationService] - Issue: \(issueTitle)")
    print("🔔 [NotificationService] - Update type: \(updateType)")
    
    // Create enhanced notification content
    let notificationTitle = "New Update: \(restaurantName)"
    let truncatedIssueTitle = String(issueTitle.prefix(50)) + (issueTitle.count > 50 ? "..." : "")
    let notificationBody = "\(updatedBy) posted an update on '\(truncatedIssueTitle)'"
    
    print("🔔 [NotificationService] Creating enhanced notification:")
    print("🔔 [NotificationService] - Title: \(notificationTitle)")
    print("🔔 [NotificationService] - Body: \(notificationBody)")
    
    let userInfo: [String: Any] = [
      "type": "work_update",
      "issueId": issueId,
      "updateType": updateType,
      "restaurantName": restaurantName,
      "updatedBy": updatedBy,
      "timestamp": Date().timeIntervalSince1970,
      "deepLink": "issue://\(issueId)" // Deep link for navigation
    ]
    
    print("🔔 [NotificationService] - UserInfo: \(userInfo)")
    print("🔔 [NotificationService] - Has permission: \(hasNotificationPermission)")
    
    // Show local notification for testing
    showLocalNotification(
      title: notificationTitle,
      body: notificationBody,
      userInfo: userInfo
    )
    
    // Send push notification via Firebase Cloud Function
    do {
      try await FirebaseClient().sendNotificationTrigger(
        userIds: userIds,
        title: notificationTitle,
        body: notificationBody,
        data: userInfo
      )
      print("✅ [NotificationService] Notification trigger sent")
    } catch {
      print("❌ [NotificationService] Failed to send notification: \(error)")
      print("🔔 [NotificationService] Falling back to local notification only")
    }
  }
  
  // MARK: - Receipt Status Notifications
  func sendReceiptStatusNotification(
    to userIds: [String],
    receiptAmount: String,
    issueTitle: String,
    restaurantName: String,
    status: String, // "approved", "rejected", "needs_revision"
    receiptId: String,
    reviewNotes: String? = nil
  ) async {
    print("🔔 [NotificationService] Sending receipt status notification")
    print("🔔 [NotificationService] - Receipt: \(receiptAmount)")
    print("🔔 [NotificationService] - Status: \(status)")
    
    let title: String
    let body: String
    
    switch status {
    case "approved":
      title = "Receipt Approved ✅"
      body = "Receipt for \(receiptAmount) approved - \(issueTitle)"
    case "rejected":
      title = "Receipt Rejected ❌"
      body = "Receipt for \(receiptAmount) rejected - \(reviewNotes ?? "See details")"
    case "needs_revision":
      title = "Receipt Needs Revision ⚠️"
      body = "Receipt for \(receiptAmount) needs changes - \(reviewNotes ?? "See details")"
    default:
      title = "Receipt Status Updated"
      body = "Receipt for \(receiptAmount) - \(status)"
    }
    
    let notificationData: [String: Any] = [
      "type": "receipt_status",
      "receiptId": receiptId,
      "issueTitle": issueTitle,
      "restaurantName": restaurantName,
      "status": status,
      "amount": receiptAmount,
      "reviewNotes": reviewNotes ?? "",
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  // MARK: - Enhanced Message Notifications
  func sendEnhancedMessageNotification(
    to userIds: [String],
    senderName: String,
    messagePreview: String,
    conversationId: String,
    senderId: String,
    restaurantName: String? = nil,
    issueTitle: String? = nil,
    issueId: String? = nil
  ) async {
    print("🔔 [NotificationService] Sending enhanced message notification")
    print("🔔 [NotificationService] - Sender: \(senderName)")
    print("🔔 [NotificationService] - Issue context: \(issueTitle ?? "General")")
    
    let title: String
    let body: String
    
    if let issueTitle = issueTitle, let restaurantName = restaurantName {
      title = "\(senderName) replied"
      body = "About '\(issueTitle)' at \(restaurantName): \(messagePreview)"
    } else if let restaurantName = restaurantName {
      title = "\(senderName) sent a message"
      body = "\(restaurantName): \(messagePreview)"
    } else {
      title = "\(senderName) sent a message"
      body = messagePreview
    }
    
    let notificationData: [String: Any] = [
      "type": "message_enhanced",
      "conversationId": conversationId,
      "senderId": senderId,
      "senderName": senderName,
      "restaurantName": restaurantName ?? "",
      "issueTitle": issueTitle ?? "",
      "issueId": issueId ?? "",
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  // MARK: - Urgent Issue Alerts
  func sendUrgentIssueAlert(
    to userIds: [String],
    issueTitle: String,
    restaurantName: String,
    priority: String,
    issueId: String,
    reportedBy: String
  ) async {
    print("🔔 [NotificationService] Sending URGENT issue alert")
    print("🔔 [NotificationService] - Issue: \(issueTitle)")
    print("🔔 [NotificationService] - Priority: \(priority)")
    
    let title = "🚨 \(priority.uppercased()) ISSUE"
    let body = "\(restaurantName): \(issueTitle)"
    
    let notificationData: [String: Any] = [
      "type": "urgent_issue",
      "issueId": issueId,
      "restaurantName": restaurantName,
      "priority": priority,
      "reportedBy": reportedBy,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  // MARK: - Photo Upload Notifications
  func sendPhotoUploadNotification(
    to userIds: [String],
    issueTitle: String,
    restaurantName: String,
    photoCount: Int,
    issueId: String,
    uploadedBy: String
  ) async {
    print("🔔 [NotificationService] Sending photo upload notification")
    print("🔔 [NotificationService] - Photos: \(photoCount)")
    
    let title = "📸 New Photo\(photoCount > 1 ? "s" : "") Added"
    let body = "\(uploadedBy) added \(photoCount) photo\(photoCount > 1 ? "s" : "") to '\(issueTitle)' at \(restaurantName)"
    
    let notificationData: [String: Any] = [
      "type": "photo_upload",
      "issueId": issueId,
      "restaurantName": restaurantName,
      "photoCount": photoCount,
      "uploadedBy": uploadedBy,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  // MARK: - Mention Notifications
  func sendMentionNotification(
    to userIds: [String],
    issueTitle: String,
    restaurantName: String,
    message: String,
    issueId: String,
    mentionedBy: String
  ) async {
    print("🔔 [NotificationService] Sending mention notification")
    print("🔔 [NotificationService] - Mentioned users: \(userIds.count)")
    
    let title = "💬 \(mentionedBy) mentioned you"
    let preview = message.count > 50 ? String(message.prefix(50)) + "..." : message
    let body = "\(restaurantName): \(preview)"
    
    let notificationData: [String: Any] = [
      "type": "mention",
      "issueId": issueId,
      "restaurantName": restaurantName,
      "mentionedBy": mentionedBy,
      "message": message,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  // MARK: - Assignment Notifications
  func sendAssignmentNotification(
    to userIds: [String],
    issueTitle: String,
    restaurantName: String,
    issueId: String,
    assignedBy: String
  ) async {
    print("🔔 [NotificationService] Sending assignment notification")
    
    let title = "👤 You've Been Assigned"
    let body = "\(assignedBy) assigned you to '\(issueTitle)' at \(restaurantName)"
    
    let notificationData: [String: Any] = [
      "type": "assignment",
      "issueId": issueId,
      "restaurantName": restaurantName,
      "assignedBy": assignedBy,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  // MARK: - Quote Notifications
  func sendQuoteNotification(
    to userIds: [String],
    quoteAmount: String,
    issueTitle: String,
    restaurantName: String,
    quoteId: String,
    issueId: String
  ) async {
    print("🔔 [NotificationService] Sending quote notification")
    
    let title = "💰 Quote Received"
    let body = "Quote for \(quoteAmount) - '\(issueTitle)' at \(restaurantName)"
    
    let notificationData: [String: Any] = [
      "type": "quote",
      "issueId": issueId,
      "quoteId": quoteId,
      "restaurantName": restaurantName,
      "amount": quoteAmount,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  func sendQuoteApprovedNotification(
    to userIds: [String],
    quoteAmount: String,
    issueTitle: String,
    restaurantName: String,
    approvedBy: String,
    issueId: String
  ) async {
    print("🔔 [NotificationService] Sending quote approved notification")
    
    let title = "✅ Quote Approved"
    let body = "\(approvedBy) approved quote for \(quoteAmount) - '\(issueTitle)'"
    
    let notificationData: [String: Any] = [
      "type": "quote_approved",
      "issueId": issueId,
      "restaurantName": restaurantName,
      "amount": quoteAmount,
      "approvedBy": approvedBy,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  // MARK: - Invoice Notifications
  func sendInvoiceNotification(
    to userIds: [String],
    invoiceNumber: String,
    amount: Double,
    restaurantName: String,
    issueTitle: String,
    invoiceId: String,
    issueId: String
  ) async {
    print("🔔 [NotificationService] Sending invoice notification")
    
    let formattedAmount = String(format: "$%.2f", amount)
    let title = "📄 Invoice \(invoiceNumber)"
    let body = "Invoice for \(formattedAmount) - '\(issueTitle)' at \(restaurantName)"
    
    let notificationData: [String: Any] = [
      "type": "invoice",
      "issueId": issueId,
      "invoiceId": invoiceId,
      "restaurantName": restaurantName,
      "amount": formattedAmount,
      "invoiceNumber": invoiceNumber,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  func sendInvoicePaidNotification(
    to userIds: [String],
    invoiceNumber: String,
    amount: Double,
    restaurantName: String,
    paidBy: String,
    invoiceId: String,
    issueId: String
  ) async {
    print("🔔 [NotificationService] Sending invoice paid notification")
    
    let formattedAmount = String(format: "$%.2f", amount)
    let title = "💳 Payment Received"
    let body = "\(paidBy) paid invoice \(invoiceNumber) for \(formattedAmount)"
    
    let notificationData: [String: Any] = [
      "type": "invoice_paid",
      "issueId": issueId,
      "invoiceId": invoiceId,
      "restaurantName": restaurantName,
      "amount": formattedAmount,
      "paidBy": paidBy,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    await sendNotification(
      to: userIds,
      title: title,
      body: body,
      data: notificationData
    )
  }
  
  // MARK: - Generic Notification Sender
  private func sendNotification(
    to userIds: [String],
    title: String,
    body: String,
    data: [String: Any]
  ) async {
    // Show local notification for testing
    showLocalNotification(
      title: title,
      body: body,
      userInfo: data
    )
    
    // Send via Cloud Functions
    do {
      try await FirebaseClient().sendNotificationTrigger(
        userIds: userIds,
        title: title,
        body: body,
        data: data
      )
      print("✅ [NotificationService] Notification trigger sent")
    } catch {
      print("❌ [NotificationService] Failed to send notification: \(error)")
    }
  }
  
  func sendMessageNotification(
    to userIds: [String],
    title: String,
    body: String,
    conversationId: String,
    senderId: String,
    restaurantName: String? = nil
  ) async {
    print("🔔 [NotificationService] Sending notification to \(userIds.count) users")
    print("🔔 [NotificationService] - Recipients: \(userIds)")
    print("🔔 [NotificationService] - Title: \(title)")
    print("🔔 [NotificationService] - Body: \(body)")
    print("🔔 [NotificationService] - Conversation ID: \(conversationId)")
    
    let notificationData: [String: Any] = [
      "type": "message",
      "conversationId": conversationId,
      "senderId": senderId,
      "restaurantName": restaurantName ?? "",
      "timestamp": Date().timeIntervalSince1970
    ]
    
    // For testing: show immediate local notification
    showLocalNotification(
      title: "Push: \(title)",
      body: body,
      userInfo: notificationData
    )
    
    // In a real app, this would call your backend API to send FCM notifications
    // For now, we'll use Firestore to trigger notifications via Cloud Functions
    do {
      try await FirebaseClient().sendNotificationTrigger(
        userIds: userIds,
        title: title,
        body: body,
        data: notificationData
      )
      print("✅ [NotificationService] Notification trigger sent")
    } catch {
      print("❌ [NotificationService] Failed to send notification: \(error)")
      print("🔔 [NotificationService] Falling back to local notification only")
    }
  }
  
  func sendIssueNotification(
    to adminUserIds: [String],
    issueTitle: String,
    restaurantName: String,
    priority: String,
    issueId: String
  ) async {
    print("🔔 [NotificationService] Sending issue notification to \(adminUserIds.count) admins")
    print("🔔 [NotificationService] - Issue: \(issueTitle)")
    print("🔔 [NotificationService] - Restaurant: \(restaurantName)")
    print("🔔 [NotificationService] - Priority: \(priority)")
    
    let title = "New \(priority.capitalized) Issue"
    let body = "\(restaurantName): \(issueTitle)"
    
    let notificationData: [String: Any] = [
      "type": "issue",
      "issueId": issueId,
      "restaurantName": restaurantName,
      "priority": priority,
      "timestamp": Date().timeIntervalSince1970
    ]
    
    // Show local notification for testing
    showLocalNotification(
      title: title,
      body: body,
      userInfo: notificationData
    )
    
    // Send via Cloud Functions
    do {
      try await FirebaseClient().sendNotificationTrigger(
        userIds: adminUserIds,
        title: title,
        body: body,
        data: notificationData
      )
      print("✅ [NotificationService] Issue notification trigger sent")
    } catch {
      print("❌ [NotificationService] Failed to send issue notification: \(error)")
    }
  }
  
  // MARK: - Notification History Logging
  
  private func logNotificationToHistory(title: String, body: String, userInfo: [AnyHashable: Any]) {
    guard let typeString = userInfo["type"] as? String else {
      print("⚠️ [NotificationService] No type in notification userInfo")
      return
    }
    
    let notificationType: NotificationType
    switch typeString {
    case "issue", "issue_created":
      notificationType = .issueCreated
    case "work_update":
      notificationType = .workUpdate
    case "issue_status", "issue_status_change":
      notificationType = .statusChanged
    case "message", "message_enhanced":
      notificationType = .message
    case "receipt_status":
      notificationType = .receiptStatus
    case "urgent_issue":
      notificationType = .urgentIssue
    case "photo_upload":
      notificationType = .issueUpdated // Photo upload is an issue update
    case "assignment":
      notificationType = .issueAssigned
    case "quote", "quote_approved":
      notificationType = .quoteReceived
    case "invoice", "invoice_paid":
      notificationType = .invoiceReceived
    default:
      notificationType = .issueUpdated
    }
    
    let issueId = userInfo["issueId"] as? String
    let conversationId = userInfo["conversationId"] as? String
    
    var metadata: [String: String] = [:]
    if let restaurantName = userInfo["restaurantName"] as? String {
      metadata["restaurantName"] = restaurantName
    }
    if let priority = userInfo["priority"] as? String {
      metadata["priority"] = priority
    }
    if let updatedBy = userInfo["updatedBy"] as? String {
      metadata["updatedBy"] = updatedBy
    }
    
    NotificationHistoryService.shared.addNotification(
      type: notificationType,
      title: title,
      message: body,
      issueId: issueId,
      conversationId: conversationId,
      metadata: metadata.isEmpty ? nil : metadata
    )
  }
  
  // MARK: - Local Notifications (Fallback)
  
  func showLocalNotification(title: String, body: String, userInfo: [AnyHashable: Any] = [:]) {
    print("🔔 [NotificationService] Creating local notification:")
    print("🔔 [NotificationService] - Title: \(title)")
    print("🔔 [NotificationService] - Body: \(body)")
    print("🔔 [NotificationService] - UserInfo: \(userInfo)")
    print("🔔 [NotificationService] - Has permission: \(hasNotificationPermission)")
    
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    
    // Compute next absolute badge count and persist
    let current = max(self.unreadNotificationCount, UIApplication.shared.applicationIconBadgeNumber)
    let next = current + 1
    self.unreadNotificationCount = next
    UIApplication.shared.applicationIconBadgeNumber = next
    UserDefaults.standard.set(next, forKey: "appBadgeCount")
    content.badge = NSNumber(value: next)
    
    // Mark this as a local notification to avoid double-increment in willPresent
    var fullInfo = userInfo
    fullInfo["__local"] = true
    content.userInfo = fullInfo
    
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    )
    
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("❌ [NotificationService] Local notification error: \(error)")
      } else {
        print("✅ [NotificationService] Local notification scheduled successfully")
        print("🔔 [NotificationService] Notification ID: \(request.identifier)")
      }
    }
  }
}

// MARK: - MessagingDelegate (Disabled until FirebaseMessaging is added)

// MARK: - MessagingDelegate

extension NotificationService: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔔 [NotificationService] FCM registration token updated: \(fcmToken ?? "nil")")
    
    // Prevent concurrent token updates
    tokenFetchLock.lock()
    let shouldUpdate = self.fcmToken != fcmToken
    tokenFetchLock.unlock()
    
    guard shouldUpdate else {
      print("⏭️ [NotificationService] Token unchanged, skipping update")
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.fcmToken = fcmToken
      if let token = fcmToken {
        self.registerTokenWithServer(token)
      }
    }
  }
}


// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
  // Handle notifications when app is in foreground
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("🔔 [NotificationService] Foreground notification: \(userInfo)")
    
    // Increment badge ONLY for remote notifications (locals are already counted when scheduled)
    let isLocal = (userInfo["__local"] as? Bool) == true
    if !isLocal {
      incrementBadgeCount()
    }
    
    // Log to notification history
    logNotificationToHistory(
      title: notification.request.content.title,
      body: notification.request.content.body,
      userInfo: userInfo
    )
    
    // Show notification even when app is in foreground
    completionHandler([.banner, .sound, .badge])
  }
  
  // MARK: - Notification Handling
  
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    print("🚨🚨🚨 [NotificationService] ===== USER TAPPED NOTIFICATION =====")
    print("🚨 [NotificationService] Response action identifier: \(response.actionIdentifier)")
    print("🚨 [NotificationService] Notification request identifier: \(response.notification.request.identifier)")
    
    let userInfo = response.notification.request.content.userInfo
    print("🚨 [NotificationService] UserInfo: \(userInfo)")
    
    // Handle notification tap and deep linking
    handleNotificationTap(userInfo: userInfo)
    
    // Clear badge count when notification is tapped
    clearBadgeCount()
    
    print("🚨🚨🚨 [NotificationService] ===== NOTIFICATION TAP COMPLETE =====")
    completionHandler()
  }
  
  private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
    print("🔔 [NotificationService] ===== HANDLING NOTIFICATION TAP =====")
    print("🔔 [NotificationService] Full userInfo: \(userInfo)")
    
    guard let type = userInfo["type"] as? String else {
      print("❌ [NotificationService] No notification type found in userInfo")
      return
    }
    
    print("🔔 [NotificationService] Notification type: \(type)")
    
    switch type {
    case "work_update":
      handleWorkUpdateNotificationTap(userInfo: userInfo)
    case "receipt_status":
      handleReceiptNotificationTap(userInfo: userInfo)
    case "issue_status", "issue_status_change":
      handleIssueStatusNotificationTap(userInfo: userInfo)
    case "message", "message_enhanced":
      // Handle both message types
      handleMessageNotificationTap(userInfo: userInfo)
    case "issue", "issue_created":
      handleIssueNotificationTap(userInfo: userInfo)
    case "photo_upload", "assignment", "quote", "quote_approved", "invoice", "invoice_paid", "urgent_issue":
      // All these navigate to issue detail
      handleIssueNotificationTap(userInfo: userInfo)
    default:
      print("❌ [NotificationService] Unknown notification type: \(type)")
      print("❌ [NotificationService] Available types: message, work_update, receipt_status, issue_status, photo_upload, assignment, quote, invoice")
    }
    
    print("🔔 [NotificationService] ===== NOTIFICATION TAP HANDLING COMPLETE =====")
  }
  
  private func handleWorkUpdateNotificationTap(userInfo: [AnyHashable: Any]) {
    guard let issueId = userInfo["issueId"] as? String else {
      print("🔔 [NotificationService] No issueId in work update notification")
      return
    }
    
    print("🔔 [NotificationService] Navigating to issue: \(issueId)")
    
    // Post notification for deep linking
    NotificationCenter.default.post(
      name: .navigateToIssue,
      object: nil,
      userInfo: ["issueId": issueId]
    )
  }
  
  private func handleReceiptNotificationTap(userInfo: [AnyHashable: Any]) {
    guard let issueId = userInfo["issueId"] as? String else { return }
    
    // Navigate to issue with receipts tab selected
    NotificationCenter.default.post(
      name: .navigateToIssue,
      object: nil,
      userInfo: ["issueId": issueId, "tab": "receipts"]
    )
  }
  
  private func handleIssueStatusNotificationTap(userInfo: [AnyHashable: Any]) {
    guard let issueId = userInfo["issueId"] as? String else { return }
    
    // Navigate to issue detail
    NotificationCenter.default.post(
      name: .navigateToIssue,
      object: nil,
      userInfo: ["issueId": issueId]
    )
  }
  
  private func handleMessageNotificationTap(userInfo: [AnyHashable: Any]) {
    print("🔔 [NotificationService] Handling message notification tap")
    print("🔔 [NotificationService] UserInfo: \(userInfo)")
    // Prefer navigating directly to the issue timeline if present
    if let issueId = userInfo["issueId"] as? String, !issueId.isEmpty {
      print("🔔 [NotificationService] Navigating to issue from message notification: \(issueId)")
      NotificationCenter.default.post(
        name: .navigateToIssue,
        object: nil,
        userInfo: ["issueId": issueId]
      )
      return
    }

    // Fallback to opening the legacy conversation flow
    guard let conversationId = userInfo["conversationId"] as? String else {
      print("⚠️ [NotificationService] No conversation ID in notification and no issueId; nothing to open")
      return
    }
    print("🔔 [NotificationService] Opening conversation: \(conversationId)")
    NotificationCenter.default.post(
      name: .openConversation,
      object: nil,
      userInfo: ["conversationId": conversationId]
    )
    print("✅ [NotificationService] Posted openConversation notification")
  }
  
  private func handleIssueNotificationTap(userInfo: [AnyHashable: Any]) {
    print("🔔 [NotificationService] Handling issue notification tap")
    print("🔔 [NotificationService] UserInfo: \(userInfo)")
    
    guard let issueId = userInfo["issueId"] as? String else {
      print("⚠️ [NotificationService] No issue ID in notification")
      return
    }
    
    print("🔔 [NotificationService] Opening issue: \(issueId)")
    
    // Post notification to open the issue detail
    NotificationCenter.default.post(
      name: .openIssueDetail,
      object: nil,
      userInfo: ["issueId": issueId]
    )
    
    print("✅ [NotificationService] Posted openIssueDetail notification")
  }
  
}
