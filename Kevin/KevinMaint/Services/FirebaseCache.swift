import Foundation

final class FirebaseCache {
    static let shared = FirebaseCache()
    
    private var issuesCache: [Issue]?
    private var issuesCacheTime: Date?
    private let cacheTimeout: TimeInterval = 30 // 30 seconds
    
    private init() {}
    
    func getCachedIssues() -> [Issue]? {
        guard let cache = issuesCache,
              let cacheTime = issuesCacheTime,
              Date().timeIntervalSince(cacheTime) < cacheTimeout else {
            print("🗄️ [FirebaseCache] Issues cache miss or expired")
            return nil
        }
        
        print("🗄️ [FirebaseCache] Issues cache hit - returning \(cache.count) cached issues")
        print("🕒 [FirebaseCache] Cache age: \(Date().timeIntervalSince(cacheTime))s (timeout: \(cacheTimeout)s)")
        return cache
    }
    
    func cacheIssues(_ issues: [Issue]) {
        issuesCache = issues
        issuesCacheTime = Date()
        print("🗄️ [FirebaseCache] Cached \(issues.count) issues")
    }
    
    func invalidateIssuesCache() {
        issuesCache = nil
        issuesCacheTime = nil
        print("🗄️ [FirebaseCache] Issues cache invalidated")
    }
    
    func clearAllCache() {
        issuesCache = nil
        issuesCacheTime = nil
        print("🗄️ [FirebaseCache] All cache cleared")
    }
}
