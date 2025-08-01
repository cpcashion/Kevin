import Foundation
import SwiftUI

/// Service to track notification history for the activity feed
class NotificationHistoryService: ObservableObject {
  static let shared = NotificationHistoryService()
  
  @Published var recentNotifications: [NotificationHistoryItem] = []
  @Published var unreadCount: Int = 0
  
  private let maxHistoryItems = 50
  private let storageKey = "notificationHistory"
  
  private init() {
    loadHistory()
  }
  
  // MARK: - Add Notifications
  
  func addNotification(
    type: NotificationType,
    title: String,
    message: String,
    issueId: String? = nil,
    conversationId: String? = nil,
    metadata: [String: String]? = nil
  ) {
    let notification = NotificationHistoryItem(
      type: type,
      title: title,
      message: message,
      issueId: issueId,
      conversationId: conversationId,
      metadata: metadata,
      timestamp: Date(),
      isRead: false
    )
    
    DispatchQueue.main.async {
      self.recentNotifications.insert(notification, at: 0)
      
      // Keep only recent notifications
      if self.recentNotifications.count > self.maxHistoryItems {
        self.recentNotifications = Array(self.recentNotifications.prefix(self.maxHistoryItems))
      }
      
      self.updateUnreadCount()
      self.saveHistory()
      
      print("📝 [NotificationHistory] Added notification: \(title)")
      print("📝 [NotificationHistory] Total: \(self.recentNotifications.count), Unread: \(self.unreadCount)")
    }
  }
  
  // MARK: - Mark as Read
  
  func markAsRead(_ notificationId: String) {
    if let index = recentNotifications.firstIndex(where: { $0.id == notificationId }) {
      recentNotifications[index].isRead = true
      updateUnreadCount()
      saveHistory()
    }
  }
  
  func markAllAsRead() {
    for index in recentNotifications.indices {
      recentNotifications[index].isRead = true
    }
    updateUnreadCount()
    saveHistory()
    print("✅ [NotificationHistory] Marked all as read")
  }
  
  func clearHistory() {
    recentNotifications.removeAll()
    unreadCount = 0
    saveHistory()
    print("🗑️ [NotificationHistory] Cleared history")
  }
  
  // MARK: - Private Helpers
  
  private func updateUnreadCount() {
    unreadCount = recentNotifications.filter { !$0.isRead }.count
  }
  
  private func saveHistory() {
    do {
      let data = try JSONEncoder().encode(recentNotifications)
      UserDefaults.standard.set(data, forKey: storageKey)
    } catch {
      print("❌ [NotificationHistory] Failed to save history: \(error)")
    }
  }
  
  private func loadHistory() {
    guard let data = UserDefaults.standard.data(forKey: storageKey) else {
      print("📝 [NotificationHistory] No saved history found")
      return
    }
    
    do {
      recentNotifications = try JSONDecoder().decode([NotificationHistoryItem].self, from: data)
      updateUnreadCount()
      print("✅ [NotificationHistory] Loaded \(recentNotifications.count) notifications, \(unreadCount) unread")
    } catch {
      print("❌ [NotificationHistory] Failed to load history: \(error)")
    }
  }
}

// MARK: - Models

enum NotificationType: String, Codable {
  case issueCreated = "issue_created"
  case issueUpdated = "issue_updated"
  case statusChanged = "status_changed"
  case workUpdate = "work_update"
  case message = "message"
  case receiptStatus = "receipt_status"
  case urgentIssue = "urgent_issue"
  case issueAssigned = "issue_assigned"
  case quoteReceived = "quote_received"
  case invoiceReceived = "invoice_received"
  
  var icon: String {
    switch self {
    case .issueCreated: return "plus.circle.fill"
    case .issueUpdated: return "arrow.triangle.2.circlepath"
    case .statusChanged: return "arrow.triangle.2.circlepath"
    case .workUpdate: return "wrench.and.screwdriver.fill"
    case .message: return "message.fill"
    case .receiptStatus: return "receipt.fill"
    case .urgentIssue: return "exclamationmark.triangle.fill"
    case .issueAssigned: return "person.fill.checkmark"
    case .quoteReceived: return "dollarsign.circle.fill"
    case .invoiceReceived: return "doc.text.fill"
    }
  }
  
  var color: Color {
    switch self {
    case .issueCreated: return .green
    case .issueUpdated: return .blue
    case .statusChanged: return .blue
    case .workUpdate: return .orange
    case .issueAssigned: return .purple
    case .quoteReceived: return .green
    case .invoiceReceived: return .blue
    case .message: return .purple
    case .receiptStatus: return .teal
    case .urgentIssue: return .red
    }
  }
}

struct NotificationHistoryItem: Identifiable, Codable {
  let id: String
  let type: NotificationType
  let title: String
  let message: String
  let issueId: String?
  let conversationId: String?
  let metadata: [String: String]?
  let timestamp: Date
  var isRead: Bool
  
  init(
    id: String = UUID().uuidString,
    type: NotificationType,
    title: String,
    message: String,
    issueId: String? = nil,
    conversationId: String? = nil,
    metadata: [String: String]? = nil,
    timestamp: Date = Date(),
    isRead: Bool = false
  ) {
    self.id = id
    self.type = type
    self.title = title
    self.message = message
    self.issueId = issueId
    self.conversationId = conversationId
    self.metadata = metadata
    self.timestamp = timestamp
    self.isRead = isRead
  }
  
  var displayTime: String {
    let now = Date()
    let seconds = Int(now.timeIntervalSince(timestamp))
    
    if seconds < 60 {
      return "Just now"
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
