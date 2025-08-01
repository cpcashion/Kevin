import SwiftUI
import UIKit
import CoreLocation

struct DebugInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var debugInfo: DebugInfo?
    @State private var isLoading = true
    @State private var showingCopyAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    if isLoading {
                        loadingSection
                    } else if let debugInfo = debugInfo {
                        debugSections(debugInfo)
                    }
                    
                    copyButton
                }
                .padding()
            }
            .background(KMTheme.background)
            .navigationTitle("Debug Information")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(KMTheme.accent)
                }
            }
        }
        .task {
            await loadDebugInfo()
        }
        .alert("Debug Info Copied", isPresented: $showingCopyAlert) {
            Button("OK") { }
        } message: {
            Text("Debug information has been copied to your clipboard. You can paste this when reporting issues.")
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Technical Information")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
            
            Text("This information helps our team diagnose and fix issues. You can copy this information and include it when reporting bugs.")
                .font(.body)
                .foregroundColor(KMTheme.secondaryText)
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: KMTheme.accent))
            
            Text("Collecting debug information...")
                .font(.body)
                .foregroundColor(KMTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func debugSections(_ info: DebugInfo) -> some View {
        VStack(spacing: 20) {
            DebugSection(title: "App Information", items: [
                ("Version", info.appVersion),
                ("Build", info.buildNumber),
                ("Bundle ID", info.bundleIdentifier),
                ("Environment", info.isTestFlight ? "TestFlight" : (info.isDebug ? "Debug" : "Production")),
                ("Session ID", info.sessionId)
            ])
            
            DebugSection(title: "Device Information", items: [
                ("Model", info.deviceModel),
                ("iOS Version", info.iosVersion),
                ("Device ID", info.deviceId),
                ("Battery Level", "\(Int(info.batteryLevel * 100))%"),
                ("Battery State", info.batteryState),
                ("Available Storage", info.availableStorage),
                ("Memory Usage", info.memoryUsage)
            ])
            
            DebugSection(title: "Network Information", items: [
                ("Connection", info.isNetworkConnected ? "Connected" : "Disconnected"),
                ("Connection Type", info.networkType),
                ("API Configuration", info.isOpenAIConfigured ? "Configured" : "Not Configured"),
                ("Google Places", info.isGooglePlacesConfigured ? "Configured" : "Not Configured")
            ])
            
            DebugSection(title: "User Information", items: [
                ("User ID", info.userId ?? "Not signed in"),
                ("Email", info.userEmail ?? "N/A"),
                ("Role", info.userRole ?? "N/A"),
                ("Restaurant", info.restaurantName ?? "None"),
                ("Location Permission", info.locationPermissionStatus)
            ])
            
            if !info.recentErrors.isEmpty {
                DebugSection(title: "Recent Errors", items: info.recentErrors.map { error in
                    (error.timestamp, error.description)
                })
            }
            
            DebugSection(title: "Performance Metrics", items: [
                ("App Launch Time", info.appLaunchTime),
                ("Last AI Analysis", info.lastAIAnalysisTime ?? "Never"),
                ("Total Issues Created", "\(info.totalIssuesCreated)"),
                ("Last Sync", info.lastSyncTime ?? "Never")
            ])
        }
    }
    
    private var copyButton: some View {
        Button(action: copyDebugInfo) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                Text("Copy Debug Information")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(KMTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    private func loadDebugInfo() async {
        // Simulate loading time for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            debugInfo = DebugInfo(appState: appState)
            isLoading = false
        }
    }
    
    private func copyDebugInfo() {
        guard let debugInfo = debugInfo else { return }
        
        let debugText = debugInfo.formattedString()
        UIPasteboard.general.string = debugText
        showingCopyAlert = true
        
        // Log the copy action
        RemoteLoggingService.shared.logUserAction(
            "Debug Info Copied",
            screen: "DebugInfoView",
            userId: appState.currentAppUser?.id
        )
    }
}

struct DebugSection: View {
    let title: String
    let items: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
            
            VStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    DebugInfoRow(label: item.0, value: item.1)
                }
            }
            .padding(16)
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
        }
    }
}

