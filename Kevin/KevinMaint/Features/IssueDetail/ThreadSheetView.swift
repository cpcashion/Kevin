import SwiftUI

struct ThreadSheetView: View {
  let parentMessage: ThreadMessage
  let requestId: String
  let onSendReply: (String) -> Void
  let getUserDisplayName: (String) -> String
  
  @State private var replyText = ""
  @State private var typingUsers: [String] = []
  @State private var selectedMessageForReaction: ThreadMessage?
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState
  @StateObject private var threadService = ThreadService()
  
  private var typingIndicatorText: String? {
    guard !typingUsers.isEmpty else { return nil }
    if typingUsers.count == 1 {
      return "\(typingUsers[0]) is typing..."
    } else {
      return "\(typingUsers.count) people are typing..."
    }
  }
  
  // Computed property to filter replies from all messages
  // DISABLED: Filter out AI messages until UX is improved
  private var replies: [ThreadMessage] {
    threadService.messages
      .filter { $0.parentMessageId == parentMessage.id && $0.authorType != .ai }
      .sorted { $0.createdAt < $1.createdAt }
  }
  
  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Messages in chat bubble style
        ScrollView {
          VStack(spacing: 12) {
            // Parent message bubble
            ChatBubbleView(
              message: parentMessage.message,
              authorId: parentMessage.authorId,
              authorName: getUserDisplayName(parentMessage.authorId),
              timestamp: parentMessage.createdAt,
              isCurrentUser: isCurrentUser(parentMessage.authorId)
            )
            
            // Reply bubbles (real-time updates)
            ForEach(replies) { reply in
              EnhancedChatBubbleView(
                message: reply,
                authorName: getUserDisplayName(reply.authorId),
                isCurrentUser: isCurrentUser(reply.authorId),
                currentUserId: appState.currentAppUser?.id ?? "",
                onReaction: { emoji in
                  Task {
                    try? await threadService.addReaction(
                      requestId: requestId,
                      messageId: reply.id,
                      emoji: emoji,
                      userId: appState.currentAppUser?.id ?? ""
                    )
                  }
                },
                onRemoveReaction: { emoji in
                  Task {
                    try? await threadService.removeReaction(
                      requestId: requestId,
                      messageId: reply.id,
                      emoji: emoji,
                      userId: appState.currentAppUser?.id ?? ""
                    )
                  }
                }
              )
            }
            
            // Typing indicator
            if let typingText = typingIndicatorText {
              HStack {
                Text(typingText)
                  .font(.system(size: 13))
                  .foregroundColor(KMTheme.secondaryText)
                  .italic()
                Spacer()
              }
              .padding(.horizontal, 16)
              .padding(.top, 8)
            }
          }
          .padding(16)
        }
        .onAppear {
          startListeningToReplies()
          markMessagesAsRead()
        }
        .onDisappear {
          threadService.stopListening()
          stopTypingIndicator()
        }
        
        // Reply input
        VStack(spacing: 0) {
          Divider()
            .background(KMTheme.border)
          
          HStack(spacing: 12) {
            TextField("Add a reply...", text: $replyText, axis: .vertical)
              .textFieldStyle(PlainTextFieldStyle())
              .padding(.horizontal, 16)
              .padding(.vertical, 12)
              .background(KMTheme.background)
              .cornerRadius(20)
              .overlay(
                RoundedRectangle(cornerRadius: 20)
                  .stroke(KMTheme.border, lineWidth: 1)
              )
              .lineLimit(1...4)
              .onChange(of: replyText) { oldValue, newValue in
                handleTypingChange(oldValue: oldValue, newValue: newValue)
              }
            
            Button(action: sendReply) {
              Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundColor(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? KMTheme.tertiaryText : KMTheme.accent)
            }
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(KMTheme.cardBackground)
        }
      }
      .background(KMTheme.background)
      .navigationTitle("Thread")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
    }
  }
  
  private func sendReply() {
    let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    
    onSendReply(text)
    replyText = ""
    stopTypingIndicator()
    
    // Don't dismiss - allow user to send follow-up messages
  }
  
  private func startListeningToReplies() {
    // Start listening to all messages for this request
    threadService.startListening(requestId: requestId)
    
    // Start listening to typing indicators
    _ = threadService.listenToTypingIndicators(
      requestId: requestId,
      currentUserId: appState.currentAppUser?.id ?? ""
    ) { users in
      typingUsers = users
    }
  }
  
  private func markMessagesAsRead() {
    guard let userId = appState.currentAppUser?.id,
          let userName = appState.currentAppUser?.name else { return }
    
    Task {
      try? await threadService.markAllMessagesAsRead(
        requestId: requestId,
        userId: userId,
        userName: userName
      )
    }
  }
  
  private func handleTypingChange(oldValue: String, newValue: String) {
    guard let userId = appState.currentAppUser?.id,
          let userName = appState.currentAppUser?.name else { return }
    
    let isTyping = !newValue.isEmpty
    Task {
      await threadService.setTypingIndicator(
        requestId: requestId,
        userId: userId,
        userName: userName,
        isTyping: isTyping
      )
    }
  }
  
  private func stopTypingIndicator() {
    guard let userId = appState.currentAppUser?.id,
          let userName = appState.currentAppUser?.name else { return }
    
    Task {
      await threadService.setTypingIndicator(
        requestId: requestId,
        userId: userId,
        userName: userName,
        isTyping: false
      )
    }
  }
  
  private func isCurrentUser(_ authorId: String) -> Bool {
    return authorId == appState.currentAppUser?.id
  }
  
  private func formatRelativeTime(_ date: Date) -> String {
    let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: Date())
    if let day = components.day, day > 0 {
      return day == 1 ? "Yesterday" : (day < 7 ? "\(day)d ago" : date.formatted(date: .abbreviated, time: .omitted))
    } else if let hour = components.hour, hour > 0 {
      return "\(hour)h ago"
    } else if let minute = components.minute, minute > 0 {
      return "\(minute)m ago"
    }
    return "Just now"
  }
}

// MARK: - Chat Bubble Component

struct ChatBubbleView: View {
  let message: String
  let authorId: String
  let authorName: String
  let timestamp: Date
  let isCurrentUser: Bool
  
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
        
        // Message bubble
        Text(message)
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
        
        // Timestamp
        Text(formatRelativeTime(timestamp))
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
    let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: Date())
    if let day = components.day, day > 0 {
      return day == 1 ? "Yesterday" : (day < 7 ? "\(day)d ago" : date.formatted(date: .abbreviated, time: .omitted))
    } else if let hour = components.hour, hour > 0 {
      return "\(hour)h ago"
    } else if let minute = components.minute, minute > 0 {
      return "\(minute)m ago"
    }
    return "Just now"
  }
}
