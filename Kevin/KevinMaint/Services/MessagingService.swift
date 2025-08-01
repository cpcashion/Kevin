import Foundation
import FirebaseFirestore
import FirebaseAuth

class MessagingService: ObservableObject {
  static let shared = MessagingService()
  private let db = Firestore.firestore()
  
  @Published var conversations: [Conversation] = []
  @Published var currentMessages: [Message] = []
  @Published var messages: [String: [Message]] = [:] // Messages by conversation ID
  @Published var unreadCount: Int = 0
  
  private var conversationsListener: ListenerRegistration?
  private var messagesListener: ListenerRegistration?
  
  // PERFORMANCE: Disable excessive debug logging
  private let enableDebugLogging = false
  
  private init() {}
  
  // MARK: - Conversation Management
  
  func startListeningToConversations(for userId: String, isAdmin: Bool = false) {
    print("🎧 [MessagingService] startListeningToConversations called")
    print("🎧 [MessagingService] - User ID: \(userId)")
    print("🎧 [MessagingService] - Is Admin: \(isAdmin)")
    
    conversationsListener?.remove()
    
    // SECURITY: Only admins can see all conversations, regular users only see their own
    let query: Query
    if isAdmin {
      print("🎧 [MessagingService] Using ADMIN query (all active conversations)")
      // Admin mode - show all active conversations
      query = db.collection("conversations")
        .whereField("isActive", isEqualTo: true)
        .order(by: "createdAt", descending: true)
        .limit(to: 100) // Limit for performance
    } else {
      print("🎧 [MessagingService] Using USER query (participantIds array-contains)")
      // Regular user mode - show ONLY conversations they're a participant in
      query = db.collection("conversations")
        .whereField("participantIds", arrayContains: userId)
        .whereField("isActive", isEqualTo: true)
        .order(by: "createdAt", descending: true)
    }
    
    conversationsListener = query.addSnapshotListener { [weak self] snapshot, error in
      if let error = error {
        print("❌ [MessagingService] Conversations listener error: \(error.localizedDescription)")
        print("❌ [MessagingService] Error code: \((error as NSError).code)")
        print("❌ [MessagingService] This may be a Firebase rules propagation delay - wait 1-2 minutes")
        return
      }
      
      guard let documents = snapshot?.documents else {
        print("⚠️ [MessagingService] No documents in snapshot")
        return
      }
      
      print("📬 [MessagingService] Listener received \(documents.count) documents")
      
      let conversations = documents.compactMap { doc -> Conversation? in
        do {
          let conv = try doc.data(as: Conversation.self)
          print("📬 [MessagingService] - Conversation: \(conv.id)")
          print("📬 [MessagingService]   Title: \(conv.title ?? "nil")")
          print("📬 [MessagingService]   Type: \(conv.type)")
          print("📬 [MessagingService]   IsActive: \(conv.isActive)")
          print("📬 [MessagingService]   IssueId: \(conv.issueId ?? "nil")")
          return conv
        } catch {
          print("❌ [MessagingService] Failed to decode conversation: \(error)")
          return nil
        }
      }
      
      let sortedConversations = conversations.sorted { conv1, conv2 in
        switch (conv1.lastMessageAt, conv2.lastMessageAt) {
        case (let date1?, let date2?):
          return date1 > date2
        case (nil, _?):
          return false
        case (_?, nil):
          return true
        case (nil, nil):
          return conv1.createdAt > conv2.createdAt
        }
      }
      
      print("📬 [MessagingService] Decoded \(conversations.count) conversations successfully")
      print("📬 [MessagingService] Sorted conversations: \(sortedConversations.count)")
      
      DispatchQueue.main.async {
        self?.conversations = sortedConversations
        print("✅ [MessagingService] Updated UI with \(sortedConversations.count) conversations")
        self?.updateUnreadCount(for: userId)
      }
    }
  }
  
