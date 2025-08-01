import Foundation

// MARK: - Thread Message Types

enum ThreadMessageType: String, Codable {
  case text
  case status_change
  case photo
  case receipt
  case invoice
  case voice
  case system
  
  var icon: String {
    switch self {
    case .text: return "text.bubble"
    case .status_change: return "arrow.triangle.2.circlepath"
    case .photo: return "photo"
    case .receipt: return "doc.text"
    case .invoice: return "doc.plaintext"
    case .voice: return "waveform"
    case .system: return "gear"
    }
  }
}

enum ThreadAuthorType: String, Codable {
  case user
  case ai
  case system
}

// MARK: - AI Proposal

struct AIProposal: Codable {
  var proposedStatus: RequestStatus?
  var proposedPriority: MaintenancePriority?
  var extractedCost: Double?
  var extractedVendor: String?
  var extractedInvoiceNumber: String?
  var nextAction: String?
  var riskLevel: RiskLevel?
  var confidence: Double // 0.0 to 1.0
  var reasoning: String // Brief explanation
  
  enum RiskLevel: String, Codable {
    case low, medium, high
    
    var color: String {
      switch self {
      case .low: return "#10B981"
      case .medium: return "#F59E0B"
      case .high: return "#EF4444"
      }
    }
  }
}

// MARK: - Message Status

enum MessageStatus: String, Codable {
  case sending
  case sent
  case delivered
  case read
  case failed
  
  var icon: String {
    switch self {
    case .sending: return "circle.dotted"
    case .sent: return "checkmark"
    case .delivered: return "checkmark.circle"
    case .read: return "checkmark.circle.fill"
    case .failed: return "exclamationmark.circle"
    }
  }
}

// MARK: - Message Reaction

struct MessageReaction: Codable, Identifiable {
  let id: String
  let emoji: String
  let userId: String
  let timestamp: Date
  
  init(id: String = UUID().uuidString, emoji: String, userId: String, timestamp: Date = Date()) {
    self.id = id
    self.emoji = emoji
    self.userId = userId
    self.timestamp = timestamp
  }
}

// MARK: - Read Receipt

struct ReadReceipt: Codable, Identifiable {
  let id: String
  let userId: String
  let userName: String
  let readAt: Date
  
  init(id: String = UUID().uuidString, userId: String, userName: String, readAt: Date = Date()) {
    self.id = id
    self.userId = userId
    self.userName = userName
    self.readAt = readAt
  }
}

// MARK: - Thread Message

struct ThreadMessage: Identifiable, Codable {
  let id: String
  let requestId: String
  let authorId: String
  let authorType: ThreadAuthorType
  var message: String
  var type: ThreadMessageType
  var attachmentUrl: String?
  var attachmentThumbUrl: String?
  var aiProposal: AIProposal?
  var proposalAccepted: Bool? // nil = pending, true = accepted, false = dismissed
  var parentMessageId: String? // For threaded replies
  var replyCount: Int? // Number of direct replies
  var status: MessageStatus? // Message delivery status
  var readReceipts: [ReadReceipt]? // Who has read this message
  var reactions: [MessageReaction]? // Emoji reactions
  var editedAt: Date? // When message was last edited
  let createdAt: Date
  
  init(
    id: String = UUID().uuidString,
    requestId: String,
    authorId: String,
    authorType: ThreadAuthorType,
    message: String,
    type: ThreadMessageType = .text,
    attachmentUrl: String? = nil,
    attachmentThumbUrl: String? = nil,
    aiProposal: AIProposal? = nil,
    proposalAccepted: Bool? = nil,
    parentMessageId: String? = nil,
    replyCount: Int? = nil,
    status: MessageStatus? = nil,
    readReceipts: [ReadReceipt]? = nil,
    reactions: [MessageReaction]? = nil,
    editedAt: Date? = nil,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.requestId = requestId
    self.authorId = authorId
    self.authorType = authorType
    self.message = message
    self.type = type
    self.attachmentUrl = attachmentUrl
    self.attachmentThumbUrl = attachmentThumbUrl
    self.aiProposal = aiProposal
    self.proposalAccepted = proposalAccepted
    self.parentMessageId = parentMessageId
    self.replyCount = replyCount
    self.status = status
    self.readReceipts = readReceipts
    self.reactions = reactions
    self.editedAt = editedAt
    self.createdAt = createdAt
  }
  
  // Helper to check if this is a reply
  var isReply: Bool {
    return parentMessageId != nil
  }
  
  // Helper to check if this has replies
  var hasReplies: Bool {
    return (replyCount ?? 0) > 0
  }
  
  // Helper to check if message has been read by specific user
  func isReadBy(userId: String) -> Bool {
    return readReceipts?.contains(where: { $0.userId == userId }) ?? false
  }
  
  // Helper to get read receipt for specific user
  func readReceiptFor(userId: String) -> ReadReceipt? {
    return readReceipts?.first(where: { $0.userId == userId })
  }
  
