import SwiftUI

struct ChatView: View {
  let conversation: Conversation
  @EnvironmentObject var appState: AppState
  @ObservedObject private var messagingService = MessagingService.shared
  @State private var messageText = ""
  @State private var isLoading = true
  @State private var showingQuickReplies = false
  @State private var showingPhotoOptions = false
  @State private var showingIssueDetail = false
  @State private var issueForDetail: Issue?
  @Environment(\.dismiss) private var dismiss
  
  private var currentUser: AppUser? {
    appState.currentAppUser
  }
  
  private var isAdmin: Bool {
    currentUser?.role == .admin
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        VStack(spacing: 0) {
          // Issue Context Card (for issue-specific conversations)
          if conversation.type == .issue_specific {
            VStack(spacing: 0) {
              ExpandableIssueCard(conversation: conversation, startExpanded: true)
                .padding(.horizontal, 16)
                .padding(.top, 8)
              
              Divider()
                .background(KMTheme.border)
                .padding(.top, 12)
            }
          }
          
          // Messages List
          messagesScrollView
          
          // Message Input
          messageInputView
        }
      }
      .navigationTitle(chatTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(KMTheme.cardBackground, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          // Restaurant context for admins
          if isAdmin, let restaurantName = conversation.restaurantName {
            VStack(alignment: .trailing, spacing: 2) {
              Text(restaurantName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
              
              if let managerName = conversation.managerName {
                Text(managerName)
                  .font(.caption2)
                  .foregroundColor(KMTheme.secondaryText)
              }
            }
          }
        }
      }
      .onAppear {
        print("👁️ [ChatView] ===== CHAT VIEW APPEARED =====")
        print("👁️ [ChatView] Conversation ID: \(conversation.id)")
        print("👁️ [ChatView] Conversation type: \(conversation.type)")
        print("👁️ [ChatView] Conversation title: \(conversation.title ?? "nil")")
        print("👁️ [ChatView] Current user: \(currentUser?.name ?? "nil") (\(currentUser?.id ?? "nil"))")
        print("👁️ [ChatView] Is admin: \(isAdmin)")
        
        print("👁️ [ChatView] Starting message listener...")
        messagingService.startListeningToMessages(conversationId: conversation.id)
        
        print("👁️ [ChatView] Marking messages as read...")
        markMessagesAsRead()
        
        print("👁️ [ChatView] Chat view setup complete")
      }
      .onDisappear {
        print("👋 [ChatView] Chat view disappeared, stopping listeners")
        messagingService.stopListening()
      }
      .sheet(isPresented: $showingIssueDetail) {
        if let issue = issueForDetail {
          NavigationStack {
            IssueDetailView(issue: .constant(issue), onIssueUpdated: nil)
          }
        }
      }
    }
  }
  
  private var messagesScrollView: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(messagingService.currentMessages) { message in
            // Skip system messages for issue-specific conversations since we have the card
            if !(conversation.type == .issue_specific && message.type == .system) {
              MessageBubble(
                message: message,
                isCurrentUser: message.senderId == currentUser?.id
              )
              .id(message.id)
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
      }
      .onChange(of: messagingService.currentMessages.count) {
        // Auto-scroll to bottom when new messages arrive
        if let lastMessage = messagingService.currentMessages.last {
          withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
          }
        }
      }
    }
  }
  
  private var messageInputView: some View {
    VStack(spacing: 0) {
      // Quick Replies
      if showingQuickReplies {
        quickRepliesView
      }
      
      Divider()
        .background(KMTheme.border)
      
      VStack(spacing: 12) {
        // Main input row
        HStack(spacing: 12) {
          // Photo button
          Button(action: { showingPhotoOptions = true }) {
            Image(systemName: "camera")
              .font(.title3)
              .foregroundColor(KMTheme.accent)
          }
          
          // Message Text Field
          ZStack(alignment: .topLeading) {
            if messageText.isEmpty {
              Text("Type a message...")
                .foregroundColor(KMTheme.tertiaryText.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .allowsHitTesting(false)
            }
            
            TextField("", text: $messageText, axis: .vertical)
              .textFieldStyle(PlainTextFieldStyle())
              .foregroundColor(KMTheme.primaryText)
              .padding(.horizontal, 16)
              .padding(.vertical, 12)
              .lineLimit(1...4)
          }
          .background(KMTheme.background)
          .cornerRadius(20)
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(Color(red: 0.1, green: 0.2, blue: 0.4), lineWidth: 1)
          )
          
          // Send Button
          Button(action: sendMessage) {
            Image(systemName: "arrow.up.circle.fill")
              .font(.title2)
              .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? KMTheme.tertiaryText : KMTheme.accent)
          }
          .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        
        // Context indicators
        if conversation.type == .emergency {
          HStack {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.caption)
              .foregroundColor(KMTheme.danger)
            
            Text("Emergency conversation - Priority response")
              .font(.caption)
              .foregroundColor(KMTheme.danger)
            
            Spacer()
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(KMTheme.background)
    }
  }
  
  private func sendMessage() {
    print("💬 [ChatView] ===== SEND MESSAGE BUTTON TAPPED =====")
    
    let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    print("💬 [ChatView] Original message text: '\(messageText)'")
    print("💬 [ChatView] Trimmed message text: '\(trimmedMessage)'")
    print("💬 [ChatView] Message is empty: \(trimmedMessage.isEmpty)")
    
    guard !trimmedMessage.isEmpty else {
      print("❌ [ChatView] Message is empty, aborting send")
      return
    }
    
    guard let currentUser = currentUser else {
      print("❌ [ChatView] No current user available, aborting send")
      print("❌ [ChatView] AppState.currentAppUser: \(appState.currentAppUser?.id ?? "nil")")
      return
    }
    
    print("✅ [ChatView] Current user found: \(currentUser.name) (\(currentUser.id))")
    print("✅ [ChatView] User role: \(currentUser.role)")
    print("✅ [ChatView] User email: \(currentUser.email ?? "nil")")
    print("✅ [ChatView] Conversation ID: \(conversation.id)")
    print("✅ [ChatView] Conversation type: \(conversation.type)")
    print("✅ [ChatView] Conversation title: \(conversation.title ?? "nil")")
    
    let messageToSend = trimmedMessage
    let senderName = currentUser.name.isEmpty ? (currentUser.email ?? "Unknown") : currentUser.name
    
    print("✅ [ChatView] Final sender name: '\(senderName)'")
    print("✅ [ChatView] Final message content: '\(messageToSend)'")
    
    messageText = "" // Clear immediately for better UX
    print("✅ [ChatView] Cleared message text field")
    
    print("🚀 [ChatView] Starting async message send task...")
    Task {
      do {
        print("🚀 [ChatView] Calling MessagingService.sendMessage()...")
        try await messagingService.sendMessage(
          conversationId: conversation.id,
          content: messageToSend,
          senderId: currentUser.id,
          senderName: senderName,
          senderRole: currentUser.role
        )
        print("✅ [ChatView] Message sent successfully!")
      } catch {
        print("❌ [ChatView] ===== MESSAGE SEND FAILED =====")
        print("❌ [ChatView] Error: \(error)")
        print("❌ [ChatView] Error description: \(error.localizedDescription)")
        print("❌ [ChatView] Error code: \((error as NSError).code)")
        print("❌ [ChatView] Error domain: \((error as NSError).domain)")
        
        // Restore message text on error
        await MainActor.run {
          messageText = messageToSend
          print("🔄 [ChatView] Restored message text due to error")
        }
      }
    }
  }
  
  private var quickRepliesView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(getQuickReplies(), id: \.self) { reply in
          Button(reply) {
            messageText = reply
            showingQuickReplies = false
          }
          .font(.caption)
          .foregroundColor(KMTheme.accent)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(KMTheme.accent.opacity(0.1))
          .cornerRadius(16)
        }
      }
      .padding(.horizontal, 16)
    }
    .padding(.vertical, 8)
    .background(KMTheme.cardBackground)
  }
  
  private var chatTitle: String {
    if isAdmin, let restaurantName = conversation.restaurantName {
      return "\(restaurantName) - \(conversation.type.displayName)"
    }
    return conversation.title ?? conversation.type.displayName
  }
  
  private func getQuickReplies() -> [String] {
    guard let role = currentUser?.role else { return [] }
    return SmartReplyTemplate.getRepliesFor(role: role, conversationType: conversation.type)
  }
  
  private func markMessagesAsRead() {
    guard let currentUserId = currentUser?.id else {
      print("⚠️ [ChatView] Cannot mark messages as read - no current user ID")
      return
    }
    
    print("📖 [ChatView] Marking messages as read for user: \(currentUserId)")
    print("📖 [ChatView] Total messages to check: \(messagingService.currentMessages.count)")
    
    Task {
      var markedCount = 0
      for message in messagingService.currentMessages {
        if message.senderId != currentUserId && !message.readBy.keys.contains(currentUserId) {
          print("📖 [ChatView] Marking message \(message.id) as read")
          try? await messagingService.markMessageAsRead(
            messageId: message.id,
            conversationId: conversation.id,
            userId: currentUserId
          )
          markedCount += 1
        }
      }
      print("📖 [ChatView] Marked \(markedCount) messages as read")
    }
  }
  
  private func loadIssueForDetail() async {
    guard let issueId = conversation.issueId else { return }
    
    do {
      let issues = try await FirebaseClient.shared.fetchIssues()
      if let issue = issues.first(where: { $0.id == issueId }) {
        await MainActor.run {
          issueForDetail = issue
          showingIssueDetail = true
        }
      }
    } catch {
      print("Failed to load issue: \(error)")
    }
  }
}