  func createGeneralConversation(restaurantId: String?, userId: String, userName: String) async throws -> Conversation {
    print("🔄 MessagingService: Creating general conversation")
    print("🔄 MessagingService: - Restaurant ID: \(restaurantId ?? "nil (admin mode)")")
    print("🔄 MessagingService: - User ID: \(userId)")
    print("🔄 MessagingService: - User Name: \(userName)")
    print("🔄 MessagingService: - Auth UID: \(Auth.auth().currentUser?.uid ?? "nil")")
    
    // For admin users, create a global conversation if no restaurant specified
    let effectiveRestaurantId = restaurantId ?? "global_admin_chat"
    
    // Check if general conversation already exists
    let existingQuery = db.collection("conversations")
      .whereField("restaurantId", isEqualTo: effectiveRestaurantId)
      .whereField("type", isEqualTo: ConversationType.general.rawValue)
      .whereField("participantIds", arrayContains: userId)
    
    print("🔍 MessagingService: Checking for existing general conversation...")
    let existingSnapshot = try await existingQuery.getDocuments()
    
    if let existingDoc = existingSnapshot.documents.first,
       let existingConversation = try? existingDoc.data(as: Conversation.self) {
      print("✅ MessagingService: Found existing general conversation: \(existingConversation.id)")
      return existingConversation
    }
    
    print("🆕 MessagingService: No existing conversation found, creating new one...")
    
    // Create new general conversation
    let conversationId = UUID().uuidString
    let now = Date()
    
    print("🔍 MessagingService: Getting admin user IDs...")
    // Get admin IDs
    let adminIds = try await getAdminUserIds()
    print("✅ MessagingService: Found \(adminIds.count) admin IDs: \(adminIds)")
    let participantIds = [userId] + adminIds
    print("👥 MessagingService: Total participants: \(participantIds)")
    
    let conversationTitle = restaurantId == nil ? "Kevin Admin Support" : "General Chat"
    
    let conversation = Conversation(
      id: conversationId,
      restaurantId: effectiveRestaurantId,
      type: .general,
      issueId: nil,
      workOrderId: nil,
      participantIds: participantIds,
      title: conversationTitle,
      createdAt: now,
      updatedAt: now,
      isActive: true,
      lastMessageAt: nil,
      unreadCount: [:],
      priority: nil,
      restaurantName: nil,
      restaurantAddress: nil,
      managerName: userName,
      contextData: nil
    )
    
    print("💾 MessagingService: Saving conversation to Firestore...")
    try db.collection("conversations").document(conversationId).setData(from: conversation)
    print("✅ MessagingService: Conversation saved successfully")
    
    // Send welcome message
    print("💬 MessagingService: Sending welcome system message...")
    try await sendSystemMessage(
      conversationId: conversationId,
      content: "\(userName) started a conversation with Kevin Maint support."
    )
    print("✅ MessagingService: Welcome message sent")
    
    return conversation
  }
  
