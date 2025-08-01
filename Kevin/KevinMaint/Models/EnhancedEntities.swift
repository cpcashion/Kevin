import Foundation
import FirebaseFirestore

// MARK: - Enhanced Issue Status Extensions
// Note: displayName is now defined in the main IssueStatus enum in Entities.swift

extension IssuePriority {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Activity Feed Entry Types
enum ActivityType: String, CaseIterable, Codable {
    case issueCreated = "issue_created"
    case statusChanged = "status_changed"
    case priorityChanged = "priority_changed"
    case update = "update"
    case message = "message"
    case photoAdded = "photo_added"
    case aiAnalysis = "ai_analysis"
    case assigned = "assigned"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .issueCreated: return "Issue Created"
        case .statusChanged: return "Status Changed"
        case .priorityChanged: return "Priority Changed"
        case .update: return "Update"
        case .message: return "Message"
        case .photoAdded: return "Photo Added"
        case .aiAnalysis: return "AI Analysis"
        case .assigned: return "Assigned"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .issueCreated: return "plus.circle"
        case .statusChanged: return "arrow.triangle.2.circlepath"
        case .priorityChanged: return "exclamationmark.triangle"
        case .update: return "pencil.circle"
        case .message: return "message.circle"
        case .photoAdded: return "camera.circle"
        case .aiAnalysis: return "brain"
        case .assigned: return "person.circle"
        case .completed: return "checkmark.circle"
        }
    }
    
    var tag: String {
        switch self {
        case .issueCreated: return "CREATED"
        case .statusChanged: return "STATUS"
        case .priorityChanged: return "PRIORITY"
        case .update: return "UPDATE"
        case .message: return "MESSAGE"
        case .photoAdded: return "PHOTO"
        case .aiAnalysis: return "AI"
        case .assigned: return "ASSIGNED"
        case .completed: return "DONE"
        }
    }
}

// MARK: - Activity Feed Entry
struct ActivityEntry: Identifiable, Codable {
    let id: String
    let type: ActivityType
    let content: String
    let authorId: String
    let authorName: String
    let authorInitials: String
    let timestamp: Date
    let metadata: [String: String]? // For additional data like old/new values
    
    init(
        id: String = UUID().uuidString,
        type: ActivityType,
        content: String,
        authorId: String,
        authorName: String,
        authorInitials: String,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.authorId = authorId
        self.authorName = authorName
        self.authorInitials = authorInitials
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    var isSystemEntry: Bool {
        return type == .aiAnalysis || type == .issueCreated
    }
    
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Enhanced Issue Model
struct EnhancedIssue: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let priority: IssuePriority
    let status: IssueStatus
    let locationId: String
    let restaurantId: String
    let reporterId: String
    let reporterName: String
    let assigneeId: String?
    let assigneeName: String?
    let photoURLs: [String]
    let aiAnalysis: String?
    let estimatedDuration: String?
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let activityFeed: [ActivityEntry]
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        priority: IssuePriority,
        status: IssueStatus = .reported,
        locationId: String,
        restaurantId: String,
        reporterId: String,
        reporterName: String,
        assigneeId: String? = nil,
        assigneeName: String? = nil,
        photoURLs: [String] = [],
        aiAnalysis: String? = nil,
        estimatedDuration: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        activityFeed: [ActivityEntry] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.status = status
        self.locationId = locationId
        self.restaurantId = restaurantId
        self.reporterId = reporterId
        self.reporterName = reporterName
        self.assigneeId = assigneeId
        self.assigneeName = assigneeName
        self.photoURLs = photoURLs
        self.aiAnalysis = aiAnalysis
        self.estimatedDuration = estimatedDuration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.activityFeed = activityFeed
    }
    
    // Progress tracking
    var progressSteps: [ProgressStep] {
        return [
            ProgressStep(
                title: "Reported",
                emoji: "📸",
                isCompleted: true,
                completedBy: reporterName
            ),
            ProgressStep(
                title: "Analyzed",
                emoji: "🔍",
                isCompleted: status != .reported,
                completedBy: status != .reported ? "AI Assistant" : nil
            ),
            ProgressStep(
                title: "Assigned",
                emoji: "🛠",
                isCompleted: assigneeId != nil,
                completedBy: assigneeName
            ),
            ProgressStep(
                title: "In Progress",
                emoji: "🚧",
                isCompleted: status == .in_progress || status == .completed,
                completedBy: status == .in_progress || status == .completed ? assigneeName : nil
            ),
            ProgressStep(
                title: "Completed",
                emoji: "✅",
                isCompleted: status == .completed,
                completedBy: status == .completed ? assigneeName : nil
            )
        ]
    }
    
    var sortedActivityFeed: [ActivityEntry] {
        return activityFeed.sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Progress Step
struct ProgressStep {
    let title: String
    let emoji: String
    let isCompleted: Bool
    let completedBy: String?
}

// MARK: - No Mock Data - Use Real Data Only
extension EnhancedIssue {
    static let mockEnhancedIssues: [EnhancedIssue] = []
}
