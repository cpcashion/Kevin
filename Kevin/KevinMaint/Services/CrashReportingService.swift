import Foundation
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
import UIKit

/// Crash reporting and non-fatal error tracking service
class CrashReportingService {
    static let shared = CrashReportingService()
    
    private init() {}
    
    /// Configure crash reporting on app launch
    func configure() {
        // DISABLED: Crashlytics causing 30+ second background task delays
        // Will re-enable when network performance improves
        print("⚠️ Crashlytics DISABLED for performance")
    }
    
    /// Set user ID for crash reports
    func setUserId(_ userId: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(userId)
        #endif
        setCustomValue(userId, forKey: "user_id")
    }
    
    /// Set custom key-value pairs for crash context
    func setCustomValue(_ value: Any, forKey key: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #else
        print("📝 Custom value: \(key) = \(value)")
        #endif
    }
    
    /// Log a breadcrumb for crash context
    func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #else
        print("🍞 Breadcrumb: \(message)")
        #endif
    }
    
    /// Record a non-fatal error
    func recordError(_ error: Error, userInfo: [String: Any] = [:]) {
        var allUserInfo = userInfo
        allUserInfo["timestamp"] = Date().timeIntervalSince1970
        allUserInfo["session_id"] = SessionManager.shared.sessionId
        
        #if canImport(FirebaseCrashlytics)
        // Add to Crashlytics
        Crashlytics.crashlytics().record(error: error, userInfo: allUserInfo)
        #endif
        
        // Also log locally
        print("🚨 Non-fatal error recorded: \(error.localizedDescription)")
        if !userInfo.isEmpty {
            print("   Context: \(userInfo)")
        }
    }
    
    /// Record AI analysis failures specifically
    func recordAIAnalysisError(
        _ error: Error,
        imageSize: CGSize? = nil,
        imageSizeBytes: Int? = nil,
        apiResponse: String? = nil
    ) {
        var userInfo: [String: Any] = [
            "error_type": "ai_analysis_failure",
            "api_configured": APIKeys.isOpenAIConfigured
        ]
        
        if let imageSize = imageSize {
            userInfo["image_width"] = imageSize.width
            userInfo["image_height"] = imageSize.height
        }
        
        if let imageSizeBytes = imageSizeBytes {
            userInfo["image_size_bytes"] = imageSizeBytes
        }
        
        if let apiResponse = apiResponse {
            userInfo["api_response_preview"] = String(apiResponse.prefix(200))
        }
        
        recordError(error, userInfo: userInfo)
    }
    
    /// Record network failures
    func recordNetworkError(
        _ error: Error,
        url: String,
        method: String,
        statusCode: Int? = nil
    ) {
        var userInfo: [String: Any] = [
            "error_type": "network_failure",
            "url": url,
            "method": method
        ]
        
        if let statusCode = statusCode {
            userInfo["status_code"] = statusCode
        }
        
        recordError(error, userInfo: userInfo)
    }
    
    /// Force a crash for testing (DEBUG only)
    #if DEBUG
    func testCrash() {
        #if canImport(FirebaseCrashlytics)
        fatalError("Test crash triggered")
        #else
        print("🧪 Test crash would be triggered (Crashlytics not available)")
        #endif
    }
    #endif
}

// MARK: - Integration Helpers

extension CrashReportingService {
    /// Track screen views for crash context
    func trackScreenView(_ screenName: String) {
        log("Screen: \(screenName)")
        setCustomValue(screenName, forKey: "current_screen")
    }
    
    /// Track user actions for crash context
    func trackUserAction(_ action: String, screen: String) {
        log("Action: \(action) on \(screen)")
        setCustomValue(action, forKey: "last_user_action")
        setCustomValue(screen, forKey: "last_action_screen")
    }
    
    /// Track app state changes
    func trackAppState(_ state: String) {
        log("App State: \(state)")
        setCustomValue(state, forKey: "app_state")
    }
}
