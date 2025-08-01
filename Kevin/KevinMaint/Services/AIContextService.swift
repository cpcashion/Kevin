import Foundation
import FirebaseFirestore

/// Service for building and maintaining AI context for work orders
class AIContextService: ObservableObject {
    static let shared = AIContextService()
    
    private let db = Firestore.firestore()
    private var contextCache: [String: WorkOrderContext] = [:]
    
    private init() {}
    
    // MARK: - Context Building
    
    /// Build comprehensive context for a work order
    func buildContext(for issue: Issue) async throws -> WorkOrderContext {
        print("🧠 Building AI context for issue: \(issue.id)")
        
        // Check cache first
        if let cached = contextCache[issue.id] {
            print("✅ Using cached context")
            return cached
        }
        
        // Fetch all related data
        async let workLogs = fetchWorkLogs(for: issue.id)
        async let photos = fetchPhotos(for: issue.id)
        async let messages = fetchMessages(for: issue.id)
        async let aiAnalyses = fetchAIAnalyses(for: issue.id)
        
        let (logs, photosList, messagesList, analyses) = try await (workLogs, photos, messages, aiAnalyses)
        
        // Build events timeline
        var events: [ContextEvent] = []
        
        // Add issue creation event
        events.append(ContextEvent(
            id: UUID().uuidString,
            type: .photoUploaded,
            timestamp: issue.createdAt,
            userId: issue.reporterId,
            userName: "Reporter",
            summary: "Issue reported: \(issue.title)",
            details: issue.description.map { ["description": $0] }
        ))
        
        // Add photo events
        for photo in photosList {
            events.append(ContextEvent(
                id: photo.id,
                type: .photoUploaded,
                timestamp: photo.takenAt,
                userId: issue.reporterId,
                userName: "User",
                summary: "Photo uploaded",
                details: nil
            ))
        }
        
        // Add work log events
        for log in logs {
            events.append(ContextEvent(
                id: log.id,
                type: .statusChanged,
                timestamp: log.createdAt,
                userId: log.authorId,
                userName: "User",
                summary: log.message,
                details: nil
            ))
        }
        
        // Add message events
        for message in messagesList {
            let eventType: ContextEvent.EventType = message.type == .voice ? .voiceNoteAdded : .messageSent
            events.append(ContextEvent(
                id: message.id,
                type: eventType,
                timestamp: message.timestamp,
                userId: message.senderId,
                userName: message.senderName,
                summary: message.type == .voice ? "Voice note added" : "Message sent",
                details: ["content": message.content]
            ))
        }
        
        // Detect intents from messages and voice notes
        let intents = await detectIntents(from: messagesList, issue: issue)
        
        // Build business state
        var businessState = BusinessState()
        businessState.currentStatus = issue.status.rawValue
        businessState.estimatedCost = extractEstimatedCost(from: analyses)
        businessState.quoteGenerated = false // TODO: Check if quote exists
        businessState.suggestedActions = generateSuggestedActions(issue: issue, intents: intents)
        
        // Create context
        let context = WorkOrderContext(
            workOrderId: issue.id,
            locationId: issue.restaurantId,
            locationName: "Location",
            reporterId: issue.reporterId,
            reporterName: "Reporter",
            reporterRole: "Owner", // TODO: Fetch from user data
            events: events.sorted(by: { $0.timestamp < $1.timestamp }),
            aiAnalyses: analyses,
            detectedIntents: intents,
            businessState: businessState,
            createdAt: issue.createdAt,
            updatedAt: Date()
        )
        
        // Cache the context
        contextCache[issue.id] = context
        
        // Store in Firestore
        try await storeContext(context)
        
        print("✅ Context built successfully with \(events.count) events and \(intents.count) intents")
        
        return context
    }
    
    /// Update context when new events occur
    func updateContext(for issueId: String, with event: ContextEvent) async throws {
        guard var context = contextCache[issueId] else {
            print("⚠️ No cached context found for issue: \(issueId)")
            return
        }
        
        // Add new event
        context.events.append(event)
        context.updatedAt = Date()
        
        // Re-detect intents if it's a message event
        if event.type == .messageSent || event.type == .voiceNoteAdded {
            // TODO: Re-analyze intents
        }
        
        // Update cache
        contextCache[issueId] = context
        
        // Store in Firestore
        try await storeContext(context)
        
        print("✅ Context updated with new event: \(event.type.rawValue)")
    }
    
    // MARK: - Intent Detection
    