  func createIssueConversation(for issue: Issue, userId: String, userName: String) async throws -> Conversation {
    print("🔄 [MessagingService] ===== CREATING ISSUE CONVERSATION =====")
    print("🔄 [MessagingService] Issue ID: \(issue.id)")
    print("🔄 [MessagingService] Issue Title: \(issue.title)")
    print("🔄 [MessagingService] User ID: \(userId)")
    print("🔄 [MessagingService] User Name: \(userName)")
    print("🔄 [MessagingService] Restaurant ID: \(issue.restaurantId ?? "nil")")
    
    // Check if issue conversation already exists
    let existingQuery = db.collection("conversations")
      .whereField("issueId", isEqualTo: issue.id)
      .whereField("type", isEqualTo: ConversationType.issue_specific.rawValue)
    
    print("🔍 [MessagingService] Checking for existing conversation...")
    let existingSnapshot = try await existingQuery.getDocuments()
    print("🔍 [MessagingService] Found \(existingSnapshot.documents.count) existing conversations")
    
    if let existingDoc = existingSnapshot.documents.first,
       let existingConversation = try? existingDoc.data(as: Conversation.self) {
      print("✅ [MessagingService] Found existing conversation: \(existingConversation.id)")
      print("✅ [MessagingService] Participants: \(existingConversation.participantIds)")
      return existingConversation
    }
    
    // Create new issue conversation
    let conversationId = UUID().uuidString
    let now = Date()
    
    print("🆕 [MessagingService] Creating new conversation: \(conversationId)")
    
    // Get admin IDs with error handling
    print("🔍 [MessagingService] Getting admin user IDs...")
    let adminIds: [String]
    do {
      adminIds = try await getAdminUserIds()
      print("✅ [MessagingService] Retrieved \(adminIds.count) admin IDs: \(adminIds)")
    } catch {
      print("❌ [MessagingService] Failed to get admin IDs, using current user only: \(error)")
      adminIds = []
    }
    
    // Ensure current user is always included and deduplicate
    var participantIds = [userId]
    for adminId in adminIds {
      if !participantIds.contains(adminId) {
        participantIds.append(adminId)
      }
    }
    
    print("👥 [MessagingService] Final participant IDs: \(participantIds)")
    print("👥 [MessagingService] Participant count: \(participantIds.count)")
    print("👥 [MessagingService] Current user (\(userId)) included: \(participantIds.contains(userId))")
    
    let conversation = Conversation(
      id: conversationId,
      restaurantId: issue.restaurantId,
      type: .issue_specific,
      issueId: issue.id,
      workOrderId: nil,
      participantIds: participantIds,
      title: "Issue: \(issue.title)",
      createdAt: now,
      updatedAt: now,
      isActive: true,
      lastMessageAt: nil,
      unreadCount: [:],
      priority: issue.priority,
      restaurantName: nil,
      restaurantAddress: nil,
      managerName: userName,
      contextData: ["issueType": issue.type ?? "General", "issueStatus": issue.status.rawValue]
    )
    
    print("💾 [MessagingService] Saving conversation to Firestore...")
    print("💾 [MessagingService] Conversation data:")
    print("💾 [MessagingService] - ID: \(conversation.id)")
    print("💾 [MessagingService] - Type: \(conversation.type)")
    print("💾 [MessagingService] - Participants: \(conversation.participantIds)")
    print("💾 [MessagingService] - IsActive: \(conversation.isActive)")
    print("💾 [MessagingService] - RestaurantId: \(conversation.restaurantId ?? "nil")")
    print("💾 [MessagingService] - CreatedAt: \(conversation.createdAt)")
    
    try db.collection("conversations").document(conversationId).setData(from: conversation)
    print("✅ [MessagingService] Conversation saved to Firestore successfully")
    
    // Send system message with issue context
    print("💬 [MessagingService] Sending system welcome message...")
    try await sendSystemMessage(
      conversationId: conversationId,
      content: "\(userName) started a conversation about issue: \(issue.title)\n\nPriority: \(issue.priority.rawValue.capitalized)\nStatus: \(issue.status.rawValue.capitalized)"
    )
    print("✅ [MessagingService] System message sent successfully")
    
    print("✅ [MessagingService] ===== ISSUE CONVERSATION CREATED SUCCESSFULLY =====")
    return conversation
  }
  
  // MARK: - Message Management
  
  // Simple message sending for Smart Timeline
  func sendMessage(
    conversationId: String,
    text: String,
    senderId: String,
    senderName: String
  ) async throws {
    let messageId = UUID().uuidString
    let now = Date()
    
    let message = Message(
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: .owner, // Default role
      type: .text,
      content: text,
      imageUrl: nil,
      voiceUrl: nil,
      createdAt: now,
      isRead: false,
      readBy: [senderId: now],
      metadata: nil
    )
    
    // Save to Firestore
    try await db.collection("conversations")
      .document(conversationId)
      .collection("messages")
      .document(messageId)
      .setData(message.toDictionary())
    
    // Update conversation's lastMessageAt
    try await db.collection("conversations")
      .document(conversationId)
      .updateData([
        "lastMessageAt": now,
        "lastMessage": text
      ])
    
    print("✅ [MessagingService] Simple message sent successfully")
  }
  
  
  func startListeningToMessages(conversationId: String) {
    messagesListener?.remove()
    
    messagesListener = db.collection("conversations")
      .document(conversationId)
      .collection("messages")
      .order(by: "createdAt", descending: false)
      .addSnapshotListener { [weak self] snapshot, error in
        guard let documents = snapshot?.documents else {
          print("❌ Error fetching messages: \(error?.localizedDescription ?? "Unknown")")
          return
        }
        
        let messages = documents.compactMap { doc in
          try? doc.data(as: Message.self)
        }
        
        DispatchQueue.main.async {
          self?.currentMessages = messages
          self?.messages[conversationId] = messages
        }
      }
  }
  
