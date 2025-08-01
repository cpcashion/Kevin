import Foundation
import Network
import SystemConfiguration

class NetworkQualityService {
    static let shared = NetworkQualityService()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.logNetworkStatus(path: path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func logNetworkStatus(path: NWPath) {
        print("🌐 [NetworkQuality] Status: \(path.status)")
        print("🌐 [NetworkQuality] Is expensive: \(path.isExpensive)")
        print("🌐 [NetworkQuality] Is constrained: \(path.isConstrained)")
        
        if path.usesInterfaceType(.wifi) {
            print("🌐 [NetworkQuality] Connection: WiFi")
        } else if path.usesInterfaceType(.cellular) {
            print("🌐 [NetworkQuality] Connection: Cellular")
        } else if path.usesInterfaceType(.wiredEthernet) {
            print("🌐 [NetworkQuality] Connection: Ethernet")
        } else {
            print("🌐 [NetworkQuality] Connection: Unknown")
        }
        
        // Test connection speed
        testConnectionSpeed()
    }
    
    private func testConnectionSpeed() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simple ping test to Google DNS
        let url = URL(string: "https://8.8.8.8")!
        let task = URLSession.shared.dataTask(with: url) { _, _, error in
            let endTime = CFAbsoluteTimeGetCurrent()
            let latency = (endTime - startTime) * 1000 // Convert to milliseconds
            
            DispatchQueue.main.async {
                if error != nil {
                    print("🌐 [NetworkQuality] Ping failed: \(error?.localizedDescription ?? "Unknown error")")
                } else {
                    print("🌐 [NetworkQuality] Ping latency: \(String(format: "%.0f", latency))ms")
                    
                    if latency > 1000 {
                        print("🚨 [NetworkQuality] SLOW NETWORK DETECTED - This explains the Firebase delays!")
                    } else if latency > 500 {
                        print("⚠️ [NetworkQuality] Moderate network latency detected")
                    } else {
                        print("✅ [NetworkQuality] Good network connection")
                    }
                }
            }
        }
        task.resume()
    }
}
