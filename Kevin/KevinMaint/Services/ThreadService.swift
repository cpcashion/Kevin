import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine
import UIKit

final class ThreadService: ObservableObject {
  static let shared = ThreadService()
  
  private let db = Firestore.firestore()
  private let storage = Storage.storage()
  
  @Published var messages: [ThreadMessage] = []
  @Published var smartSummary: SmartSummary = SmartSummary(
    currentStatus: "",
    riskLevel: .low,
    totalCost: 0,
    nextAction: "",
    updatedAt: Date()
  )
  @Published var isLoadingMessages = true
  
  private var listener: ListenerRegistration?
  
  // MARK: - Collection Paths
  
  private func messagesCol(_ requestId: String) -> CollectionReference {
    db.collection("maintenance_requests").document(requestId).collection("thread_messages")
  }
  
  private func summaryDoc(_ requestId: String) -> DocumentReference {
    db.collection("maintenance_requests").document(requestId).collection("thread_cache").document("summary")
  }
  
  // MARK: - Start Listening
  
  func startListening(requestId: String) {
    print("🔄 [ThreadService] Starting to listen for messages on request: \(requestId)")
    listener?.remove()
    isLoadingMessages = true
    
    listener = messagesCol(requestId)
      .order(by: "createdAt", descending: false)
      .addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else { return }
        
        if let error = error {
          print("❌ [ThreadService] Error listening to messages: \(error)")
          return
        }
        
        guard let documents = snapshot?.documents else { 
          print("📭 [ThreadService] No documents in snapshot")
          DispatchQueue.main.async {
            self.messages = []
            self.isLoadingMessages = false
            print("📭 [ThreadService] Set loading to false - no documents")
          }
          return 
        }
        
        print("📨 [ThreadService] Received \(documents.count) message documents")
        let newMessages = documents.compactMap { self.parseMessage(doc: $0) }
        print("📨 [ThreadService] Parsed \(newMessages.count) valid messages")
        
        for message in newMessages {
          print("📨 [ThreadService] Message: \(message.message) by \(message.authorType) at \(message.createdAt)")
        }
        
        DispatchQueue.main.async {
          self.messages = newMessages
          self.isLoadingMessages = false
          print("📨 [ThreadService] Updated UI with \(newMessages.count) messages")
        }
      }
    
