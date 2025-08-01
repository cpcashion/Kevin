import Foundation
import FirebaseFirestore

// MARK: - User Lookup Service
// Provides user display names for timeline transparency

actor UserCache {
    private var cache: [String: String] = [:]
    
    func get(_ key: String) -> String? {
        return cache[key]
    }
    
    func set(_ key: String, value: String) {
        cache[key] = value
    }
}

class UserLookupService {
    static let shared = UserLookupService()
    
    private let db = Firestore.firestore()
    private let userCache = UserCache() // Thread-safe cache using actor
    
    private init() {}
    
    /// Get a display name for a user ID, fetching from Firestore if needed
    func getUserDisplayName(for userId: String, currentUser: AppUser? = nil) async -> String {
        // First check if it's the current user
        if let currentUser = currentUser, currentUser.id == userId {
            return currentUser.name.isEmpty ? 
                (currentUser.email?.components(separatedBy: "@").first?.capitalized ?? "You") : 
                currentUser.name
        }
        
        // Check cache first (thread-safe)
        if let cachedName = await userCache.get(userId) {
            print("👤 [UserLookup] Using cached name for \(userId): \(cachedName)")
            return cachedName
        }
        
        // Fetch from Firestore
        print("👤 [UserLookup] Fetching user name from Firestore for: \(userId)")
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            if let data = doc.data() {
                // Try to get name first
                if let name = data["name"] as? String, !name.isEmpty {
                    print("👤 [UserLookup] Found user name: \(name)")
                    await userCache.set(userId, value: name)
                    return name
                }
                // Fall back to email if name is empty
                if let email = data["email"] as? String {
                    let name = email.components(separatedBy: "@").first?.capitalized ?? "User"
                    print("👤 [UserLookup] Using email-based name: \(name)")
                    await userCache.set(userId, value: name)
                    return name
                }
            }
        } catch {
            print("❌ [UserLookup] Error fetching user: \(error)")
        }
        
        // Fallback to generic name
        let fallbackName = getGenericDisplayName(for: userId)
        print("👤 [UserLookup] Using fallback name: \(fallbackName)")
        return fallbackName
    }
    
    /// Synchronous version for compatibility (uses fallback and triggers async fetch)
    /// ⚠️ This returns a generic name immediately and fetches the real name in the background
    func getUserDisplayName(for userId: String, currentUser: AppUser? = nil) -> String {
        // First check if it's the current user
        if let currentUser = currentUser, currentUser.id == userId {
            return currentUser.name.isEmpty ? 
                (currentUser.email?.components(separatedBy: "@").first?.capitalized ?? "You") : 
                currentUser.name
        }
        
        // Return generic name immediately and trigger async fetch in background
        // This prevents crashes from concurrent cache access
        Task {
            _ = await getUserDisplayName(for: userId, currentUser: currentUser)
        }
        
        return getGenericDisplayName(for: userId)
    }
    
    /// Get a generic display name based on user ID patterns
    private func getGenericDisplayName(for userId: String) -> String {
        // Try to extract name from email-like patterns
        if userId.contains("@") {
            return userId.components(separatedBy: "@").first?.capitalized ?? "Unknown User"
        } 
        // Long ID, probably Firebase UID - show generic name based on context
        else if userId.count > 10 {
            return "Kevin Team"
        } 
        // Short ID or other pattern
        else {
            return "Unknown User"
        }
    }
    
    /// Get reporter name with proper attribution
    func getReporterName(for issue: Issue, currentUser: AppUser? = nil) -> String {
        return getUserDisplayName(for: issue.reporterId, currentUser: currentUser)
    }
    
    /// Get work log author name with proper attribution
    func getWorkLogAuthorName(for workLog: WorkLog, currentUser: AppUser? = nil) -> String {
        return getUserDisplayName(for: workLog.authorId, currentUser: currentUser)
    }
}

// MARK: - Timeline Attribution Extensions
// Extensions to provide user attribution for timeline events

extension UserLookupService {
    
    /// Generate timeline subtitle with user attribution for status changes
    func getTimelineSubtitle(for status: IssueStatus, workLogs: [WorkLog], currentUser: AppUser? = nil) -> String {
        switch status {
        case .in_progress:
            if let recentLog = workLogs.filter({ $0.message.lowercased().contains("progress") || $0.message.lowercased().contains("working") }).last {
                let authorName = getWorkLogAuthorName(for: recentLog, currentUser: currentUser)
                return "\(authorName): \(recentLog.message.prefix(50))..."
            }
            if let firstLog = workLogs.first {
                let authorName = getWorkLogAuthorName(for: firstLog, currentUser: currentUser)
                return "\(authorName): \(firstLog.message.prefix(50))..."
            }
            // Try to find who changed the status by looking for status change work logs
            if let statusLog = workLogs.filter({ $0.message.lowercased().contains("in progress") || $0.message.lowercased().contains("status updated") }).last {
                let authorName = getWorkLogAuthorName(for: statusLog, currentUser: currentUser)
                return "\(authorName) started working on this issue"
            }
            return "Kevin Team started reviewing issue details"
            
        case .completed:
            if let completionLog = workLogs.filter({ $0.message.lowercased().contains("completed") || $0.message.lowercased().contains("done") }).last {
                let authorName = getWorkLogAuthorName(for: completionLog, currentUser: currentUser)
                return "\(authorName): \(completionLog.message.prefix(50))..."
            }
            // Try to find who marked it as completed
            if let statusLog = workLogs.filter({ $0.message.lowercased().contains("completed") || $0.message.lowercased().contains("status updated") }).last {
                let authorName = getWorkLogAuthorName(for: statusLog, currentUser: currentUser)
                return "\(authorName) marked this issue as completed"
            }
            return "Work completed successfully"
            
        default:
            return "Status updated"
        }
    }
}
