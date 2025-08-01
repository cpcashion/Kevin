import Foundation
#if canImport(FirebasePerformance)
import FirebasePerformance
#endif
import os.signpost
import UIKit

/// Performance monitoring service for tracking app performance
class PerformanceMonitoringService {
    static let shared = PerformanceMonitoringService()
    
    private let performanceLog = OSLog(subsystem: "com.kevinmaint.app", category: .pointsOfInterest)
    #if canImport(FirebasePerformance)
    private var activeTraces: [String: Trace?] = [:]
    #endif
    private var activeSignposts: [String: OSSignpostID] = [:]
    
    private init() {}
    
    /// Start tracking a performance trace
    func startTrace(_ name: String, attributes: [String: String] = [:]) {
        #if canImport(FirebasePerformance)
        // Firebase Performance
        let trace = Performance.startTrace(name: name)
        for (key, value) in attributes {
            trace?.setValue(value, forAttribute: key)
        }
        activeTraces[name] = trace
        #endif
        
        // OS Signpost for Instruments
        let signpostID = OSSignpostID(log: performanceLog)
        activeSignposts[name] = signpostID
        
        // Use string literal for StaticString
        if #available(iOS 12.0, *) {
            os_signpost(.begin, log: performanceLog, name: "Performance Trace", signpostID: signpostID, "%{public}s", name)
        }
        
        print("🚀 Started trace: \(name)")
    }
    
    /// Stop tracking a performance trace
    func stopTrace(_ name: String, success: Bool = true, additionalMetrics: [String: NSNumber] = [:]) {
        #if canImport(FirebasePerformance)
        // Firebase Performance
        if let trace = activeTraces[name], let unwrappedTrace = trace {
            // Add custom metrics
            for (key, value) in additionalMetrics {
                unwrappedTrace.setValue(value.int64Value, forMetric: key)
            }
            
            // Add success/failure attribute
            unwrappedTrace.setValue(success ? "success" : "failure", forAttribute: "result")
            
            unwrappedTrace.stop()
            activeTraces.removeValue(forKey: name)
        }
        #endif
        
        // OS Signpost
        if let signpostID = activeSignposts[name] {
            if #available(iOS 12.0, *) {
                os_signpost(.end, log: performanceLog, name: "Performance Trace", signpostID: signpostID, "%{public}s", name)
            }
            activeSignposts.removeValue(forKey: name)
        }
        
        print("🏁 Stopped trace: \(name) (success: \(success))")
    }
    
    /// Track app launch performance
    func trackAppLaunch() {
        startTrace("app_launch", attributes: [
            "device_model": UIDevice.current.model,
            "ios_version": UIDevice.current.systemVersion
        ])
    }
    
    /// Complete app launch tracking
    func completeAppLaunch(success: Bool = true) {
        stopTrace("app_launch", success: success)
    }
    
    /// Track AI analysis performance
    func trackAIAnalysis(imageSize: CGSize? = nil, imageSizeBytes: Int? = nil) {
        var attributes: [String: String] = [:]
        
        if let imageSize = imageSize {
            attributes["image_width"] = String(Int(imageSize.width))
            attributes["image_height"] = String(Int(imageSize.height))
        }
        
        if let imageSizeBytes = imageSizeBytes {
            attributes["image_size_kb"] = String(imageSizeBytes / 1024)
        }
        
        startTrace("ai_analysis", attributes: attributes)
    }
    
    /// Complete AI analysis tracking
    func completeAIAnalysis(success: Bool, duration: TimeInterval? = nil, confidence: Double? = nil) {
        var metrics: [String: NSNumber] = [:]
        
        if let duration = duration {
            metrics["duration_ms"] = NSNumber(value: duration * 1000)
        }
        
        if let confidence = confidence {
            metrics["confidence_percent"] = NSNumber(value: confidence * 100)
        }
        
        stopTrace("ai_analysis", success: success, additionalMetrics: metrics)
    }
    
    /// Track screen load performance
    func trackScreenLoad(_ screenName: String) {
        startTrace("screen_load", attributes: ["screen_name": screenName])
    }
    
    /// Complete screen load tracking
    func completeScreenLoad(_ screenName: String, success: Bool = true) {
        stopTrace("screen_load", success: success)
    }
    
    /// Track network request performance
    func trackNetworkRequest(url: String, method: String) -> String {
        let traceName = "network_request_\(UUID().uuidString.prefix(8))"
        startTrace(traceName, attributes: [
            "url": url,
            "method": method
        ])
        return traceName
    }
    
    /// Complete network request tracking
    func completeNetworkRequest(_ traceName: String, statusCode: Int, responseSize: Int? = nil) {
        var metrics: [String: NSNumber] = [
            "status_code": NSNumber(value: statusCode)
        ]
        
        if let responseSize = responseSize {
            metrics["response_size_bytes"] = NSNumber(value: responseSize)
        }
        
        let success = (200...299).contains(statusCode)
        stopTrace(traceName, success: success, additionalMetrics: metrics)
    }
    
    /// Track memory usage
    func trackMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        
        #if canImport(FirebasePerformance)
        // Log to Firebase Performance as a custom metric
        if let trace = Performance.startTrace(name: "memory_usage") {
            trace.setValue(Int64(memoryUsage / 1024 / 1024), forMetric: "memory_mb")
            trace.stop()
        }
        #endif
        
        print("📊 Memory usage: \(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory))")
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
}

// MARK: - Memory Usage Helper

import Darwin