    private func detectIntents(from messages: [Message], issue: Issue) async -> [UserIntent] {
        var intents: [UserIntent] = []
        
        for message in messages {
            let content = (message.content ?? "").lowercased()
            
            // Detect quote request
            if content.contains("quote") || content.contains("estimate") || content.contains("how much") || content.contains("cost") {
                intents.append(UserIntent(
                    id: UUID().uuidString,
                    type: .requestQuote,
                    confidence: 0.85,
                    detectedAt: message.timestamp,
                    details: "Quote requested in message",
                    fulfilled: false
                ))
            }
            
            // Detect urgency
            if content.contains("urgent") || content.contains("asap") || content.contains("emergency") || content.contains("immediately") {
                intents.append(UserIntent(
                    id: UUID().uuidString,
                    type: .reportUrgency,
                    confidence: 0.9,
                    detectedAt: message.timestamp,
                    details: "Urgent request detected",
                    fulfilled: false
                ))
            }
            
            // Detect scheduling request
            if content.contains("schedule") || content.contains("when can") || content.contains("appointment") || content.contains("come by") {
                intents.append(UserIntent(
                    id: UUID().uuidString,
                    type: .requestScheduling,
                    confidence: 0.8,
                    detectedAt: message.timestamp,
                    details: "Scheduling request detected",
                    fulfilled: false
                ))
            }
            
            // Detect budget mention
            if content.contains("budget") || content.contains("$") || content.contains("afford") {
                intents.append(UserIntent(
                    id: UUID().uuidString,
                    type: .provideBudget,
                    confidence: 0.75,
                    detectedAt: message.timestamp,
                    details: "Budget information provided",
                    fulfilled: false
                ))
            }
            
            // Detect callback request
            if content.contains("call me") || content.contains("call back") || content.contains("phone") {
                intents.append(UserIntent(
                    id: UUID().uuidString,
                    type: .requestCallback,
                    confidence: 0.8,
                    detectedAt: message.timestamp,
                    details: "Callback requested",
                    fulfilled: false
                ))
            }
        }
        
        // Check issue description for intents
        let description = (issue.description ?? "").lowercased()
        if description.contains("quote") || description.contains("estimate") {
            intents.append(UserIntent(
                id: UUID().uuidString,
                type: .requestQuote,
                confidence: 0.7,
                detectedAt: issue.createdAt,
                details: "Quote mentioned in issue description",
                fulfilled: false
            ))
        }
        
        return intents
    }
    
    private func extractEstimatedCost(from analyses: [AIContextAnalysis]) -> Double? {
        // Look for cost estimation in AI analyses
        for analysis in analyses {
            if analysis.type == .costEstimation,
               let costString = analysis.extractedData["estimated_cost"],
               let cost = Double(costString) {
                return cost
            }
        }
        // Also check if there's an estimated cost in the extracted data
        if let firstAnalysis = analyses.first,
           let costString = firstAnalysis.extractedData["estimated_cost"] {
            // Try to extract number from string like "$250-350"
            let numbers = costString.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Double($0) }
            return numbers.first
        }
        return nil
    }
    
    private func generateSuggestedActions(issue: Issue, intents: [UserIntent]) -> [String] {
        var actions: [String] = []
        
        // Suggest quote if requested
        if intents.contains(where: { $0.type == .requestQuote && !$0.fulfilled }) {
            actions.append("Create and send quote")
        }
        
        // Suggest scheduling if quote approved
        if issue.status == .in_progress {
            actions.append("Schedule work appointment")
        }
        
        // Suggest status update
        if issue.status == .reported {
            actions.append("Update status to in progress")
        }
        
        return actions
    }
    
    // MARK: - Data Fetching
    
    private func fetchWorkLogs(for issueId: String) async throws -> [WorkLog] {
        let snapshot = try await db.collection("workLogs")
            .whereField("issueId", isEqualTo: issueId)
            .order(by: "timestamp", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: WorkLog.self)
        }
    }
    
    private func fetchPhotos(for issueId: String) async throws -> [IssuePhoto] {
        let snapshot = try await db.collection("issuePhotos")
            .whereField("issueId", isEqualTo: issueId)
            .order(by: "uploadedAt", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: IssuePhoto.self)
        }
    }
    
    private func fetchMessages(for issueId: String) async throws -> [Message] {
        // Find conversation for this issue
        let conversationSnapshot = try await db.collection("conversations")
            .whereField("issueId", isEqualTo: issueId)
            .limit(to: 1)
            .getDocuments()
        
        guard let conversationId = conversationSnapshot.documents.first?.documentID else {
            return []
        }
        
        let messagesSnapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .getDocuments()
        
        return messagesSnapshot.documents.compactMap { doc in
            try? doc.data(as: Message.self)
        }
    }
    
    private func fetchAIAnalyses(for issueId: String) async throws -> [AIContextAnalysis] {
        // Fetch AI analysis from issue document
        let issueDoc = try await db.collection("issues").document(issueId).getDocument()
        
        guard let issue = try? issueDoc.data(as: Issue.self),
              let aiAnalysis = issue.aiAnalysis else {
            return []
        }
        
        // Convert to context analysis
        let analysis = AIContextAnalysis(
            id: UUID().uuidString,
            timestamp: issue.createdAt,
            type: .photoAnalysis,
            summary: aiAnalysis.summary ?? aiAnalysis.description,
            extractedData: [
                "description": aiAnalysis.description,
                "category": aiAnalysis.category ?? "",
                "priority": aiAnalysis.priority,
                "estimated_time": aiAnalysis.timeToComplete ?? ""
            ],
            confidence: aiAnalysis.confidence ?? 0.0
        )
        
        return [analysis]
    }
    
    // MARK: - Firestore Storage
    
    private func storeContext(_ context: WorkOrderContext) async throws {
        let data = try Firestore.Encoder().encode(context)
        
        try await db.collection("workOrders")
            .document(context.workOrderId)
            .collection("aiContext")
            .document("current")
            .setData(data)
        
        print("💾 Context stored in Firestore")
    }
    
    /// Fetch stored context from Firestore
    func fetchStoredContext(for issueId: String) async throws -> WorkOrderContext? {
        let doc = try await db.collection("workOrders")
            .document(issueId)
            .collection("aiContext")
            .document("current")
            .getDocument()
        
        guard doc.exists else {
            return nil
        }
        
        return try doc.data(as: WorkOrderContext.self)
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        contextCache.removeAll()
        print("🗑️ Context cache cleared")
    }
    
    func clearCache(for issueId: String) {
        contextCache.removeValue(forKey: issueId)
        print("🗑️ Context cache cleared for issue: \(issueId)")
    }
}