struct DebugInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(KMTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Debug Info Model

struct DebugInfo {
    // App Information
    let appVersion: String
    let buildNumber: String
    let bundleIdentifier: String
    let isTestFlight: Bool
    let isDebug: Bool
    let sessionId: String
    
    // Device Information
    let deviceModel: String
    let iosVersion: String
    let deviceId: String
    let batteryLevel: Float
    let batteryState: String
    let availableStorage: String
    let memoryUsage: String
    
    // Network Information
    let isNetworkConnected: Bool
    let networkType: String
    let isOpenAIConfigured: Bool
    let isGooglePlacesConfigured: Bool
    
    // User Information
    let userId: String?
    let userEmail: String?
    let userRole: String?
    let restaurantName: String?
    let locationPermissionStatus: String
    
    // Error Information
    let recentErrors: [DebugError]
    
    // Performance Metrics
    let appLaunchTime: String
    let lastAIAnalysisTime: String?
    let totalIssuesCreated: Int
    let lastSyncTime: String?
    
    @MainActor
    init(appState: AppState) {
        // App Information
        let bundle = Bundle.main
        self.appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        self.isTestFlight = bundle.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        self.sessionId = SessionManager.shared.sessionId
        
        #if DEBUG
        self.isDebug = true
        #else
        self.isDebug = false
        #endif
        
        // Device Information
        let device = UIDevice.current
        self.deviceModel = device.model
        self.iosVersion = device.systemVersion
        self.deviceId = device.identifierForVendor?.uuidString ?? "unknown"
        
        device.isBatteryMonitoringEnabled = true
        self.batteryLevel = device.batteryLevel
        self.batteryState = device.batteryState.description
        
        self.availableStorage = DebugInfo.getAvailableStorage()
        self.memoryUsage = DebugInfo.getMemoryUsage()
        
        // Network Information
        self.isNetworkConnected = NetworkMonitor.shared.isConnected
        self.networkType = NetworkMonitor.shared.connectionType.rawValue
        self.isOpenAIConfigured = APIKeys.isOpenAIConfigured
        self.isGooglePlacesConfigured = APIKeys.isGooglePlacesConfigured
        
        // User Information (will be set when the view is created)
        self.userId = appState.currentAppUser?.id
        self.userEmail = appState.currentUser?.email
        self.userRole = appState.currentAppUser?.role.rawValue
        self.restaurantName = appState.currentRestaurant?.name
        self.locationPermissionStatus = DebugInfo.getLocationPermissionStatus()
        
        // Error Information (simplified for now)
        self.recentErrors = []
        
        // Performance Metrics (simplified for now)
        self.appLaunchTime = "< 1 second" // Would need to track this properly
        self.lastAIAnalysisTime = nil // Would need to track this
        self.totalIssuesCreated = 0 // Would need to track this
        self.lastSyncTime = nil // Would need to track this
    }
    
    func formattedString() -> String {
        var text = "Kevin Maint Debug Information\n"
        text += "Generated: \(DateFormatter.debugFormatter.string(from: Date()))\n\n"
        
        text += "APP INFORMATION:\n"
        text += "Version: \(appVersion)\n"
        text += "Build: \(buildNumber)\n"
        text += "Bundle ID: \(bundleIdentifier)\n"
        text += "Environment: \(isTestFlight ? "TestFlight" : (isDebug ? "Debug" : "Production"))\n"
        text += "Session ID: \(sessionId)\n\n"
        
        text += "DEVICE INFORMATION:\n"
        text += "Model: \(deviceModel)\n"
        text += "iOS Version: \(iosVersion)\n"
        text += "Device ID: \(deviceId)\n"
        text += "Battery: \(Int(batteryLevel * 100))% (\(batteryState))\n"
        text += "Storage: \(availableStorage)\n"
        text += "Memory: \(memoryUsage)\n\n"
        
        text += "NETWORK INFORMATION:\n"
        text += "Connection: \(isNetworkConnected ? "Connected" : "Disconnected")\n"
        text += "Type: \(networkType)\n"
        text += "OpenAI: \(isOpenAIConfigured ? "Configured" : "Not Configured")\n"
        text += "Google Places: \(isGooglePlacesConfigured ? "Configured" : "Not Configured")\n\n"
        
        text += "USER INFORMATION:\n"
        text += "User ID: \(userId ?? "Not signed in")\n"
        text += "Email: \(userEmail ?? "N/A")\n"
        text += "Role: \(userRole ?? "N/A")\n"
        text += "Restaurant: \(restaurantName ?? "None")\n"
        text += "Location Permission: \(locationPermissionStatus)\n\n"
        
        return text
    }
    
    private static func getAvailableStorage() -> String {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                return ByteCountFormatter.string(fromByteCount: freeSpace.int64Value, countStyle: .file)
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
    
    private static func getLocationPermissionStatus() -> String {
        let status = CLLocationManager().authorizationStatus
        switch status {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always Authorized"
        case .authorizedWhenInUse: return "When In Use"
        @unknown default: return "Unknown"
        }
    }
}

struct DebugError {
    let timestamp: String
    let description: String
}

extension DateFormatter {
    static let debugFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

#Preview {
    DebugInfoView()
}
