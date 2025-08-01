import SwiftUI

struct ActivityFeedView: View {
  @Environment(\.dismiss) var dismiss
  @StateObject private var historyService = NotificationHistoryService.shared
  @EnvironmentObject var appState: AppState
  
  @State private var selectedNotification: NotificationHistoryItem?
  @State private var navigateToIssueId: String?
  @State private var showingIssueDetail = false
  @State private var isRefreshing = false
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if historyService.recentNotifications.isEmpty {
          emptyState
        } else {
          notificationsList
        }
      }
      .navigationTitle("Activity")
      .navigationBarTitleDisplayMode(.large)
      .interactiveDismissDisabled(true) // Prevent swipe to dismiss
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            dismiss()
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
              Text("Close")
            }
          }
          .foregroundColor(KMTheme.accent)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          if !historyService.recentNotifications.isEmpty {
            Menu {
              Button {
                markAllAsRead()
              } label: {
                Label("Mark All as Read", systemImage: "checkmark.circle")
              }
              
              Button(role: .destructive) {
                clearAll()
              } label: {
                Label("Clear All", systemImage: "trash")
              }
            } label: {
              Image(systemName: "ellipsis.circle")
                .foregroundColor(KMTheme.accent)
            }
          }
        }
      }
    }
    .onAppear {
      // Mark all as read when view appears
      markAllAsRead()
    }
  }
  
  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "bell.slash")
        .font(.system(size: 60))
        .foregroundColor(KMTheme.tertiaryText)
      
      Text("No Notifications")
        .font(.title3)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      Text("You're all caught up! New notifications will appear here.")
        .font(.subheadline)
        .foregroundColor(KMTheme.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
  }
  
  private var notificationsList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        // Header with count
        HStack {
          Text("\(historyService.recentNotifications.count) Notification\(historyService.recentNotifications.count == 1 ? "" : "s")")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          Spacer()
          if historyService.unreadCount > 0 {
            Text("\(historyService.unreadCount) Unread")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundColor(KMTheme.accent)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(KMTheme.accent.opacity(0.1))
              .cornerRadius(8)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(KMTheme.background)
        
        Divider()
          .background(KMTheme.tertiaryText.opacity(0.2))
        
        ForEach(historyService.recentNotifications) { notification in
          NotificationRow(notification: notification) {
            handleNotificationTap(notification)
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
          
          if notification.id != historyService.recentNotifications.last?.id {
            Divider()
              .background(KMTheme.tertiaryText.opacity(0.1))
              .padding(.leading, 72)
          }
        }
      }
      .animation(.easeInOut(duration: 0.2), value: historyService.recentNotifications.count)
    }
    .refreshable {
      await refreshNotifications()
    }
  }
  
  private func handleNotificationTap(_ notification: NotificationHistoryItem) {
    // Haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    
    // Mark as read
    historyService.markAsRead(notification.id)
    
    // Navigate based on type
    if let issueId = notification.issueId {
      // Post notification to navigate to issue
      NotificationCenter.default.post(
        name: .navigateToIssue,
        object: nil,
        userInfo: ["issueId": issueId]
      )
      dismiss()
    } else if let conversationId = notification.conversationId {
      // Post notification to open conversation
      NotificationCenter.default.post(
        name: .openConversation,
        object: nil,
        userInfo: ["conversationId": conversationId]
      )
      dismiss()
    } else {
      // No navigation target - just mark as read and provide feedback
      let successGenerator = UINotificationFeedbackGenerator()
      successGenerator.notificationOccurred(.success)
    }
  }
  
  private func markAllAsRead() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    
    historyService.markAllAsRead()
    
    // Clear badge
    NotificationService.shared.clearBadgeCount()
  }
  
  private func clearAll() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.warning)
    
    historyService.clearHistory()
    NotificationService.shared.clearBadgeCount()
  }
  
  private func refreshNotifications() async {
    isRefreshing = true
    // Simulate refresh delay
    try? await Task.sleep(nanoseconds: 500_000_000)
    isRefreshing = false
  }
}

// MARK: - Notification Row

struct NotificationRow: View {
  let notification: NotificationHistoryItem
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 12) {
        // Icon
        ZStack {
          Circle()
            .fill(notification.type.color.opacity(notification.isRead ? 0.08 : 0.15))
            .frame(width: 44, height: 44)
          
          Image(systemName: notification.type.icon)
            .font(.system(size: 20, weight: notification.isRead ? .regular : .semibold))
            .foregroundColor(notification.type.color)
        }
        
        // Content
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            Text(notification.title)
              .font(.subheadline)
              .fontWeight(notification.isRead ? .regular : .semibold)
              .foregroundColor(KMTheme.primaryText)
              .lineLimit(2)
            
            Spacer()
            
            if !notification.isRead {
              Circle()
                .fill(KMTheme.accent)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            }
          }
          
          Text(notification.message)
            .font(.footnote)
            .foregroundColor(KMTheme.secondaryText)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
          
          HStack {
            Text(notification.displayTime)
              .font(.caption)
              .foregroundColor(KMTheme.tertiaryText)
            
            Spacer()
            
            Image(systemName: "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(KMTheme.tertiaryText.opacity(0.5))
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(
        Group {
          if !notification.isRead {
            KMTheme.cardBackground
          } else {
            KMTheme.background
          }
        }
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  ActivityFeedView()
    .environmentObject(AppState())
}