  // Helper to get all readers except author
  var otherReaders: [ReadReceipt] {
    return readReceipts?.filter { $0.userId != authorId } ?? []
  }
  
  // Helper to format read receipt text
  var readReceiptText: String? {
    let readers = otherReaders
    guard !readers.isEmpty else { return nil }
    
    if readers.count == 1 {
      let reader = readers[0]
      let timeAgo = formatTimeAgo(reader.readAt)
      return "Seen by \(reader.userName) \(timeAgo)"
    } else {
      return "Seen by \(readers.count) people"
    }
  }
  
  // Helper to get reaction count for emoji
  func reactionCount(for emoji: String) -> Int {
    return reactions?.filter { $0.emoji == emoji }.count ?? 0
  }
  
  // Helper to check if user reacted with emoji
  func userReacted(userId: String, emoji: String) -> Bool {
    return reactions?.contains(where: { $0.userId == userId && $0.emoji == emoji }) ?? false
  }
  
  // Helper to get grouped reactions
  var groupedReactions: [(emoji: String, count: Int, userIds: [String])] {
    guard let reactions = reactions, !reactions.isEmpty else { return [] }
    
    let grouped = Dictionary(grouping: reactions, by: { $0.emoji })
    return grouped.map { (emoji, reactions) in
      (emoji: emoji, count: reactions.count, userIds: reactions.map { $0.userId })
    }.sorted { $0.count > $1.count }
  }
  
  // Helper to format time ago
  private func formatTimeAgo(_ date: Date) -> String {
    let seconds = Int(Date().timeIntervalSince(date))
    
    if seconds < 60 {
      return "just now"
    } else if seconds < 3600 {
      let minutes = seconds / 60
      return "\(minutes)m ago"
    } else if seconds < 86400 {
      let hours = seconds / 3600
      return "\(hours)h ago"
    } else {
      let days = seconds / 86400
      return "\(days)d ago"
    }
  }
}

// MARK: - Smart Summary

struct SmartSummary: Codable {
  var currentStatus: String // "Waiting on plumber ETA"
  var riskLevel: AIProposal.RiskLevel
  var totalCost: Double
  var nextAction: String
  var updatedAt: Date
  
  static var empty: SmartSummary {
    SmartSummary(
      currentStatus: "Issue reported",
      riskLevel: .low,
      totalCost: 0,
      nextAction: "Add details to begin analysis",
      updatedAt: Date()
    )
  }
}

// MARK: - AIProposal Extensions

extension AIProposal {
  func toDictionary() throws -> [String: Any] {
    var dict: [String: Any] = [
      "confidence": confidence,
      "reasoning": reasoning
    ]
    
    if let riskLevel = riskLevel {
      dict["riskLevel"] = riskLevel.rawValue
    }
    
    if let proposedStatus = proposedStatus {
      dict["proposedStatus"] = proposedStatus.rawValue
    }
    
    if let proposedPriority = proposedPriority {
      dict["proposedPriority"] = proposedPriority.rawValue
    }
    
    if let extractedCost = extractedCost {
      dict["extractedCost"] = extractedCost
    }
    
    if let extractedVendor = extractedVendor {
      dict["extractedVendor"] = extractedVendor
    }
    
    if let extractedInvoiceNumber = extractedInvoiceNumber {
      dict["extractedInvoiceNumber"] = extractedInvoiceNumber
    }
    
    if let nextAction = nextAction {
      dict["nextAction"] = nextAction
    }
    
    return dict
  }
}

// MARK: - Timeline Event

struct TimelineEvent: Identifiable {
  let id: String
  let type: TimelineEventType
  let title: String
  let bullets: [String]
  let timestamp: Date
  let sourceMessageId: String?
  let metadata: [String: String]
  
  enum TimelineEventType: String {
    case analysis
    case status_change
    case assignment
    case cost_logged
    case document_parsed
    case progress_update
    case blocker
    case note
    case resolution
    
    var icon: String {
      switch self {
      case .analysis: return "brain.head.profile"
      case .status_change: return "flag.fill"
      case .assignment: return "person.fill"
      case .cost_logged: return "dollarsign.circle.fill"
      case .document_parsed: return "doc.text.fill"
      case .progress_update: return "chart.line.uptrend.xyaxis"
      case .blocker: return "exclamationmark.triangle.fill"
      case .note: return "note.text"
      case .resolution: return "checkmark.circle.fill"
      }
    }
    
    var color: String {
      switch self {
      case .analysis: return "#10B981"
      case .status_change: return "#3B82F6"
      case .assignment: return "#8B5CF6"
      case .cost_logged: return "#F59E0B"
      case .document_parsed: return "#06B6D4"
      case .progress_update: return "#3B82F6"
      case .blocker: return "#EF4444"
      case .note: return "#6B7280"
      case .resolution: return "#10B981"
      }
    }
  }
}
