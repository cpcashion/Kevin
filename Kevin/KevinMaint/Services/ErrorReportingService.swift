import Foundation
import UIKit
import Firebase

/// Service for collecting and reporting errors with user feedback
class ErrorReportingService {
    static let shared = ErrorReportingService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Report an error with optional user feedback
    func reportError(
        _ error: Error,
        context: String,
        userFeedback: String? = nil,
        userId: String? = nil,
        additionalData: [String: Any] = [:]
    ) {
        let errorReport = ErrorReport(
            error: error,
            context: context,
            userFeedback: userFeedback,
            userId: userId ?? "anonymous",
            additionalData: additionalData
        )
        
        // Log locally
        print("🚨 ERROR REPORT: \(context)")
        print("   Error: \(error.localizedDescription)")
        if let feedback = userFeedback {
            print("   User Feedback: \(feedback)")
        }
        
        // Send to Firebase
        Task {
            await sendErrorReport(errorReport)
        }
        
        // Also log to remote logging
        RemoteLoggingService.shared.logEvent(
            "Error Report: \(context)",
            level: .error,
            category: .general,
            details: additionalData,
            error: error,
            userId: userId
        )
    }
    
    /// Report AI analysis failure with detailed context
    func reportAIAnalysisFailure(
        error: Error,
        imageSize: CGSize? = nil,
        imageSizeBytes: Int? = nil,
        apiResponse: String? = nil,
        userFeedback: String? = nil,
        userId: String? = nil
    ) {
        var additionalData: [String: Any] = [:]
        
        if let imageSize = imageSize {
            additionalData["image_width"] = imageSize.width
            additionalData["image_height"] = imageSize.height
        }
        
        if let imageSizeBytes = imageSizeBytes {
            additionalData["image_size_bytes"] = imageSizeBytes
        }
        
        if let apiResponse = apiResponse {
            additionalData["api_response"] = String(apiResponse.prefix(500))
        }
        
        // Check API key status
        additionalData["api_key_configured"] = APIKeys.isOpenAIConfigured
        additionalData["api_key_length"] = APIKeys.openAIAPIKey.count
        additionalData["api_key_prefix"] = String(APIKeys.openAIAPIKey.prefix(10))
        
        reportError(
            error,
            context: "AI Analysis Failure",
            userFeedback: userFeedback,
            userId: userId,
            additionalData: additionalData
        )
    }
    
    private func sendErrorReport(_ report: ErrorReport) async {
        do {
            let data = try report.toDictionary()
            try await db.collection("error_reports").document(report.id).setData(data)
            print("✅ Error report sent to Firebase")
        } catch {
            print("❌ Failed to send error report: \(error)")
        }
    }
}

// MARK: - Models

struct ErrorReport {
    let id: String
    let timestamp: Date
    let error: Error
    let context: String
    let userFeedback: String?
    let userId: String
    let additionalData: [String: Any]
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo
    
    init(
        error: Error,
        context: String,
        userFeedback: String?,
        userId: String,
        additionalData: [String: Any]
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.error = error
        self.context = context
        self.userFeedback = userFeedback
        self.userId = userId
        self.additionalData = additionalData
        self.deviceInfo = DeviceInfo()
        self.appInfo = AppInfo()
    }
    
    func toDictionary() throws -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "timestamp": Timestamp(date: timestamp),
            "context": context,
            "userId": userId,
            "error_description": error.localizedDescription,
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "device_info": deviceInfo.toDictionary(),
            "app_info": appInfo.toDictionary(),
            "additional_data": additionalData
        ]
        
        if let userFeedback = userFeedback {
            data["user_feedback"] = userFeedback
        }
        
        return data
    }
}

struct DeviceInfo {
    let model: String
    let systemName: String
    let systemVersion: String
    let identifierForVendor: String?
    let batteryLevel: Float
    let batteryState: String
    let diskSpace: String
    let memoryUsage: String
    
    init() {
        let device = UIDevice.current
        self.model = device.model
        self.systemName = device.systemName
        self.systemVersion = device.systemVersion
        self.identifierForVendor = device.identifierForVendor?.uuidString
        
        device.isBatteryMonitoringEnabled = true
        self.batteryLevel = device.batteryLevel
        self.batteryState = device.batteryState.description
        
        self.diskSpace = DeviceInfo.getDiskSpace()
        self.memoryUsage = DeviceInfo.getMemoryUsage()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "model": model,
            "system_name": systemName,
            "system_version": systemVersion,
            "identifier_for_vendor": identifierForVendor ?? "unknown",
            "battery_level": batteryLevel,
            "battery_state": batteryState,
            "disk_space": diskSpace,
            "memory_usage": memoryUsage
        ]
    }
    
    private static func getDiskSpace() -> String {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber
            let totalSpace = systemAttributes[.systemSize] as? NSNumber
            
            if let free = freeSpace, let total = totalSpace {
                return "Free: \(ByteCountFormatter.string(fromByteCount: free.int64Value, countStyle: .file)) / Total: \(ByteCountFormatter.string(fromByteCount: total.int64Value, countStyle: .file))"
            }
        } catch {
            return "Unknown"
        }
        return "Unknown"
    }
    
    private static func getMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = info.resident_size
            return ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory)
        }
        
        return "Unknown"
    }
}

struct AppInfo {
    let version: String
    let buildNumber: String
    let bundleIdentifier: String
    let isTestFlight: Bool
    let isDebug: Bool
    
    init() {
        let bundle = Bundle.main
        self.version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        
        // Detect TestFlight
        self.isTestFlight = bundle.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        
        // Detect debug build
        #if DEBUG
        self.isDebug = true
        #else
        self.isDebug = false
        #endif
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "version": version,
            "build_number": buildNumber,
            "bundle_identifier": bundleIdentifier,
            "is_testflight": isTestFlight,
            "is_debug": isDebug
        ]
    }
}

extension UIDevice.BatteryState {
    var description: String {
        switch self {
        case .unknown: return "unknown"
        case .unplugged: return "unplugged"
        case .charging: return "charging"
        case .full: return "full"
        @unknown default: return "unknown"
        }
    }
}
