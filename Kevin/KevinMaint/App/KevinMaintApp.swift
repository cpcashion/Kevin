import SwiftUI
import FirebaseCore
import FirebaseCrashlytics
import FirebasePerformance
import FirebaseMessaging
import UIKit

struct KevinMaintApp: App {
  @UIApplicationDelegateAdaptor(KevinAppDelegate.self) var appDelegate
  @StateObject private var appState = AppState()
  
  init() {
    LaunchTimeProfiler.shared.startProfiling()
    LaunchTimeProfiler.shared.checkpoint("App init started")
    
    FirebaseBootstrap.configure()
    LaunchTimeProfiler.shared.checkpoint("Firebase configured")
    
    // Configure monitoring services
    CrashReportingService.shared.configure()
    PerformanceMonitoringService.shared.trackAppLaunch()
    LaunchTimeProfiler.shared.checkpoint("Monitoring services configured")
    
    configureAppearances()
    LaunchTimeProfiler.shared.checkpoint("Appearances configured")
    
    // PERFORMANCE: Pre-load Google Places cache for instant location selection
    GooglePlacesPersistentCache.preloadCommonPlaces()
    LaunchTimeProfiler.shared.checkpoint("Google Places cache preloaded")
  }
  
  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(appState)
    }
  }
  
  private func configureAppearances() {
    // Configure navigation bar appearance
    let navBarAppearance = UINavigationBarAppearance()
    navBarAppearance.configureWithOpaqueBackground()
    UINavigationBar.appearance().standardAppearance = navBarAppearance
    UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    
    // Configure search bar appearance
    configureSearchBarAppearance()
  }
  
  private func configureSearchBarAppearance() {
    let searchBarAppearance = UISearchBar.appearance()
    searchBarAppearance.searchBarStyle = .minimal
    searchBarAppearance.isTranslucent = true
    searchBarAppearance.backgroundColor = UIColor.clear
    searchBarAppearance.barTintColor = UIColor.clear
  }
}

// MARK: - AppDelegate for Remote Notifications

class KevinAppDelegate: NSObject, UIApplicationDelegate {
  private var lastAPNSToken: Data?
  
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    print("🎨 [KevinAppDelegate] didFinishLaunchingWithOptions")
    return true
  }
  
  // CRITICAL: Handle APNS device token registration
  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Prevent duplicate token registrations
    if let lastToken = lastAPNSToken, lastToken == deviceToken {
      print("⏭️ [KevinAppDelegate] APNS token unchanged, skipping...")
      return
    }
    
    lastAPNSToken = deviceToken
    
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("✅ [KevinAppDelegate] APNS device token registered: \(token)")
    
    // Pass APNS token to Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken
    print("✅ [KevinAppDelegate] APNS token passed to Firebase Messaging")
  }
  
  // Handle APNS registration failure
  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ [KevinAppDelegate] Failed to register for remote notifications: \(error)")
  }
  
  // Handle remote notification when app is in background/killed
  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("🔔 [KevinAppDelegate] Received remote notification in background")
    print("🔔 [KevinAppDelegate] UserInfo: \(userInfo)")
    
    // CRITICAL: Increment badge for background notifications
    // This handles the case when app is in background or killed
    DispatchQueue.main.async {
      let currentBadge = UIApplication.shared.applicationIconBadgeNumber
      UIApplication.shared.applicationIconBadgeNumber = currentBadge + 1
      print("🔔 [KevinAppDelegate] Badge incremented to: \(UIApplication.shared.applicationIconBadgeNumber)")
    }
    
    completionHandler(.newData)
  }
}
