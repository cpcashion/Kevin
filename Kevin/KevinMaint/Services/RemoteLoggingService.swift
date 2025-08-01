import Foundation
import Firebase
import UIKit

/// Remote logging service for debugging TestFlight and production issues
class RemoteLoggingService {
    static let shared = RemoteLoggingService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Log an event with context for remote debugging
    func logEvent(
        _ event: String,
        level: LogLevel = .info,
        category: LogCategory = .general,
        details: [String: Any] = [:],
        error: Error? = nil,
        userId: String? = nil
    ) {
        let logEntry = createLogEntry(
            event: event,
            level: level,
            category: category,
            details: details,
            error: error,
            userId: userId
        )
        
        // Log locally for immediate debugging
        printLog(logEntry)
        
        // Send to Firebase for remote debugging
        Task {
            await sendToFirebase(logEntry)
        }
    }
    
    /// Log AI analysis attempts and results
    func logAIAnalysis(
        event: AIAnalysisEvent,
        imageSize: CGSize? = nil,
        imageSizeBytes: Int? = nil,
        apiResponse: String? = nil,
        error: Error? = nil,
        duration: TimeInterval? = nil,
        userId: String? = nil
    ) {
        var details: [String: Any] = [
            "ai_event": event.rawValue
        ]
        
        if let imageSize = imageSize {
            details["image_width"] = imageSize.width
            details["image_height"] = imageSize.height
        }
        
        if let imageSizeBytes = imageSizeBytes {
            details["image_size_bytes"] = imageSizeBytes
        }
        
        if let apiResponse = apiResponse {
            details["api_response_preview"] = String(apiResponse.prefix(200))
        }
        
        if let duration = duration {
            details["duration_seconds"] = duration
        }
        
        logEvent(
            "AI Analysis: \(event.rawValue)",
            level: error != nil ? .error : .info,
            category: .aiAnalysis,
            details: details,
            error: error,
            userId: userId
        )
    }
    
    /// Log user actions for debugging UX issues
    func logUserAction(
        _ action: String,
        screen: String,
        details: [String: Any] = [:],
        userId: String? = nil
    ) {
        var actionDetails = details
        actionDetails["screen"] = screen
        
        logEvent(
            "User Action: \(action)",
            level: .info,
            category: .userAction,
            details: actionDetails,
            userId: userId
        )
    }
    
    /// Log network requests and responses
    func logNetworkRequest(
        url: String,
        method: String,
        statusCode: Int? = nil,
        responseTime: TimeInterval? = nil,
        error: Error? = nil,
        userId: String? = nil
    ) {
        var details: [String: Any] = [
            "url": url,
            "method": method
        ]
        
        if let statusCode = statusCode {
            details["status_code"] = statusCode
        }
        
        if let responseTime = responseTime {
            details["response_time_ms"] = responseTime * 1000
        }
        
        logEvent(
            "Network Request: \(method) \(url)",
            level: error != nil ? .error : .info,
            category: .network,
            details: details,
            error: error,
            userId: userId
        )
    }
    
    private func createLogEntry(
        event: String,
        level: LogLevel,
        category: LogCategory,
        details: [String: Any],
        error: Error?,
        userId: String?
    ) -> LogEntry {
        var allDetails = details
        
        // Add device context
        allDetails["device_model"] = UIDevice.current.model
        allDetails["ios_version"] = UIDevice.current.systemVersion
        allDetails["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        allDetails["build_number"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        
        // Add network info
        allDetails["network_reachable"] = NetworkMonitor.shared.isConnected
        allDetails["network_type"] = NetworkMonitor.shared.connectionType.rawValue
        
        // Add error details if present
        if let error = error {
            allDetails["error_description"] = error.localizedDescription
            allDetails["error_domain"] = (error as NSError).domain
            allDetails["error_code"] = (error as NSError).code
        }
        
        return LogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            event: event,
            level: level,
            category: category,
            details: allDetails,
            userId: userId ?? "anonymous",
            sessionId: SessionManager.shared.sessionId
        )
    }
    
    private func printLog(_ entry: LogEntry) {
        let emoji = entry.level.emoji
        let timestamp = DateFormatter.logFormatter.string(from: entry.timestamp)
        
        print("\(emoji) [\(timestamp)] [\(entry.category.rawValue.uppercased())] \(entry.event)")
        
        if !entry.details.isEmpty {
            print("   Details: \(entry.details)")
        }
    }
    
    private func sendToFirebase(_ entry: LogEntry) async {
        do {
            let data = try entry.toDictionary()
            try await db.collection("debug_logs").document(entry.id).setData(data)
        } catch {
            print("❌ Failed to send log to Firebase: \(error)")
        }
    }
}

// MARK: - Models

struct LogEntry {
    let id: String
    let timestamp: Date
    let event: String
    let level: LogLevel
    let category: LogCategory
    let details: [String: Any]
    let userId: String
    let sessionId: String
    
    func toDictionary() throws -> [String: Any] {
        return [
            "id": id,
            "timestamp": Timestamp(date: timestamp),
            "event": event,
            "level": level.rawValue,
            "category": category.rawValue,
            "details": details,
            "userId": userId,
            "sessionId": sessionId
        ]
    }
}

enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

enum LogCategory: String, CaseIterable {
    case general = "general"
    case aiAnalysis = "ai_analysis"
    case userAction = "user_action"
    case network = "network"
    case authentication = "auth"
    case firebase = "firebase"
    case location = "location"
    case camera = "camera"
    case performance = "performance"
}

enum AIAnalysisEvent: String, CaseIterable {
    case started = "started"
    case imageProcessed = "image_processed"
    case apiRequestSent = "api_request_sent"
    case apiResponseReceived = "api_response_received"
    case parsingStarted = "parsing_started"
    case parsingCompleted = "parsing_completed"
    case completed = "completed"
    case failed = "failed"
}

// MARK: - Supporting Services

class SessionManager {
    static let shared = SessionManager()
    let sessionId = UUID().uuidString
    
    private init() {}
}

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .wifi
    
    private init() {
        // Initialize network monitoring
        // This is a simplified version - you might want to use Network framework
    }
    
    enum ConnectionType: String {
        case wifi = "wifi"
        case cellular = "cellular"
        case none = "none"
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
