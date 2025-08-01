import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseAuth
import GoogleSignIn
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Firebase on main thread to avoid threading issues
        FirebaseBootstrap.configure()
        
        // Initialize Google Sign-In
        if let clientId = FirebaseApp.app()?.options.clientID {
            let config = GIDConfiguration(clientID: clientId)
            GIDSignIn.sharedInstance.configuration = config
        }
        
        // Setup push notifications
        NotificationService.shared.setupNotifications()
        
        // Set Firebase Messaging delegate to receive FCM token updates
        Messaging.messaging().delegate = self
        
        // Configure consistent dark blue tab bar theme globally at app startup
        configureGlobalTabBarTheme()
        
        // Configure status bar style
        configureStatusBarStyle()
        
        // Force window and safe area background color to match theme
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    window.backgroundColor = UIColor(red: 0.078, green: 0.098, blue: 0.149, alpha: 1.0) // #141926
                    // Also set the root view controller background
                    window.rootViewController?.view.backgroundColor = UIColor(red: 0.078, green: 0.098, blue: 0.149, alpha: 1.0)
                }
            }
        }
        
        return true
    }
    
    private func configureGlobalTabBarTheme() {
        // Import theme colors - fixed dark blue (#141926)
        let darkBlueBackground = UIColor(red: 0.078, green: 0.098, blue: 0.149, alpha: 1.0)
        let cardBackground = UIColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0) // KMTheme.cardBackground
        let lightGrayInactive = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let brightBlueActive = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0) // KMTheme.accent
        let primaryText = UIColor.white
        let secondaryText = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
        
        // MARK: - Tab Bar Configuration
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = darkBlueBackground
        appearance.shadowColor = UIColor.clear
        appearance.shadowImage = UIImage()
        appearance.selectionIndicatorTintColor = UIColor.clear
        
        // Selected tab item - bright blue on dark background
        appearance.stackedLayoutAppearance.selected.iconColor = brightBlueActive
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: brightBlueActive,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance.selected.badgeBackgroundColor = UIColor.clear
        
        // Normal tab item - light gray on dark background
        appearance.stackedLayoutAppearance.normal.iconColor = lightGrayInactive
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: lightGrayInactive,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = UIColor.clear
        
        // Create identical scroll appearance
        let scrollAppearance = UITabBarAppearance()
        scrollAppearance.configureWithOpaqueBackground()
        scrollAppearance.backgroundColor = darkBlueBackground
        scrollAppearance.shadowColor = UIColor.clear
        scrollAppearance.shadowImage = UIImage()
        scrollAppearance.selectionIndicatorTintColor = UIColor.clear
        scrollAppearance.stackedLayoutAppearance = appearance.stackedLayoutAppearance
        
        // Apply tab bar styling
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = scrollAppearance
        UITabBar.appearance().tintColor = brightBlueActive
        UITabBar.appearance().unselectedItemTintColor = lightGrayInactive
        UITabBar.appearance().backgroundColor = darkBlueBackground
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().shadowImage = UIImage()
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().barTintColor = darkBlueBackground
        
        // MARK: - Navigation Bar Configuration
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = darkBlueBackground
        navAppearance.shadowColor = UIColor.clear
        navAppearance.shadowImage = UIImage()
        
        // Navigation bar text styling
        navAppearance.titleTextAttributes = [
            .foregroundColor: primaryText,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: primaryText,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        // Navigation bar button styling
        navAppearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: brightBlueActive]
        navAppearance.doneButtonAppearance.normal.titleTextAttributes = [.foregroundColor: brightBlueActive]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = brightBlueActive
        UINavigationBar.appearance().backgroundColor = darkBlueBackground
        
        
        // MARK: - Additional UIKit Components
        // Table Views
        UITableView.appearance().backgroundColor = darkBlueBackground
        UITableView.appearance().separatorColor = UIColor(red: 0.15, green: 0.17, blue: 0.22, alpha: 1.0)
        UITableViewCell.appearance().backgroundColor = cardBackground
        
        // Collection Views
        UICollectionView.appearance().backgroundColor = darkBlueBackground
        
        // Text Views and Text Fields
        UITextView.appearance().backgroundColor = UIColor(KMTheme.inputBackground)
        UITextView.appearance().textColor = UIColor(KMTheme.inputText)
        UITextField.appearance().backgroundColor = UIColor.clear
        UITextField.appearance().textColor = UIColor(KMTheme.inputText)
        
        // Search Bars
        UISearchBar.appearance().backgroundColor = darkBlueBackground
        UISearchBar.appearance().barTintColor = darkBlueBackground
        UISearchBar.appearance().searchTextField.backgroundColor = UIColor.clear
        UISearchBar.appearance().searchTextField.textColor = primaryText
        
        // Toolbars
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = darkBlueBackground
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance
        
        // Alert Controllers
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).backgroundColor = cardBackground
        
        // Page Control
        UIPageControl.appearance().backgroundColor = UIColor.clear
        UIPageControl.appearance().pageIndicatorTintColor = lightGrayInactive
        UIPageControl.appearance().currentPageIndicatorTintColor = brightBlueActive
        
        print("🎨 [AppDelegate] Configured comprehensive dark theme for all UIKit components")
    }
    
    private func configureStatusBarStyle() {
        // Status bar style is now handled by StatusBarStyleModifier in SwiftUI
        // This ensures proper dark/light content based on the current theme
        print("🎨 [AppDelegate] Status bar style will be handled by StatusBarStyleModifier")
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Push Notification Callbacks
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("🔔 [AppDelegate] Successfully registered for remote notifications")
        print("🔔 [AppDelegate] Device token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        
        // Set APNS token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        // Force FCM token registration now that we have APNS token
        NotificationService.shared.registerFCMTokenAfterAPNS()
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [AppDelegate] Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Remote Notification Handling
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        print("🔔 [AppDelegate] Received remote notification: \(userInfo)")
        
        // Handle the notification
        if let badge = userInfo["badge"] as? Int {
            DispatchQueue.main.async {
                NotificationService.shared.setBadgeCount(badge)
            }
        }
        
        // Let Firebase Messaging handle the notification
        Messaging.messaging().appDidReceiveMessage(userInfo)
        
        return .newData
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 [AppDelegate] FCM token refreshed")
        
        if let token = fcmToken {
            print("🔔 [AppDelegate] New FCM token: \(token.prefix(20))...")
            
            // Update NotificationService
            Task { @MainActor in
                NotificationService.shared.fcmToken = token
                
                // Register token with server
                if let userId = Auth.auth().currentUser?.uid {
                    print("🔔 [AppDelegate] Registering FCM token for user: \(userId)")
                    Task {
                        do {
                            try await FirebaseClient.shared.updateUserFCMToken(userId: userId, fcmToken: token)
                            print("✅ [AppDelegate] FCM token registered successfully")
                        } catch {
                            print("❌ [AppDelegate] Failed to register FCM token: \(error)")
                        }
                    }
                } else {
                    print("⚠️ [AppDelegate] No authenticated user to register FCM token")
                }
            }
        } else {
            print("⚠️ [AppDelegate] FCM token is nil")
        }
    }
}

@main
struct KevinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    
    init() {
        // CRITICAL: Initialize Firebase FIRST before anything else
        FirebaseBootstrap.configure()
        
        // Start network monitoring immediately to diagnose connection issues
        _ = NetworkQualityService.shared
        
        // All UIKit appearance configuration is handled in AppDelegate.configureGlobalTabBarTheme()
        // Removed duplicate configuration to prevent conflicts
        print("🎨 [KevinApp] Skipping duplicate UIKit config - handled in AppDelegate")
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .background(KMTheme.background)
                .background(StatusBarStyleModifier(theme: KMTheme.currentTheme))
        }
    }
}

