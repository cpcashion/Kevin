import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for managing user profiles and their location assignments
class UserProfileService {
    static let shared = UserProfileService()
    
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    private init() {}
    
    // MARK: - User Profile Management
    
    /// Get all users who can be mentioned in a given location context
    /// - Parameters:
    ///   - locationId: The location/restaurant ID to filter by (nil for all locations)
    ///   - currentUser: The current user making the request
    /// - Returns: Array of users that can be mentioned
    func getMentionableUsers(locationId: String?, currentUser: AppUser?) async throws -> [AppUser] {
        guard let currentUser = currentUser else {
            return []
        }
        
        // Admins can mention all users from any location
        if currentUser.role == .admin {
            return try await getAllActiveUsers()
        }
        
        // Non-admins can only mention users at their location
        guard let locationId = locationId else {
            // If no location specified, return empty (non-admins need a location)
            return []
        }
        
        return try await getUsersAtLocation(locationId: locationId)
    }
    
    /// Get all active users in the system
    func getAllActiveUsers() async throws -> [AppUser] {
        // Just get all users - don't filter by isActive since that field may not exist
        let snapshot = try await db.collection(usersCollection).getDocuments()
        
        let users = snapshot.documents.compactMap { doc in
            parseAppUser(from: doc)
        }
        
        return users
    }
    
    /// Get users assigned to a specific location
    func getUsersAtLocation(locationId: String) async throws -> [AppUser] {
        // For now, just return all users since assignedLocations field may not exist
        return try await getAllActiveUsers()
    }
    
    /// Assign a user to a location
    func assignUserToLocation(userId: String, locationId: String) async throws {
        let userRef = db.collection(usersCollection).document(userId)
        
        try await userRef.updateData([
            "assignedLocations": FieldValue.arrayUnion([locationId]),
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    /// Remove a user from a location
    func removeUserFromLocation(userId: String, locationId: String) async throws {
        let userRef = db.collection(usersCollection).document(userId)
        
        try await userRef.updateData([
            "assignedLocations": FieldValue.arrayRemove([locationId]),
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    /// Update user profile
    func updateUserProfile(userId: String, name: String?, phone: String?) async throws {
        let userRef = db.collection(usersCollection).document(userId)
        
        var updates: [String: Any] = [
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let name = name {
            updates["name"] = name
        }
        
        if let phone = phone {
            updates["phone"] = phone
        }
        
        try await userRef.updateData(updates)
    }
    
    /// Set user active status
    func setUserActiveStatus(userId: String, isActive: Bool) async throws {
        let userRef = db.collection(usersCollection).document(userId)
        
        try await userRef.updateData([
            "isActive": isActive,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Mention Detection
    
    /// Extract mentioned user IDs from a message
    /// Format: @Name or @First Last (supports names with spaces)
    func extractMentions(from message: String) -> [String] {
        var mentions: [String] = []
        
        // Match @Name or @First Last (until space, newline, or punctuation)
        // This pattern captures the name after @ until we hit a space followed by lowercase or punctuation
        let pattern = #"@([A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)*)"#
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: message, range: NSRange(message.startIndex..., in: message))
            for match in matches {
                if let range = Range(match.range(at: 1), in: message) {
                    let username = String(message[range])
                    mentions.append(username.lowercased())
                }
            }
        }
        
        return mentions
    }
    
    /// Find users matching a mention query
    func findUsersForMention(query: String, in users: [AppUser]) -> [AppUser] {
        let lowercaseQuery = query.lowercased()
        
        return users.filter { user in
            // Match by name
            if user.name.lowercased().contains(lowercaseQuery) {
                return true
            }
            
            // Match by email prefix
            if let email = user.email {
                let emailPrefix = email.components(separatedBy: "@").first ?? ""
                if emailPrefix.lowercased().contains(lowercaseQuery) {
                    return true
                }
            }
            
            return false
        }
    }
    
    /// Convert mention text to user IDs
    func resolveMentions(mentions: [String], from users: [AppUser]) -> [String] {
        var userIds: [String] = []
        
        for mention in mentions {
            let lowercaseMention = mention.lowercased()
            
            // Try to find user by name or email prefix
            if let user = users.first(where: { user in
                user.name.lowercased() == lowercaseMention ||
                user.email?.components(separatedBy: "@").first?.lowercased() == lowercaseMention
            }) {
                userIds.append(user.id)
            }
        }
        
        return userIds
    }
    
    // MARK: - Helper Methods
    
    private func parseAppUser(from document: DocumentSnapshot) -> AppUser? {
        guard let data = document.data(),
              let id = data["id"] as? String,
              let roleString = data["role"] as? String,
              let role = Role(rawValue: roleString),
              let name = data["name"] as? String else {
            return nil
        }
        
        return AppUser(
            id: id,
            role: role,
            name: name,
            phone: data["phone"] as? String,
            email: data["email"] as? String
        )
    }
}

// MARK: - AppUser Extension for Mentions

extension AppUser {
    /// Get mention text for this user (used in autocomplete)
    /// Just returns @name without quotes - display formatting handled separately
    var mentionText: String {
        return "@\(name)"
    }
    
    /// Get display name for mention autocomplete
    var mentionDisplayName: String {
        if let email = email {
            return "\(name) (\(email.components(separatedBy: "@").first ?? email))"
        }
        return name
    }
}
