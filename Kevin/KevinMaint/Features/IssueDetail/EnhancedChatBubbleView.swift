import SwiftUI

struct EnhancedChatBubbleView: View {
  let message: ThreadMessage
  let authorName: String
  let isCurrentUser: Bool
  let currentUserId: String
  let onReaction: (String) -> Void
  let onRemoveReaction: (String) -> Void
  
  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      if isCurrentUser {
        Spacer(minLength: 60)
      }
      
      VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
        // Author name (only for others)
        if !isCurrentUser {
          Text(authorName)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(KMTheme.secondaryText)
            .padding(.leading, 12)
        }
        
        // Message bubble - clean and simple
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
          Text(message.message)
            .font(.system(size: 15))
            .foregroundColor(isCurrentUser ? .white : KMTheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isCurrentUser ? KMTheme.accent : KMTheme.cardBackground)
            .cornerRadius(18)
            .overlay(
              RoundedRectangle(cornerRadius: 18)
                .stroke(isCurrentUser ? Color.clear : KMTheme.border.opacity(0.3), lineWidth: 0.5)
            )
        }
        
        // Timestamp
        Text(formatRelativeTime(message.createdAt))
          .font(.system(size: 10))
          .foregroundColor(KMTheme.tertiaryText)
          .padding(.horizontal, 12)
      }
      
      if !isCurrentUser {
        Spacer(minLength: 60)
      }
    }
  }
  
  private func formatRelativeTime(_ date: Date) -> String {
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