    // Load summary
    Task {
      await loadSummary(requestId: requestId)
    }
  }
  
  func stopListening() {
    listener?.remove()
    listener = nil
  }
  
  // MARK: - Send Message
  
  func sendMessage(
    requestId: String,
    authorId: String,
    message: String,
    type: ThreadMessageType = .text,
    attachmentUrl: String? = nil,
    attachmentThumbUrl: String? = nil,
    parentMessageId: String? = nil
  ) async throws {
    print("📤 [ThreadService] sendMessage called - requestId: \(requestId), authorId: \(authorId), message: '\(message)'")
    
    let msg = ThreadMessage(
      requestId: requestId,
      authorId: authorId,
      authorType: authorId == "ai" ? .ai : .user,
      message: message,
      type: type,
      attachmentUrl: attachmentUrl,
      attachmentThumbUrl: attachmentThumbUrl,
      parentMessageId: parentMessageId
    )
    
    print("📤 [ThreadService] Created message object with ID: \(msg.id)")
    
    var messageData: [String: Any] = [
      "id": msg.id,
      "requestId": requestId,
      "authorId": authorId,
      "authorType": (authorId == "ai" ? ThreadAuthorType.ai : ThreadAuthorType.user).rawValue,
      "message": message,
      "type": type.rawValue,
      "createdAt": Timestamp(date: msg.createdAt)
    ]
    
    // Add parent message ID if this is a reply
    if let parentMessageId = parentMessageId {
      messageData["parentMessageId"] = parentMessageId
    }
    
    // Add attachment URLs if provided
    if let attachmentUrl = attachmentUrl {
      messageData["attachmentUrl"] = attachmentUrl
    }
    if let attachmentThumbUrl = attachmentThumbUrl {
      messageData["attachmentThumbUrl"] = attachmentThumbUrl
    }
    
    print("📤 [ThreadService] Attempting to save message to Firestore...")
    
    try await messagesCol(requestId).document(msg.id).setData(messageData)
    
    print("✅ [ThreadService] Message saved to Firestore successfully")
    
    // If this is a reply, increment parent's reply count
    if let parentMessageId = parentMessageId {
      try await incrementReplyCount(requestId: requestId, parentMessageId: parentMessageId)
    }
    // Update thread last activity timestamp
    try? await summaryDoc(requestId).setData([
      "updatedAt": Timestamp(date: Date())
    ], merge: true)
    print("🕒 [ThreadService] Updated thread last activity timestamp")
    
    // Send push notifications (don't await - fire and forget)
    Task {
      await sendMessageNotifications(
        requestId: requestId,
        senderId: authorId,
        messageText: message,
        isReply: parentMessageId != nil
      )
    }
    
    // DISABLED: AI chat auto-response temporarily disabled until UX improvements
    // TODO: Re-enable when we have a better AI chat experience
    // if type == .text && !message.isEmpty && shouldTriggerAIAnalysis(message) && authorId != "ai" {
    //   print("🤖 [ThreadService] Triggering AI analysis...")
    //   await analyzeAndRespond(requestId: requestId, userMessage: message)
    // }
  }
  
  // MARK: - Send with Attachment
  
  func sendMessageWithAttachment(
    requestId: String,
    authorId: String,
    message: String,
    type: ThreadMessageType,
    image: UIImage
  ) async throws {
    // Upload image
    guard let data = image.jpegData(compressionQuality: 0.85) else {
      throw NSError(domain: "ThreadService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
    }
    
    let attachmentId = UUID().uuidString
    let path = "thread-attachments/\(requestId)/\(attachmentId).jpg"
    let ref = storage.reference().child(path)
    _ = try await ref.putDataAsync(data, metadata: nil)
    let url = try await ref.downloadURL().absoluteString
    
    // Create message with attachment
    let msg = ThreadMessage(
      requestId: requestId,
      authorId: authorId,
      authorType: .user,
      message: message,
      type: type,
      attachmentUrl: url,
      attachmentThumbUrl: url
    )
    
    try await messagesCol(requestId).document(msg.id).setData([
      "id": msg.id,
      "requestId": requestId,
      "authorId": authorId,
      "authorType": ThreadAuthorType.user.rawValue,
      "message": message,
      "type": type.rawValue,
      "attachmentUrl": url,
      "attachmentThumbUrl": url,
      "createdAt": Timestamp(date: msg.createdAt)
    ])
    // Update thread last activity timestamp
    try? await summaryDoc(requestId).setData([
      "updatedAt": Timestamp(date: Date())
    ], merge: true)
    
    // Trigger AI analysis based on type
    await analyzeAttachment(requestId: requestId, type: type, imageUrl: url, image: image)
  }
  
  // MARK: - AI Analysis
  
  private func shouldTriggerAIAnalysis(_ message: String) -> Bool {
    let lowercaseMessage = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Skip AI analysis for simple test messages
    let skipPatterns = [
      "test",
      "testing",
      "hello",
      "hi",
      "ok",
      "okay",
      "yes",
      "no",
      "thanks",
      "thank you"
    ]
    
    // Skip if message is too short or matches skip patterns
    if lowercaseMessage.count < 10 {
      return false
    }
    
    for pattern in skipPatterns {
      if lowercaseMessage == pattern {
        return false
      }
    }
    
    // Trigger AI analysis for meaningful content
    let meaningfulPatterns = [
      "completed",
      "finished",
      "done",
      "fixed",
      "repaired",
      "installed",
      "replaced",
      "urgent",
      "emergency",
      "problem",
      "issue",
      "cost",
      "price",
      "invoice",
      "receipt",
      "materials",
      "parts",
      "progress",
      "update",
      "status"
    ]
    
    for pattern in meaningfulPatterns {
      if lowercaseMessage.contains(pattern) {
        return true
      }
    }
    
    // Default: trigger for longer messages that might contain meaningful content
    return lowercaseMessage.count > 20
  }
  
  private func analyzeAndRespond(requestId: String, userMessage: String) async {
    print("🤖 [ThreadService] Starting AI analysis for message: \(userMessage)")
    
    // Get the issue from maintenance request
    guard let issue = await getIssueFromRequest(requestId: requestId) else {
      print("❌ [ThreadService] Could not get issue for analysis")
      return
    }
    
    do {
      // Build comprehensive context using AIContextService
      print("🧠 [ThreadService] Building AI context...")
      let context = try await AIContextService.shared.buildContext(for: issue)
      
      // Get or create assistant thread
      print("🔗 [ThreadService] Getting assistant thread...")
      let threadId = try await AIAssistantService.shared.getOrCreateThread(for: requestId, context: context)
      
      // Add user message to assistant thread
      print("💬 [ThreadService] Adding message to assistant...")
      try await AIAssistantService.shared.addMessage(threadId: threadId, content: userMessage, role: "user")
      
      // Get or create assistant
      let assistantId = try await AIAssistantService.shared.getOrCreateAssistant()
      
      // Run the assistant with context
      print("⚡ [ThreadService] Running assistant...")
      let response = try await AIAssistantService.shared.runAssistant(
        threadId: threadId,
        assistantId: assistantId,
        context: context
      )
      
      print("✅ [ThreadService] Got AI response: \(response)")
      
      // Create AI response message in timeline
      let aiMessage = ThreadMessage(
        requestId: requestId,
        authorId: "ai",
        authorType: .ai,
        message: response,
        type: .text
      )
      
      let messageData: [String: Any] = [
        "id": aiMessage.id,
        "requestId": requestId,
        "authorId": "ai",
        "authorType": ThreadAuthorType.ai.rawValue,
        "message": response,
        "type": ThreadMessageType.text.rawValue,
        "createdAt": Timestamp(date: aiMessage.createdAt)
      ]
      
      try await messagesCol(requestId).document(aiMessage.id).setData(messageData)
      
      // Update thread last activity timestamp
      try? await summaryDoc(requestId).setData([
        "updatedAt": Timestamp(date: Date())
      ], merge: true)
      
      print("✅ [ThreadService] AI response saved to timeline")
      
    } catch {
      print("❌ [ThreadService] Error in AI analysis: \(error)")
      
      // Fallback to simple acknowledgment
      let fallbackMessage = ThreadMessage(
        requestId: requestId,
        authorId: "ai",
        authorType: .ai,
        message: "I'm processing your request. I'll get back to you shortly.",
        type: .text
      )
      
      let messageData: [String: Any] = [
        "id": fallbackMessage.id,
        "requestId": requestId,
        "authorId": "ai",
        "authorType": ThreadAuthorType.ai.rawValue,
        "message": fallbackMessage.message,
        "type": ThreadMessageType.text.rawValue,
        "createdAt": Timestamp(date: fallbackMessage.createdAt)
      ]
      
      try? await messagesCol(requestId).document(fallbackMessage.id).setData(messageData)
    }
  }
  
  private func analyzeAttachment(requestId: String, type: ThreadMessageType, imageUrl: String, image: UIImage) async {
    // For now, keep using AITimelineAnalyst for photo/receipt analysis
    // TODO: Migrate to AIAssistantService for unified experience
    guard let issue = await getIssueFromRequest(requestId: requestId) else {
      print("❌ [ThreadService] Could not get issue for attachment analysis")
      return
    }
    
    // Create a simple maintenance request context for AITimelineAnalyst
    let maintenanceContext = MaintenanceRequest(
      id: requestId,
      businessId: issue.restaurantId,
      locationId: issue.locationId,
      reporterId: issue.reporterId,
      title: issue.title,
      description: issue.description ?? "",
      category: .other,
      priority: .medium,
      status: .reported
    )
    
    let result: AIAnalysisResult
    
    switch type {
    case .photo:
      result = await AITimelineAnalyst.shared.analyzePhoto(image, context: maintenanceContext)
    case .receipt:
      result = await AITimelineAnalyst.shared.analyzeReceipt(image, context: maintenanceContext)
    case .invoice:
      result = await AITimelineAnalyst.shared.analyzeInvoice(image, context: maintenanceContext)
    default:
      print("📸 [ThreadService] Unsupported attachment type for analysis: \(type)")
      return
    }
    
    // Create AI response
    let aiMessage = ThreadMessage(
      requestId: requestId,
      authorId: "ai",
      authorType: .ai,
      message: result.reply,
      type: .text,
      aiProposal: result.proposal
    )
    
    do {
      var messageData: [String: Any] = [
        "id": aiMessage.id,
        "requestId": requestId,
        "authorId": "ai",
        "authorType": ThreadAuthorType.ai.rawValue,
        "message": result.reply,
        "type": ThreadMessageType.text.rawValue,
        "createdAt": Timestamp(date: aiMessage.createdAt)
      ]
      
      if let proposal = result.proposal {
        messageData["aiProposal"] = try proposal.toDictionary()
      }
      
      try await messagesCol(requestId).document(aiMessage.id).setData(messageData)
      
      // Update smart summary
      if let proposal = result.proposal {
        await updateSmartSummaryFromProposal(requestId: requestId, proposal: proposal)
      }
      
    } catch {
      print("❌ [ThreadService] Error sending AI attachment analysis: \(error)")
    }
  }
  
  private func getIssueFromRequest(requestId: String) async -> Issue? {
    do {
      print("🔍 [ThreadService] Fetching issue from Firestore: \(requestId)")
      
      // Try maintenance_requests collection first (where messages are stored)
      let requestDoc = try await db.collection("maintenance_requests").document(requestId).getDocument()
      
      print("🔍 [ThreadService] Maintenance request document exists: \(requestDoc.exists)")
      
      if requestDoc.exists, let data = requestDoc.data() {
        print("🔍 [ThreadService] Maintenance request data keys: \(data.keys)")
        
        // Parse from maintenance_request format
        guard let title = data["title"] as? String else {
          print("❌ [ThreadService] Missing title")
          return nil
        }
        
        let description = data["description"] as? String ?? ""
        let businessId = data["businessId"] as? String ?? ""
        let locationId = data["locationId"] as? String ?? businessId
        let reporterId = data["reporterId"] as? String ?? ""
        let createdAtTimestamp = data["createdAt"] as? Timestamp ?? Timestamp(date: Date())
        let updatedAtTimestamp = data["updatedAt"] as? Timestamp
        
        // Map status from maintenance request to issue status
        let statusStr = data["status"] as? String ?? "reported"
        let status: IssueStatus
        switch statusStr {
        case "new", "pending": status = .reported
        case "in_progress", "scheduled": status = .in_progress
        case "completed", "resolved": status = .completed
        default: status = .reported
        }
        
        // Default priority
        let priority = IssuePriority.medium
        
        print("✅ [ThreadService] Successfully parsed maintenance request: \(title)")
        
        return Issue(
          id: requestId,
          restaurantId: businessId,
          locationId: locationId,
          reporterId: reporterId,
          title: title,
          description: description,
          type: nil,
          priority: priority,
          status: status,
          createdAt: createdAtTimestamp.dateValue(),
          updatedAt: updatedAtTimestamp?.dateValue()
        )
      }
      
      // Fallback: try issues collection
      print("🔍 [ThreadService] Trying issues collection as fallback...")
      let issueDoc = try await db.collection("issues").document(requestId).getDocument()
      
      if issueDoc.exists, let data = issueDoc.data() {
        print("🔍 [ThreadService] Found in issues collection")
        
        guard let restaurantId = data["restaurantId"] as? String,
              let locationId = data["locationId"] as? String,
              let reporterId = data["reporterId"] as? String,
              let title = data["title"] as? String,
              let priorityStr = data["priority"] as? String,
              let statusStr = data["status"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
          print("❌ [ThreadService] Missing required fields in issues collection")
          return nil
        }
        
        let priority = IssuePriority(rawValue: priorityStr) ?? .medium
        let status = IssueStatus(rawValue: statusStr) ?? .reported
        let description = data["description"] as? String
        let type = data["type"] as? String
        let updatedAtTimestamp = data["updatedAt"] as? Timestamp
        
        print("✅ [ThreadService] Successfully parsed issue: \(title)")
        
        return Issue(
          id: requestId,
          restaurantId: restaurantId,
          locationId: locationId,
          reporterId: reporterId,
          title: title,
          description: description,
          type: type,
          priority: priority,
          status: status,
          createdAt: createdAtTimestamp.dateValue(),
          updatedAt: updatedAtTimestamp?.dateValue()
        )
      }
      
      print("❌ [ThreadService] Issue not found in either collection")
      return nil
    } catch {
      print("❌ [ThreadService] Error fetching issue: \(error)")
      print("❌ [ThreadService] Error details: \(error.localizedDescription)")
      return nil
    }
  }
  
  private func updateSmartSummaryFromProposal(requestId: String, proposal: AIProposal) async {
    var updatedSummary = smartSummary
    
    // Update summary based on proposal
    if let cost = proposal.extractedCost {
      updatedSummary.totalCost += cost
    }
    
    if let nextAction = proposal.nextAction {
      updatedSummary.nextAction = nextAction
    }
    
    updatedSummary.riskLevel = proposal.riskLevel ?? .low
    updatedSummary.updatedAt = Date()
    
    do {
      try await updateSummary(requestId: requestId, summary: updatedSummary)
    } catch {
      print("❌ [ThreadService] Error updating smart summary: \(error)")
    }
  }
  
  // MARK: - Accept/Dismiss Proposal
  
  func acceptProposal(requestId: String, messageId: String) async throws {
    try await messagesCol(requestId).document(messageId).updateData([
      "proposalAccepted": true
    ])
    
    // TODO: Apply the proposed changes to the request
  }
  
  func dismissProposal(requestId: String, messageId: String) async throws {
    try await messagesCol(requestId).document(messageId).updateData([
      "proposalAccepted": false
    ])
  }
  
  // MARK: - Smart Summary
  
  private func loadSummary(requestId: String) async {
    do {
      let doc = try await summaryDoc(requestId).getDocument()
      if let data = doc.data(),
         let summary = try? parseSummary(data: data) {
        await MainActor.run {
          self.smartSummary = summary
        }
      }
    } catch {
      print("⚠️ [ThreadService] No summary found, using default")
    }
  }
  
  func updateSummary(requestId: String, summary: SmartSummary) async throws {
    try await summaryDoc(requestId).setData([
      "currentStatus": summary.currentStatus,
      "riskLevel": summary.riskLevel.rawValue,
      "totalCost": summary.totalCost,
      "nextAction": summary.nextAction,
      "updatedAt": Timestamp(date: summary.updatedAt)
    ])
    
    await MainActor.run {
      self.smartSummary = summary
    }
  }
  
  // MARK: - Thread Read/Activity Helpers
  
  /// Marks the issue thread as read for a specific user by updating a per-user timestamp
  /// at: maintenance_requests/{requestId}/thread_cache/reads
  func markThreadAsRead(requestId: String, userId: String) async {
    do {
      let ref = db.collection("maintenance_requests")
        .document(requestId)
        .collection("thread_cache")
        .document("reads")
      try await ref.setData([userId: Timestamp(date: Date())], merge: true)
      print("📖 [ThreadService] Marked thread as read for user \(userId) on request \(requestId)")
    } catch {
      print("⚠️ [ThreadService] Failed to mark thread as read for user \(userId) on \(requestId): \(error)")
    }
  }
  
  /// Batch fetch last-read timestamps for a user across multiple requests
  /// Returns a map of requestId -> lastReadAt date (if present)
  func getLastReadMap(userId: String, requestIds: [String]) async -> [String: Date] {
    var result: [String: Date] = [:]
    for requestId in requestIds {
      do {
        let doc = try await db.collection("maintenance_requests")
          .document(requestId)
          .collection("thread_cache")
          .document("reads")
          .getDocument()
        if let ts = doc.data()?[userId] as? Timestamp {
          result[requestId] = ts.dateValue()
        }
      } catch {
        print("⚠️ [ThreadService] Failed to fetch lastRead for user \(userId) on \(requestId): \(error)")
      }
    }
    return result
  }
  
  /// Batch fetch last activity timestamp for threads across multiple requests
  /// Returns a map of requestId -> lastActivityAt date (falls back to .distantPast if missing)
  func getThreadActivityMap(requestIds: [String]) async -> [String: Date] {
    var result: [String: Date] = [:]
    for requestId in requestIds {
      do {
        let doc = try await summaryDoc(requestId).getDocument()
        if let ts = (doc.data()? ["updatedAt"]) as? Timestamp {
          result[requestId] = ts.dateValue()
        }
      } catch {
        print("⚠️ [ThreadService] Failed to fetch thread activity for request \(requestId): \(error)")
      }
    }
    return result
  }
  
  // MARK: - Reply Management
  
  private func incrementReplyCount(requestId: String, parentMessageId: String) async throws {
    let parentRef = messagesCol(requestId).document(parentMessageId)
    
    // Use Firestore increment to atomically update reply count
    try await parentRef.updateData([
      "replyCount": FieldValue.increment(Int64(1))
    ])
    
    print("✅ [ThreadService] Incremented reply count for message: \(parentMessageId)")
  }
  
  // MARK: - Helpers
  
  private func parseMessage(doc: DocumentSnapshot) -> ThreadMessage? {
    let d = doc.data() ?? [:]
    
    guard let id = d["id"] as? String,
          let requestId = d["requestId"] as? String,
          let authorId = d["authorId"] as? String,
          let authorTypeRaw = d["authorType"] as? String,
          let authorType = ThreadAuthorType(rawValue: authorTypeRaw),
          let message = d["message"] as? String,
          let typeRaw = d["type"] as? String,
          let type = ThreadMessageType(rawValue: typeRaw),
          let createdAtTs = d["createdAt"] as? Timestamp else { return nil }
    
    let attachmentUrl = d["attachmentUrl"] as? String
    let attachmentThumbUrl = d["attachmentThumbUrl"] as? String
    
    // Parse status
    let status: MessageStatus? = {
      if let statusRaw = d["status"] as? String {
        return MessageStatus(rawValue: statusRaw)
      }
      return nil
    }()
    
    // Parse read receipts
    let readReceipts: [ReadReceipt]? = {
      guard let receiptsData = d["readReceipts"] as? [[String: Any]] else {
        print("📖 [ReadReceipt] No readReceipts field in message \(id)")
        return nil
      }
      print("📖 [ReadReceipt] Found \(receiptsData.count) receipts in message \(id)")
      let parsed: [ReadReceipt] = receiptsData.compactMap { receiptDict -> ReadReceipt? in
        guard let id = receiptDict["id"] as? String,
              let userId = receiptDict["userId"] as? String,
              let userName = receiptDict["userName"] as? String,
              let readAtTs = receiptDict["readAt"] as? Timestamp else {
          print("📖 [ReadReceipt] Failed to parse receipt: \(receiptDict)")
          return nil
        }
        print("📖 [ReadReceipt] Parsed receipt: \(userName) (\(userId))")
        return ReadReceipt(id: id, userId: userId, userName: userName, readAt: readAtTs.dateValue())
      }
      return parsed.isEmpty ? nil : parsed
    }()
    
    // Parse reactions
    let reactions: [MessageReaction]? = {
      guard let reactionsData = d["reactions"] as? [[String: Any]] else { return nil }
      return reactionsData.compactMap { reactionDict in
        guard let id = reactionDict["id"] as? String,
              let emoji = reactionDict["emoji"] as? String,
              let userId = reactionDict["userId"] as? String,
              let timestampTs = reactionDict["timestamp"] as? Timestamp else {
          return nil
        }
        return MessageReaction(id: id, emoji: emoji, userId: userId, timestamp: timestampTs.dateValue())
      }
    }()
    
    // Parse editedAt
    let editedAt: Date? = {
      if let editedAtTs = d["editedAt"] as? Timestamp {
        return editedAtTs.dateValue()
      }
      return nil
    }()
    
    return ThreadMessage(
      id: id,
      requestId: requestId,
      authorId: authorId,
      authorType: authorType,
      message: message,
      type: type,
      attachmentUrl: attachmentUrl,
      attachmentThumbUrl: attachmentThumbUrl,
      proposalAccepted: d["proposalAccepted"] as? Bool,
      parentMessageId: d["parentMessageId"] as? String,
      replyCount: d["replyCount"] as? Int,
      status: status,
      readReceipts: readReceipts,
      reactions: reactions,
      editedAt: editedAt,
      createdAt: createdAtTs.dateValue()
    )
  }
  
  private func parseSummary(data: [String: Any]) -> SmartSummary? {
    guard let currentStatus = data["currentStatus"] as? String,
          let riskLevelRaw = data["riskLevel"] as? String,
          let riskLevel = AIProposal.RiskLevel(rawValue: riskLevelRaw),
          let totalCost = data["totalCost"] as? Double,
          let nextAction = data["nextAction"] as? String,
          let updatedAtTs = data["updatedAt"] as? Timestamp else { return nil }
    
    return SmartSummary(
      currentStatus: currentStatus,
      riskLevel: riskLevel,
      totalCost: totalCost,
      nextAction: nextAction,
      updatedAt: updatedAtTs.dateValue()
    )
  }
  
  // MARK: - Push Notifications
  
  private func sendMessageNotifications(
    requestId: String,
    senderId: String,
    messageText: String,
    isReply: Bool
  ) async {
    do {
      // Fetch the issue to get reporter and title
      guard let issueDoc = try? await db.collection("maintenance_requests").document(requestId).getDocument(),
            issueDoc.exists,
            let issueData = issueDoc.data() else {
        print("⚠️ [ThreadService] Issue not found for notifications - skipping")
        return
      }
      
      let reporterId = issueData["reporterId"] as? String ?? ""
      let issueTitle = issueData["title"] as? String ?? "Issue"
      
      // Get sender's name
      let senderName = await getSenderName(senderId: senderId)
      
      // Get admin user IDs - use try? to prevent crashes
      guard let adminIds = try? await FirebaseClient.shared.getAdminUserIds(adminEmails: AdminConfig.adminEmails) else {
        print("⚠️ [ThreadService] Failed to get admin IDs - skipping notifications")
        return
      }
      
      // Build recipient list: admins + reporter, excluding sender
      var recipients = Set(adminIds)
      if !reporterId.isEmpty {
        recipients.insert(reporterId)
      }
      recipients.remove(senderId) // Don't notify the sender
      
      guard !recipients.isEmpty else {
        print("📭 [ThreadService] No recipients for notification")
        return
      }
      
      // Create notification
      let notificationTitle = isReply ? "New Reply" : "New Message"
      let notificationBody = "\(senderName): \(messageText)"
      
      print("🔔 [ThreadService] Sending notification to \(recipients.count) users")
      
      // Use try? to prevent crashes if notification fails
      try? await FirebaseClient.shared.sendNotificationTrigger(
        userIds: Array(recipients),
        title: notificationTitle,
        body: notificationBody,
        data: [
          "type": "thread_message",
          "requestId": requestId,
          "issueTitle": issueTitle
        ]
      )
      
      print("✅ [ThreadService] Notification sent successfully")
    } catch {
      print("❌ [ThreadService] Failed to send notification: \(error)")
    }
  }
  
  private func getSenderName(senderId: String) async -> String {
    // Check if it's AI
    if senderId == "ai" {
      return "Kevin AI"
    }
    
    // Try to fetch user from Firestore
    do {
      if let user = try await FirebaseClient.shared.fetchUser(userId: senderId) {
        // If admin, return first name only
        if let email = user.email, AdminConfig.isAdmin(email: email) {
          return user.name.components(separatedBy: " ").first ?? user.name
        }
        return user.name
      }
    } catch {
      print("⚠️ [ThreadService] Failed to fetch sender name: \(error)")
    }
    
    return "Someone"
  }
  
  // MARK: - Read Receipts
  
  func markMessageAsRead(requestId: String, messageId: String, userId: String, userName: String) async throws {
    let messageRef = messagesCol(requestId).document(messageId)
    
    let receipt = ReadReceipt(userId: userId, userName: userName)
    let receiptData: [String: Any] = [
      "id": receipt.id,
      "userId": receipt.userId,
      "userName": receipt.userName,
      "readAt": Timestamp(date: receipt.readAt)
    ]
    
    try await messageRef.updateData([
      "readReceipts": FieldValue.arrayUnion([receiptData])
    ])
    
    print("✅ [ThreadService] Marked message \(messageId) as read by \(userName)")
  }
  
  // Mark all messages in a thread as read
  func markAllMessagesAsRead(requestId: String, userId: String, userName: String) async throws {
    let snapshot = try await messagesCol(requestId).getDocuments()
    
    for doc in snapshot.documents {
      let data = doc.data()
      let authorId = data["authorId"] as? String ?? ""
      
      // Skip messages from the current user
      if authorId == userId {
        continue
      }
      
      // Check if already read
      if let receipts = data["readReceipts"] as? [[String: Any]] {
        let alreadyRead = receipts.contains { receipt in
          (receipt["userId"] as? String) == userId
        }
        if alreadyRead {
          continue
        }
      }
      
      // Mark as read
      try? await markMessageAsRead(requestId: requestId, messageId: doc.documentID, userId: userId, userName: userName)
    }
    
    print("✅ [ThreadService] Marked all messages as read for \(userName)")
  }
  
  // MARK: - Reactions
  
  func addReaction(requestId: String, messageId: String, emoji: String, userId: String) async throws {
    let messageRef = messagesCol(requestId).document(messageId)
    
    let reaction = MessageReaction(emoji: emoji, userId: userId)
    let reactionData: [String: Any] = [
      "id": reaction.id,
      "emoji": reaction.emoji,
      "userId": reaction.userId,
      "timestamp": Timestamp(date: reaction.timestamp)
    ]
    
    try await messageRef.updateData([
      "reactions": FieldValue.arrayUnion([reactionData])
    ])
    
    print("✅ [ThreadService] Added reaction \(emoji) to message \(messageId)")
  }
  
  func removeReaction(requestId: String, messageId: String, emoji: String, userId: String) async throws {
    let messageRef = messagesCol(requestId).document(messageId)
    let doc = try await messageRef.getDocument()
    
    guard let data = doc.data(),
          let reactions = data["reactions"] as? [[String: Any]] else {
      return
    }
    
    // Find and remove the specific reaction
    let updatedReactions = reactions.filter { reaction in
      let reactionUserId = reaction["userId"] as? String
      let reactionEmoji = reaction["emoji"] as? String
      return !(reactionUserId == userId && reactionEmoji == emoji)
    }
    
    try await messageRef.updateData([
      "reactions": updatedReactions
    ])
    
    print("✅ [ThreadService] Removed reaction \(emoji) from message \(messageId)")
  }
  
  // MARK: - Typing Indicators
  
  func setTypingIndicator(requestId: String, userId: String, userName: String, isTyping: Bool) async {
    let typingRef = db.collection("maintenance_requests")
      .document(requestId)
      .collection("typing_indicators")
      .document(userId)
    
    if isTyping {
      try? await typingRef.setData([
        "userId": userId,
        "userName": userName,
        "timestamp": Timestamp(date: Date())
      ])
    } else {
      try? await typingRef.delete()
    }
  }
  
  func listenToTypingIndicators(requestId: String, currentUserId: String, onUpdate: @escaping ([String]) -> Void) -> ListenerRegistration {
    return db.collection("maintenance_requests")
      .document(requestId)
      .collection("typing_indicators")
      .addSnapshotListener { snapshot, error in
        guard let documents = snapshot?.documents else { return }
        
        let typingUsers = documents.compactMap { doc -> String? in
          let data = doc.data()
          let userId = data["userId"] as? String
          let userName = data["userName"] as? String
          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()
          
          // Filter out current user and stale indicators (>10 seconds old)
          guard userId != currentUserId,
                let name = userName,
                let time = timestamp,
                Date().timeIntervalSince(time) < 10 else {
            return nil
          }
          
          return name
        }
        
        onUpdate(typingUsers)
      }
  }
}