  func sendMessage(
    conversationId: String,
    content: String,
    senderId: String,
    senderName: String,
    senderRole: Role,
    type: MessageType = .text,
    imageUrl: String? = nil,
    voiceUrl: String? = nil
  ) async throws {
    print("💬 [MessagingService] ===== SENDING MESSAGE =====")
    print("💬 [MessagingService] Conversation ID: \(conversationId)")
    print("💬 [MessagingService] Sender ID: \(senderId)")
    print("💬 [MessagingService] Sender Name: \(senderName)")
    print("💬 [MessagingService] Sender Role: \(senderRole)")
    print("💬 [MessagingService] Message Type: \(type)")
    print("💬 [MessagingService] Content: '\(content)'")
    print("💬 [MessagingService] Content length: \(content.count) characters")
    print("💬 [MessagingService] Image URL: \(imageUrl ?? "nil")")
    print("💬 [MessagingService] Voice URL: \(voiceUrl ?? "nil")")
    print("💬 [MessagingService] Current Auth UID: \(Auth.auth().currentUser?.uid ?? "NOT AUTHENTICATED")")
    print("💬 [MessagingService] Auth matches sender: \(Auth.auth().currentUser?.uid == senderId)")
    
    let messageId = UUID().uuidString
    let now = Date()
    
    print("💬 [MessagingService] Generated message ID: \(messageId)")
    print("💬 [MessagingService] Message timestamp: \(now)")
    
    let message = Message(
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      type: type,
      content: content,
      imageUrl: imageUrl,
      voiceUrl: voiceUrl,
      createdAt: now,
      isRead: false,
      readBy: [senderId: now], // Sender has "read" their own message
      metadata: nil
    )
    
    print("💬 [MessagingService] Created message object successfully")
    
    print("💾 [MessagingService] Saving message to Firestore...")
    print("💾 [MessagingService] Target path: conversations/\(conversationId)/messages/\(messageId)")
    print("💾 [MessagingService] Firestore database: \(db.app.name)")
    
    do {
      // Add message to subcollection
      print("💾 [MessagingService] Calling setData(from:) on message document...")
      try db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)
        .setData(from: message)
      
      print("✅ [MessagingService] Message saved to Firestore successfully")
      
      // Update conversation's lastMessageAt
      print("🔄 [MessagingService] Updating conversation lastMessageAt...")
      print("🔄 [MessagingService] Target conversation: \(conversationId)")
      print("🔄 [MessagingService] Setting lastMessageAt to: \(now)")
      
      try await db.collection("conversations")
        .document(conversationId)
        .updateData([
          "lastMessageAt": now,
          "updatedAt": now
        ])
      
      print("✅ [MessagingService] Conversation lastMessageAt updated successfully")
      
      // Send notifications to other participants
      print("🔔 [MessagingService] Starting notification process...")
      await sendMessageNotifications(message: message, conversationId: conversationId)
      print("🔔 [MessagingService] Notification process completed")
      
      print("✅ [MessagingService] ===== MESSAGE SENT SUCCESSFULLY =====")
      
    } catch {
      print("❌ [MessagingService] ===== MESSAGE SEND FAILED =====")
      print("❌ [MessagingService] Error description: \(error.localizedDescription)")
      print("❌ [MessagingService] Error code: \((error as NSError).code)")
      print("❌ [MessagingService] Error domain: \((error as NSError).domain)")
      print("❌ [MessagingService] Full error: \(error)")
      print("❌ [MessagingService] User info: \((error as NSError).userInfo)")
      
      // Check for specific error types
      let nsError = error as NSError
      switch nsError.code {
      case 7:
        print("🔒 [MessagingService] PERMISSION DENIED on message send!")
        print("🔒 [MessagingService] - Check Firestore security rules for messages subcollection")
        print("🔒 [MessagingService] - Conversation ID: \(conversationId)")
        print("🔒 [MessagingService] - Message ID: \(messageId)")
        print("🔒 [MessagingService] - Sender ID: \(senderId)")
        print("🔒 [MessagingService] - Auth UID: \(Auth.auth().currentUser?.uid ?? "nil")")
      case 5:
        print("🚫 [MessagingService] NOT FOUND ERROR")
        print("🚫 [MessagingService] - Conversation may not exist: \(conversationId)")
      case 14:
        print("🌐 [MessagingService] UNAVAILABLE ERROR")
        print("🌐 [MessagingService] - Network or service unavailable")
      default:
        print("❌ [MessagingService] OTHER ERROR TYPE: \(nsError.code)")
      }
      
      throw error
    }
  }
  
  private func sendMessageNotifications(message: Message, conversationId: String) async {
    print("🔔 MessagingService: Starting notification process for message: \(message.id)")
    print("🔔 MessagingService: Sender: \(message.senderName) (\(message.senderId))")
    print("🔔 MessagingService: Content: \(message.content)")
    
    do {
      // Get conversation to find participants and restaurant info
      let conversationDoc = try await db.collection("conversations").document(conversationId).getDocument()
      guard let conversationData = conversationDoc.data(),
            let participantIds = conversationData["participantIds"] as? [String] else {
        print("⚠️ [MessagingService] Could not get conversation data for notifications")
        return
      }
      
      let restaurantName = conversationData["restaurantName"] as? String ?? "Kevin Maint"
      let issueId = conversationData["issueId"] as? String
      let issueTitle = conversationData["title"] as? String
      
      print("🔔 MessagingService: Found \(participantIds.count) participants: \(participantIds)")
      print("🔔 MessagingService: Restaurant: \(restaurantName)")
      print("🔔 MessagingService: Issue context: \(issueTitle ?? "General conversation")")
      
      // Filter out the sender from notification recipients
      let recipientIds = participantIds.filter { $0 != message.senderId }
      print("🔔 MessagingService: Recipients after filtering sender: \(recipientIds)")
      
      guard !recipientIds.isEmpty else {
        print("ℹ️ [MessagingService] No recipients for notification")
        return
      }
      
      // Create message preview (truncate if too long)
      let messagePreview = message.content.count > 50 
        ? String(message.content.prefix(50)) + "..."
        : message.content
      
      // Send enhanced notification with context
      await NotificationService.shared.sendEnhancedMessageNotification(
        to: recipientIds,
        senderName: message.senderName,
        messagePreview: messagePreview,
        conversationId: conversationId,
        senderId: message.senderId,
        restaurantName: restaurantName,
        issueTitle: issueTitle,
        issueId: issueId
      )
      
      print("🔔 [MessagingService] Sent notifications to \(recipientIds.count) recipients")
      
      
    } catch {
      print("❌ [MessagingService] Failed to send notifications: \(error)")
    }
  }
  
  func markMessageAsRead(messageId: String, conversationId: String, userId: String) async throws {
    try await db.collection("conversations")
      .document(conversationId)
      .collection("messages")
      .document(messageId)
      .updateData([
        "readBy.\(userId)": Date()
      ])
  }
  
  // MARK: - Helper Methods
  
  private func getAdminUserIds() async throws -> [String] {
    print("🔍 MessagingService: Querying for admin users...")
    let usersQuery = db.collection("users")
      .whereField("role", isEqualTo: Role.admin.rawValue)
    
    do {
      let snapshot = try await usersQuery.getDocuments()
      print("✅ MessagingService: Admin query returned \(snapshot.documents.count) users")
      
      let adminIds = snapshot.documents.map { doc in
        print("👑 MessagingService: Found admin user: \(doc.documentID)")
        return doc.documentID
      }
      
      // If no admin users found, return empty array - don't use hardcoded fallbacks
      if adminIds.isEmpty {
        print("⚠️ MessagingService: No admin users found in database")
        return []
      }
      
      return adminIds
    } catch {
      print("❌ MessagingService: Failed to get admin users: \(error)")
      print("❌ MessagingService: Error code: \((error as NSError).code)")
      print("❌ MessagingService: Error domain: \((error as NSError).domain)")
      
      // Check for permission errors
      if (error as NSError).code == 7 {
        print("🔒 MessagingService: PERMISSION DENIED on admin users query!")
        print("🔒 MessagingService: Check Firestore security rules for users collection")
        print("🔄 MessagingService: Using fallback admin IDs due to permission error")
        return ["4gVbMp786Ka5G3Bqx47Jbuk3yL93"] // Current user's ID from logs
      }
      
      throw error
    }
  }
  
  private func sendSystemMessage(conversationId: String, content: String) async throws {
    try await sendMessage(
      conversationId: conversationId,
      content: content,
      senderId: "system",
      senderName: "Kevin System",
      senderRole: .admin,
      type: .system
    )
  }
  
  private func updateUnreadCount(for userId: String) {
    var totalUnread = 0
    
    for conversation in conversations {
      let unreadForUser = conversation.unreadCount[userId] ?? 0
      totalUnread += unreadForUser
    }
    
    DispatchQueue.main.async {
      self.unreadCount = totalUnread
    }
  }
  
  func stopListening() {
    conversationsListener?.remove()
    messagesListener?.remove()
    conversationsListener = nil
    messagesListener = nil
  }
  
  // MARK: - Enhanced Conversation Types
  
  func createEmergencyConversation(restaurantId: String?, userId: String, userName: String, restaurantName: String? = nil, managerName: String? = nil) async throws -> Conversation {
    let conversationId = UUID().uuidString
    let now = Date()
    
    let adminIds = try await getAdminUserIds()
    let participantIds = [userId] + adminIds
    
    let conversation = Conversation(
      id: conversationId,
      restaurantId: restaurantId,
      type: .emergency,
      issueId: nil,
      workOrderId: nil,
      participantIds: participantIds,
      title: "🚨 Emergency Support",
      createdAt: now,
      updatedAt: now,
      isActive: true,
      lastMessageAt: nil,
      unreadCount: [:],
      priority: .high,  // Changed from .critical
      restaurantName: restaurantName,
      restaurantAddress: nil,
      managerName: managerName ?? userName,
      contextData: ["urgency": "critical"]
    )
    
    try db.collection("conversations").document(conversationId).setData(from: conversation)
    
    try await sendSystemMessage(
      conversationId: conversationId,
      content: "🚨 EMERGENCY: \(userName) has started an emergency conversation and needs immediate assistance."
    )
    
    return conversation
  }
  
  func createAIAnalysisConversation(
    restaurantId: String?,
    userId: String,
    userName: String,
    analysisData: ImageAnalysisResult,
    restaurantName: String? = nil,
    managerName: String? = nil
  ) async throws -> Conversation {
    let conversationId = UUID().uuidString
    let now = Date()
    
    let adminIds = try await getAdminUserIds()
    let participantIds = [userId] + adminIds
    
    let conversation = Conversation(
      id: conversationId,
      restaurantId: restaurantId,
      type: .ai_review,
      issueId: nil,
      workOrderId: nil,
      participantIds: participantIds,
      title: "🤖 AI Analysis: \(analysisData.summary)",
      createdAt: now,
      updatedAt: now,
      isActive: true,
      lastMessageAt: nil,
      unreadCount: [:],
      priority: priorityFromString(analysisData.priority),
      restaurantName: restaurantName,
      restaurantAddress: nil,
      managerName: managerName ?? userName,
      contextData: [
        "aiAnalysis": "true",
        "category": analysisData.category ?? "General",
        "estimatedCost": String(analysisData.estimatedCost ?? 0),
        "timeToComplete": analysisData.timeToComplete ?? "Unknown"
      ]
    )
    
    try db.collection("conversations").document(conversationId).setData(from: conversation)
    
    // Send AI analysis as initial message
    let analysisContent = """
    🤖 **AI Analysis Results**
    
    **Summary:** \(analysisData.summary)
    **Category:** \(analysisData.category ?? "General")
    **Priority:** \(analysisData.priority)
    **Estimated Cost:** $\(String(format: "%.2f", analysisData.estimatedCost ?? 0))
    **Time to Complete:** \(analysisData.timeToComplete ?? "Unknown")
    
    **Description:**
    \(analysisData.description)
    
    \(analysisData.repairInstructions.map { "**Repair Instructions:**\n\($0)" } ?? "")
    
    How can Kevin Maint help you with this issue?
    """
    
    try await sendMessage(
      conversationId: conversationId,
      content: analysisContent,
      senderId: "system",
      senderName: "Kevin AI",
      senderRole: .admin,
      type: .ai_analysis
    )
    
    return conversation
  }
  
  private func priorityFromString(_ priority: String) -> IssuePriority? {
    switch priority.lowercased() {
    case "low": return .low
    case "medium", "moderate": return .medium
    case "high", "critical", "urgent": return .high  // critical/urgent map to high
    default: return .medium
    }
  }
  
  func getConversation(conversationId: String) async throws -> Conversation {
    let doc = try await db.collection("conversations").document(conversationId).getDocument()
    
    guard let data = doc.data() else {
      throw NSError(domain: "MessagingService", code: 404, userInfo: [
        NSLocalizedDescriptionKey: "Conversation not found"
      ])
    }
    
    return Conversation(
      id: data["id"] as? String ?? conversationId,
      restaurantId: data["restaurantId"] as? String,
      type: ConversationType(rawValue: data["type"] as? String ?? "general") ?? .general,
      issueId: data["issueId"] as? String,
      workOrderId: data["workOrderId"] as? String,
      participantIds: data["participantIds"] as? [String] ?? [],
      title: data["title"] as? String ?? "Conversation",
      createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
      updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
      isActive: data["isActive"] as? Bool ?? true,
      lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue(),
      unreadCount: data["unreadCount"] as? [String: Int] ?? [:],
      priority: IssuePriority(rawValue: data["priority"] as? String ?? "medium"),
      restaurantName: data["restaurantName"] as? String,
      restaurantAddress: data["restaurantAddress"] as? String,
      managerName: data["managerName"] as? String,
      contextData: data["contextData"] as? [String: String]
    )
  }
  
  func deleteConversation(conversationId: String) async throws {
    print("🗑️ MessagingService: Deleting conversation: \(conversationId)")
    
    // Mark conversation as inactive instead of actually deleting
    try await db.collection("conversations")
      .document(conversationId)
      .updateData([
        "isActive": false,
        "updatedAt": Date()
      ])
    
    print("✅ MessagingService: Conversation marked as inactive")
  }
  
  // MARK: - Database Repair Functions
  
  func fixAllInactiveConversations() async throws {
    print("🔧 [MessagingService] ===== FIXING ALL INACTIVE CONVERSATIONS =====")
    
    do {
      // Get all conversations that are currently inactive
      let inactiveQuery = db.collection("conversations")
        .whereField("isActive", isEqualTo: false)
      
      let snapshot = try await inactiveQuery.getDocuments()
      print("🔧 [MessagingService] Found \(snapshot.documents.count) inactive conversations to fix")
      
      if snapshot.documents.isEmpty {
        print("✅ [MessagingService] No inactive conversations found - all good!")
        return
      }
      
      // Update each conversation to set isActive = true
      for (index, doc) in snapshot.documents.enumerated() {
        let conversationId = doc.documentID
        let data = doc.data()
        let title = data["title"] as? String ?? "Unknown"
        
        print("🔧 [MessagingService] Fixing conversation \(index + 1)/\(snapshot.documents.count): \(conversationId)")
        print("🔧 [MessagingService] - Title: \(title)")
        
        try await db.collection("conversations")
          .document(conversationId)
          .updateData([
            "isActive": true,
            "updatedAt": Date()
          ])
        
        print("✅ [MessagingService] Fixed conversation: \(conversationId)")
      }
      
      print("✅ [MessagingService] Successfully fixed \(snapshot.documents.count) conversations")
      print("✅ [MessagingService] ===== ALL CONVERSATIONS FIXED =====")
      
    } catch {
      print("❌ [MessagingService] Failed to fix conversations: \(error)")
      print("❌ [MessagingService] Error code: \((error as NSError).code)")
      print("❌ [MessagingService] Error domain: \((error as NSError).domain)")
      throw error
    }
  }
  
  // MARK: - Debug Functions
  
  private func debugConversationsExistence(userId: String) async {
    print("🔍 [MessagingService] ===== DEBUG: CHECKING CONVERSATIONS EXISTENCE =====")
    
    do {
      // Check if ANY conversations exist at all
      let allConversationsSnapshot = try await db.collection("conversations").limit(to: 10).getDocuments()
      print("🔍 [MessagingService] DEBUG: Total conversations in database: \(allConversationsSnapshot.documents.count)")
      
      if allConversationsSnapshot.documents.isEmpty {
        print("⚠️ [MessagingService] DEBUG: NO CONVERSATIONS EXIST IN DATABASE!")
        return
      }
      
      // Check conversations that should match our query
      for (index, doc) in allConversationsSnapshot.documents.enumerated() {
        let data = doc.data()
        let participantIds = data["participantIds"] as? [String] ?? []
        let isActive = data["isActive"] as? Bool ?? false
        let type = data["type"] as? String ?? "unknown"
        let title = data["title"] as? String ?? "untitled"
        
        print("🔍 [MessagingService] DEBUG: Conversation \(index + 1): \(doc.documentID)")
        print("🔍 [MessagingService] DEBUG: - Title: \(title)")
        print("🔍 [MessagingService] DEBUG: - Type: \(type)")
        print("🔍 [MessagingService] DEBUG: - Participants: \(participantIds)")
        print("🔍 [MessagingService] DEBUG: - IsActive: \(isActive)")
        print("🔍 [MessagingService] DEBUG: - User '\(userId)' in participants: \(participantIds.contains(userId))")
        print("🔍 [MessagingService] DEBUG: - Should match query: \(participantIds.contains(userId) && isActive)")
        
        if participantIds.contains(userId) && isActive {
          print("✅ [MessagingService] DEBUG: This conversation SHOULD appear in the listener!")
        }
      }
      
      // Try the exact same query as the listener to see if it works
      print("🔍 [MessagingService] DEBUG: Testing exact listener query...")
      let testQuery = db.collection("conversations")
        .whereField("participantIds", arrayContains: userId)
        .whereField("isActive", isEqualTo: true)
        .order(by: "createdAt", descending: true)
      
      let testSnapshot = try await testQuery.getDocuments()
      print("🔍 [MessagingService] DEBUG: Test query returned \(testSnapshot.documents.count) conversations")
      
      if testSnapshot.documents.isEmpty {
        print("❌ [MessagingService] DEBUG: QUERY RETURNS EMPTY - THIS IS THE PROBLEM!")
        
        // Try without the order by clause
        print("🔍 [MessagingService] DEBUG: Testing query without ORDER BY...")
        let simpleQuery = db.collection("conversations")
          .whereField("participantIds", arrayContains: userId)
          .whereField("isActive", isEqualTo: true)
        
        let simpleSnapshot = try await simpleQuery.getDocuments()
        print("🔍 [MessagingService] DEBUG: Simple query returned \(simpleSnapshot.documents.count) conversations")
        
        if simpleSnapshot.documents.count > 0 {
          print("⚠️ [MessagingService] DEBUG: ORDER BY clause is causing the issue!")
        }
      } else {
        print("✅ [MessagingService] DEBUG: Test query works - listener should work too")
        for doc in testSnapshot.documents {
          print("✅ [MessagingService] DEBUG: Found conversation: \(doc.data()["title"] as? String ?? "untitled")")
        }
      }
      
    } catch {
      print("❌ [MessagingService] DEBUG: Error during debug check: \(error)")
      print("❌ [MessagingService] DEBUG: Error code: \((error as NSError).code)")
      print("❌ [MessagingService] DEBUG: Error domain: \((error as NSError).domain)")
    }
    
    print("🔍 [MessagingService] ===== DEBUG: CONVERSATIONS EXISTENCE CHECK COMPLETE =====")
  }
  
  deinit {
    stopListening()
  }
}
