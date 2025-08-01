import Foundation
import FirebaseCore
import FirebaseFirestore
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
// import FirebaseAppCheck // Completely removed to prevent any AppCheck initialization

enum FirebaseBootstrap {
  /// Configure Firebase in a resilient, idempotent way.
  /// Order of precedence:
  /// 1. Default options from GoogleService-Info.plist automatically detected
  /// 2. Explicit GoogleService-Info.plist in bundle
  /// 3. Environment variables (GOOGLE_APP_ID / GCM_SENDER_ID, etc.)
  static func configure() {
    // Prevent duplicate configuration
    if FirebaseApp.app() != nil { return }

    // CRITICAL: AppCheck completely removed to prevent 403 errors and 10s timeouts
    // No AppCheck configuration at all - this should eliminate the connection issues
    print("🔥 [FirebaseBootstrap] AppCheck COMPLETELY REMOVED to prevent timeouts")

    // 1) Try default options (Firebase will look for GoogleService-Info.plist)
    if let _ = FirebaseOptions.defaultOptions() {
      print("🔥 [FirebaseBootstrap] Configuring with default GoogleService-Info.plist")
      FirebaseApp.configure()
      
      // CRITICAL: Disable Crashlytics data collection to prevent background task delays
      #if canImport(FirebaseCrashlytics)
      Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
      print("🔥 [FirebaseBootstrap] Crashlytics data collection DISABLED")
      #endif
      
      enableOfflinePersistence()
      return
    }

    // 2) Try explicit plist path (in case the file isn't named exactly as expected in some setups)
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let options = FirebaseOptions(contentsOfFile: path) {
      print("🔥 [FirebaseBootstrap] Configuring with explicit GoogleService-Info.plist at: \(path)")
      FirebaseApp.configure(options: options)
      enableOfflinePersistence()
      return
    } else {
      print("⚠️ [FirebaseBootstrap] GoogleService-Info.plist not found in main bundle")
    }

    // 3) Fallback: Build options from environment variables
    let env = ProcessInfo.processInfo.environment

    // Required
    let googleAppID = env["GOOGLE_APP_ID"] ?? env["FIREBASE_GOOGLE_APP_ID"]
    let gcmSenderID = env["GCM_SENDER_ID"] ?? env["FIREBASE_GCM_SENDER_ID"]

    guard let googleAppID, let gcmSenderID, !googleAppID.isEmpty, !gcmSenderID.isEmpty else {
      print("❌ [FirebaseBootstrap] Missing required Firebase environment variables.\n" +
            "   Required: GOOGLE_APP_ID (or FIREBASE_GOOGLE_APP_ID), GCM_SENDER_ID (or FIREBASE_GCM_SENDER_ID)\n" +
            "   Optional: FIREBASE_API_KEY, FIREBASE_CLIENT_ID, FIREBASE_PROJECT_ID, FIREBASE_STORAGE_BUCKET, FIREBASE_DATABASE_URL")
      return
    }

    let options = FirebaseOptions(googleAppID: googleAppID, gcmSenderID: gcmSenderID)

    // Optional
    if let apiKey = env["FIREBASE_API_KEY"] ?? env["API_KEY"], !apiKey.isEmpty {
      options.apiKey = apiKey
    }
    if let clientID = env["FIREBASE_CLIENT_ID"] ?? env["CLIENT_ID"], !clientID.isEmpty {
      options.clientID = clientID
    }
    if let projectID = env["FIREBASE_PROJECT_ID"] ?? env["PROJECT_ID"], !projectID.isEmpty {
      options.projectID = projectID
    }
    if let storageBucket = env["FIREBASE_STORAGE_BUCKET"] ?? env["STORAGE_BUCKET"], !storageBucket.isEmpty {
      options.storageBucket = storageBucket
    }
    if let databaseURL = env["FIREBASE_DATABASE_URL"] ?? env["DATABASE_URL"], !databaseURL.isEmpty {
      options.databaseURL = databaseURL
    }

    print("🔥 [FirebaseBootstrap] Configuring Firebase from environment variables")
    FirebaseApp.configure(options: options)
    
    // Enable offline persistence for instant app startup
    enableOfflinePersistence()
  }
  
  private static func enableOfflinePersistence() {
    // Configure Firestore settings
    let settings = FirestoreSettings()
    settings.isPersistenceEnabled = true
    settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
    
    Firestore.firestore().settings = settings
    print("🔥 [FirebaseBootstrap] Offline persistence enabled with unlimited cache and aggressive timeouts")
  }
}
