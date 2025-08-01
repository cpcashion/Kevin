import Foundation

// MARK: - Work Order Context Models

/// Comprehensive context for a work order that the AI agent uses
struct WorkOrderContext: Codable {
    let workOrderId: String
    let locationId: String
    let locationName: String
    let reporterId: String
    let reporterName: String
    let reporterRole: String
    
    var events: [ContextEvent]
    var aiAnalyses: [AIContextAnalysis]
    var detectedIntents: [UserIntent]
    var businessState: BusinessState
    
    var createdAt: Date
    var updatedAt: Date
    
    /// Generate a comprehensive context summary for AI
    func generateContextSummary() -> String {
        var summary = """
        WORK ORDER CONTEXT:
        - Location: \(locationName)
        - Reporter: \(reporterName) (\(reporterRole))
        - Status: \(businessState.currentStatus)
        - Created: \(formatDate(createdAt))
        
        """
        
        // Add timeline
        if !events.isEmpty {
            summary += "\nTIMELINE:\n"
            for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
                summary += "  * \(formatTime(event.timestamp)) - \(event.summary)\n"
            }
        }
        
        // Add detected intents
        if !detectedIntents.isEmpty {
            summary += "\nDETECTED INTENTS:\n"
            for intent in detectedIntents {
                let status = intent.fulfilled ? "✓" : "○"
                summary += "  \(status) \(intent.type.rawValue)"
                if let details = intent.details {
                    summary += ": \(details)"
                }
                summary += "\n"
            }
        }
        
        // Add business context
        summary += "\nBUSINESS CONTEXT:\n"
        if let estimatedCost = businessState.estimatedCost {
            summary += "  - Estimated Cost: $\(String(format: "%.2f", estimatedCost))\n"
        }
        if let quoteAmount = businessState.quoteAmount {
            summary += "  - Quote Amount: $\(String(format: "%.2f", quoteAmount))\n"
        }
        if !businessState.suggestedActions.isEmpty {
            summary += "  - Suggested Actions: \(businessState.suggestedActions.joined(separator: ", "))\n"
        }
        
        return summary
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Individual events in the work order timeline
struct ContextEvent: Codable, Identifiable {
    let id: String
    let type: EventType
    let timestamp: Date
    let userId: String
    let userName: String
    let summary: String
    let details: [String: String]?
    
    enum EventType: String, Codable {
        case photoUploaded = "photo_uploaded"
        case voiceNoteAdded = "voice_note_added"
        case statusChanged = "status_changed"
        case messageSent = "message_sent"
        case aiAnalysisCompleted = "ai_analysis_completed"
        case quoteRequested = "quote_requested"
        case quoteGenerated = "quote_generated"
        case quoteSent = "quote_sent"
        case workScheduled = "work_scheduled"
        case workCompleted = "work_completed"
        case receiptUploaded = "receipt_uploaded"
    }
}

/// AI analysis results stored in context
struct AIContextAnalysis: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let type: AnalysisType
    let summary: String
    let extractedData: [String: String]
    let confidence: Double
    
    enum AnalysisType: String, Codable {
        case photoAnalysis = "photo_analysis"
        case voiceTranscription = "voice_transcription"
        case intentDetection = "intent_detection"
        case costEstimation = "cost_estimation"
        case receiptAnalysis = "receipt_analysis"
    }
}

/// User intents detected from messages and voice notes
struct UserIntent: Codable, Identifiable {
    let id: String
    let type: IntentType
    let confidence: Double
    let detectedAt: Date
    let details: String?
    var fulfilled: Bool
    var fulfilledAt: Date?
    
    enum IntentType: String, Codable {
        case requestQuote = "request_quote"
        case requestScheduling = "request_scheduling"
        case reportUrgency = "report_urgency"
        case askQuestion = "ask_question"
        case provideBudget = "provide_budget"
        case requestCallback = "request_callback"
        case approveQuote = "approve_quote"
        case rejectQuote = "reject_quote"
    }
}

/// Business logic state for the work order
struct BusinessState: Codable {
    var currentStatus: String
    var estimatedCost: Double?
    var quoteAmount: Double?
    var quoteGenerated: Bool
    var quoteSent: Bool
    var quoteApproved: Bool?
    var scheduledDate: Date?
    var completedDate: Date?
    var suggestedActions: [String]
    
    init() {
        self.currentStatus = "reported"
        self.quoteGenerated = false
        self.quoteSent = false
        self.suggestedActions = []
    }
}

// MARK: - AI Agent Message Models

/// Message in the AI agent conversation
struct AIAgentMessage: Codable, Identifiable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    let metadata: [String: String]?
    
    enum MessageRole: String, Codable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
}

/// Action that the AI agent can execute
struct AIAgentAction: Codable, Identifiable {
    let id: String
    let type: ActionType
    let parameters: [String: String]
    let requiresConfirmation: Bool
    var confirmed: Bool
    var executed: Bool
    var result: String?
    
    enum ActionType: String, Codable {
        case createQuote = "create_quote"
        case sendQuote = "send_quote"
        case scheduleWork = "schedule_work"
        case sendMessage = "send_message"
        case updateStatus = "update_status"
        case estimateCost = "estimate_cost"
        case generateInvoice = "generate_invoice"
    }
}

/// Proactive suggestion from the AI agent
struct AIAgentSuggestion: Identifiable {
    let id: String
    let title: String
    let description: String
    let actionType: AIAgentAction.ActionType
    let parameters: [String: String]
    let priority: SuggestionPriority
    
    enum SuggestionPriority {
        case high
        case medium
        case low
    }
}