struct MessageBubble: View {
  let message: Message
  let isCurrentUser: Bool
  
  private var bubbleColor: Color {
    if message.type == .system {
      return KMTheme.cardBackground
    }
    return isCurrentUser ? KMTheme.accent : KMTheme.cardBackground
  }
  
  private var textColor: Color {
    if message.type == .system {
      return KMTheme.secondaryText
    }
    return isCurrentUser ? KMTheme.surfaceBackground : KMTheme.primaryText
  }
  
  private var alignment: HorizontalAlignment {
    if message.type == .system {
      return .center
    }
    return isCurrentUser ? .trailing : .leading
  }
  
  var body: some View {
    VStack(alignment: alignment, spacing: 4) {
      if message.type == .system {
        systemMessageView
      } else {
        regularMessageView
      }
    }
  }
  
  private var systemMessageView: some View {
    VStack(spacing: 8) {
      Text(message.content)
        .font(.caption)
        .foregroundColor(KMTheme.secondaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
      
      Text(message.createdAt.formatted(.dateTime.hour().minute()))
        .font(.caption2)
        .foregroundColor(KMTheme.tertiaryText)
    }
  }
  
  private var regularMessageView: some View {
    HStack {
      if isCurrentUser {
        Spacer(minLength: 60)
      }
      
      VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
        // Sender name (only for other users)
        if !isCurrentUser {
          HStack {
            Text(message.senderName)
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(roleColor(message.senderRole))
            
            if message.senderRole == .admin {
              Image(systemName: "checkmark.seal.fill")
                .font(.caption2)
                .foregroundColor(KMTheme.accent)
            }
            
            Spacer()
          }
        }
        
        // Message content
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
          Text(message.content)
            .font(.body)
            .foregroundColor(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bubbleColor)
            .cornerRadius(18)
          
          // Timestamp
          Text(message.createdAt.formatted(.dateTime.hour().minute()))
            .font(.caption2)
            .foregroundColor(KMTheme.tertiaryText)
        }
      }
      
      if !isCurrentUser {
        Spacer(minLength: 60)
      }
    }
  }
  
  private func roleColor(_ role: Role) -> Color {
    switch role {
    case .admin: return KMTheme.accent
    case .owner: return KMTheme.warning
    case .gm: return KMTheme.success
    case .tech: return KMTheme.progress
    }
  }
}
