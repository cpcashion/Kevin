import SwiftUI

struct IssueThreadView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState
  @StateObject private var threadService = ThreadService.shared
  
  let request: MaintenanceRequest
  
  @State private var selectedTab: Tab = .chat
  @State private var messageText = ""
  @State private var showingAttachmentMenu = false
  @State private var showingImagePicker = false
  @State private var selectedAttachmentType: ThreadMessageType = .photo
  @State private var showingSummaryDetail = false
  @State private var typingUsers: [String] = []
  
  private var typingIndicatorText: String? {
    guard !typingUsers.isEmpty else { return nil }
    if typingUsers.count == 1 {
      return "\(typingUsers[0]) is typing..."
    } else {
      return "\(typingUsers.count) people are typing..."
    }
  }
  
  enum Tab: String, CaseIterable {
    case chat = "Chat"
    case timeline = "Timeline"
  }
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Smart Summary Bar
        smartSummaryBar
        
        // Tab Selector
        tabSelector
        
        // Content
        if selectedTab == .chat {
          chatView
        } else {
          timelineView
        }
        
        // Composer
        composer
      }
      .background(KMTheme.background)
      .navigationTitle(request.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Back") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button("Share Thread") { }
            Button("Export PDF") { }
            Button("Mute Notifications") { }
          } label: {
            Image(systemName: "ellipsis")
              .foregroundColor(KMTheme.primaryText)
          }
        }
      }
    }
    .onAppear {
      threadService.startListening(requestId: request.id)
      markMessagesAsRead()
      startTypingListener()
    }
    .onDisappear {
      threadService.stopListening()
      stopTypingIndicator()
    }
    .sheet(isPresented: $showingImagePicker) {
      SimpleImagePicker { image in
        Task {
          await sendAttachment(image: image)
        }
      }
    }
  }
  
  // MARK: - Smart Summary Bar
  
  private var smartSummaryBar: some View {
    Button(action: {
      showingSummaryDetail.toggle()
    }) {
      VStack(spacing: 4) {
        HStack(spacing: 8) {
          // Risk indicator
          Circle()
            .fill(Color(hex: threadService.smartSummary.riskLevel.color) ?? .orange)
            .frame(width: 6, height: 6)
          
          Text(threadService.smartSummary.currentStatus)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(KMTheme.primaryText)
            .lineLimit(1)
          
          Spacer()
          
          Image(systemName: showingSummaryDetail ? "chevron.up" : "chevron.down")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(KMTheme.secondaryText)
        }
        
        if !showingSummaryDetail {
          HStack(spacing: 12) {
            Text("Risk: \(threadService.smartSummary.riskLevel.rawValue.capitalized)")
              .font(.system(size: 11))
              .foregroundColor(KMTheme.secondaryText)
            
            Text("•")
              .foregroundColor(KMTheme.tertiaryText)
            
            Text("$\(Int(threadService.smartSummary.totalCost))")
              .font(.system(size: 11))
              .foregroundColor(KMTheme.secondaryText)
            
            Text("•")
              .foregroundColor(KMTheme.tertiaryText)
            
            Text(threadService.smartSummary.nextAction)
              .font(.system(size: 11))
              .foregroundColor(KMTheme.secondaryText)
              .lineLimit(1)
            
            Spacer()
          }
        }
        
        // Expanded summary detail
        if showingSummaryDetail {
          VStack(alignment: .leading, spacing: 8) {
            Divider()
              .background(KMTheme.border)
              .padding(.vertical, 4)
            
            summaryRow(label: "Risk Level", value: threadService.smartSummary.riskLevel.rawValue.capitalized)
            summaryRow(label: "Total Cost", value: "$\(Int(threadService.smartSummary.totalCost))")
            summaryRow(label: "Next Action", value: threadService.smartSummary.nextAction)
            summaryRow(label: "Updated", value: threadService.smartSummary.updatedAt.formatted(date: .abbreviated, time: .shortened))
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(KMTheme.cardBackground)
      .overlay(
        Rectangle()
          .frame(height: 1)
          .foregroundColor(KMTheme.border),
        alignment: .bottom
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private func summaryRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(KMTheme.secondaryText)
      Spacer()
      Text(value)
        .font(.system(size: 12))
        .foregroundColor(KMTheme.primaryText)
    }
  }
  
  // MARK: - Tab Selector
  
  private var tabSelector: some View {
    HStack(spacing: 0) {
      ForEach(Tab.allCases, id: \.self) { tab in
        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = tab
          }
        }) {
          VStack(spacing: 6) {
            Text(tab.rawValue)
              .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
              .foregroundColor(selectedTab == tab ? KMTheme.accent : KMTheme.secondaryText)
            
            Rectangle()
              .fill(selectedTab == tab ? KMTheme.accent : Color.clear)
              .frame(height: 2)
          }
        }
        .frame(maxWidth: .infinity)
      }
    }
    .frame(height: 44)
    .background(KMTheme.cardBackground)
    .overlay(
      Rectangle()
        .frame(height: 1)
        .foregroundColor(KMTheme.border),
      alignment: .bottom
    )
  }
  
  // MARK: - Chat View
  
  private var chatView: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 16) {
          ForEach(threadService.messages) { message in
            EnhancedChatBubbleView(
              message: message,
              authorName: getUserDisplayName(message.authorId),
              isCurrentUser: message.authorId == appState.currentAppUser?.id,
              currentUserId: appState.currentAppUser?.id ?? "",
              onReaction: { emoji in
                Task {
                  try? await threadService.addReaction(
                    requestId: request.id,
                    messageId: message.id,
                    emoji: emoji,
                    userId: appState.currentAppUser?.id ?? ""
                  )
                }
              },
              onRemoveReaction: { emoji in
                Task {
                  try? await threadService.removeReaction(
                    requestId: request.id,
                    messageId: message.id,
                    emoji: emoji,
                    userId: appState.currentAppUser?.id ?? ""
                  )
                }
              }
            )
            .id(message.id)
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
          }
          
          if threadService.messages.isEmpty {
            emptyState
          }
        }
        .padding(16)
      }
      .onChange(of: threadService.messages.count) { _ in
        if let lastMessage = threadService.messages.last {
          withAnimation {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
          }
        }
      }
    }
  }
  
  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 48))
        .foregroundColor(KMTheme.tertiaryText)
      
      Text("Start the conversation")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(KMTheme.primaryText)
      
      Text("Add a photo or message to begin")
        .font(.system(size: 14))
        .foregroundColor(KMTheme.secondaryText)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 60)
  }
  
  // MARK: - Timeline View
  
  private var timelineView: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        // TODO: Generate timeline events from messages
        Text("Timeline events will appear here")
          .font(.system(size: 14))
          .foregroundColor(KMTheme.secondaryText)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 60)
      }
      .padding(16)
    }
  }
  
  // MARK: - Composer
  
  private var composer: some View {
    VStack(spacing: 0) {
      Divider()
        .background(KMTheme.border)
      
      HStack(spacing: 12) {
        // Plus button
        Button(action: {
          showingAttachmentMenu.toggle()
        }) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(KMTheme.accent)
        }
        
        // Text field
        HStack {
          TextField("Type a message", text: $messageText)
            .font(.system(size: 15))
            .foregroundColor(KMTheme.primaryText)
            .accentColor(KMTheme.accent)
            .onChange(of: messageText) { oldValue, newValue in
              handleTypingChange(oldValue: oldValue, newValue: newValue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(KMTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(KMTheme.border, lineWidth: 1)
        )
        
        // Send button
        Button(action: {
          Task {
            await sendMessage()
          }
        }) {
          Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(messageText.isEmpty ? KMTheme.tertiaryText : KMTheme.accent)
        }
        .disabled(messageText.isEmpty)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(KMTheme.background)
    }
    .confirmationDialog("Add to thread", isPresented: $showingAttachmentMenu) {
      Button("Photo") {
        selectedAttachmentType = .photo
        showingImagePicker = true
      }
      Button("Receipt") {
        selectedAttachmentType = .receipt
        showingImagePicker = true
      }
      Button("Invoice") {
        selectedAttachmentType = .invoice
        showingImagePicker = true
      }
      Button("Cancel", role: .cancel) { }
    }
  }
  
  // MARK: - Actions
  
  private func sendMessage() async {
    guard !messageText.isEmpty,
          let userId = appState.currentAppUser?.id else { return }
    
    let text = messageText
    messageText = ""
    stopTypingIndicator()
    
    do {
      try await threadService.sendMessage(
        requestId: request.id,
        authorId: userId,
        message: text,
        type: .text
      )
    } catch {
      print("❌ Error sending message: \(error)")
    }
  }
  
  private func markMessagesAsRead() {
    guard let userId = appState.currentAppUser?.id,
          let userName = appState.currentAppUser?.name else {
      print("⚠️ [IssueThreadView] Cannot mark as read - no user ID or name")
      return
    }
    
    print("📖 [IssueThreadView] Marking messages as read for \(userName) (\(userId))")
    Task {
      do {
        try await threadService.markAllMessagesAsRead(
          requestId: request.id,
          userId: userId,
          userName: userName
        )
        print("✅ [IssueThreadView] Successfully marked messages as read")
      } catch {
        print("❌ [IssueThreadView] Failed to mark messages as read: \(error)")
      }
    }
  }
  
  private func startTypingListener() {
    guard let userId = appState.currentAppUser?.id else { return }
    
    _ = threadService.listenToTypingIndicators(
      requestId: request.id,
      currentUserId: userId
    ) { users in
      typingUsers = users
    }
  }
  
  private func handleTypingChange(oldValue: String, newValue: String) {
    guard let userId = appState.currentAppUser?.id,
          let userName = appState.currentAppUser?.name else { return }
    
    let isTyping = !newValue.isEmpty
    Task {
      await threadService.setTypingIndicator(
        requestId: request.id,
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
        requestId: request.id,
        userId: userId,
        userName: userName,
        isTyping: false
      )
    }
  }
  
  private func getQuickReplies() -> [QuickReply] {
    let userRole = appState.currentAppUser?.role == .admin ? "admin" : "owner"
    return QuickRepliesProvider.shared.suggestionsFor(
      issueStatus: request.status.rawValue,
      userRole: userRole
    )
  }
  
  private func getUserDisplayName(_ userId: String) -> String {
    if userId == "ai" {
      return "Kevin AI"
    }
    // Try to get from app state or return userId
    return appState.currentAppUser?.name ?? "User"
  }
  
  private func sendAttachment(image: UIImage) async {
    guard let userId = appState.currentAppUser?.id else { return }
    
    do {
      let message = selectedAttachmentType == .photo ? "Added photo" :
                    selectedAttachmentType == .receipt ? "Added receipt" :
                    "Added invoice"
      
      try await threadService.sendMessageWithAttachment(
        requestId: request.id,
        authorId: userId,
        message: message,
        type: selectedAttachmentType,
        image: image
      )
    } catch {
      print("❌ Error sending attachment: \(error)")
    }
  }
}

// MARK: - Message Bubble

struct ThreadMessageBubble: View {
  let message: ThreadMessage
  let currentUserId: String
  
  @State private var showingImageViewer = false
  
  private var isCurrentUser: Bool {
    message.authorId == currentUserId
  }
  
  private var isAI: Bool {
    message.authorType == .ai
  }
  
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      if !isCurrentUser {
        // Avatar
        Circle()
          .fill(isAI ? (Color(hex: "#10B981") ?? .green) : KMTheme.accent.opacity(0.2))
          .frame(width: 32, height: 32)
          .overlay(
            Image(systemName: isAI ? "brain.head.profile" : "person.fill")
              .font(.system(size: 14))
              .foregroundColor(isAI ? .white : KMTheme.accent)
          )
      }
      
      VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
        // Message content
        VStack(alignment: .leading, spacing: 8) {
          if let attachmentUrl = message.attachmentUrl {
            AsyncImage(url: URL(string: attachmentUrl)) { image in
              image
                .resizable()
                .aspectRatio(contentMode: .fill)
            } placeholder: {
              Rectangle()
                .fill(KMTheme.borderSecondary)
                .overlay(ProgressView())
            }
            .frame(width: 200, height: 200)
            .cornerRadius(8)
            .clipped()
            .onTapGesture {
              showingImageViewer = true
            }
          }
          
          if !message.message.isEmpty {
            Text(message.message)
              .font(.system(size: 15))
              .foregroundColor(isCurrentUser ? .white : KMTheme.primaryText)
          }
          
          // AI Proposal Card
          if let proposal = message.aiProposal, message.proposalAccepted == nil {
            AIProposalCard(message: message, proposal: proposal)
          }
        }
        .padding(12)
        .background(isCurrentUser ? KMTheme.accent : KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(isCurrentUser ? Color.clear : KMTheme.border, lineWidth: 1)
        )
        
        // Timestamp
        Text(message.createdAt.formatted(date: .omitted, time: .shortened))
          .font(.system(size: 11))
          .foregroundColor(KMTheme.tertiaryText)
      }
      .frame(maxWidth: 280, alignment: isCurrentUser ? .trailing : .leading)
      
      if isCurrentUser {
        Spacer()
      }
    }
    .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
  }
}

// MARK: - AI Proposal Card

struct AIProposalCard: View {
  let message: ThreadMessage
  let proposal: AIProposal
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Proposed Changes")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(KMTheme.secondaryText)
      
      if let status = proposal.proposedStatus {
        proposalRow(label: "Status", value: status.rawValue.capitalized)
      }
      
      if let priority = proposal.proposedPriority {
        proposalRow(label: "Priority", value: priority.rawValue.capitalized)
      }
      
      if let cost = proposal.extractedCost {
        proposalRow(label: "Cost", value: "$\(Int(cost))")
      }
      
      Text(proposal.reasoning)
        .font(.system(size: 12))
        .foregroundColor(KMTheme.secondaryText)
        .padding(.top, 4)
      
      HStack(spacing: 8) {
        Button(action: {
          Task {
            try? await ThreadService.shared.acceptProposal(requestId: message.requestId, messageId: message.id)
          }
        }) {
          Text("Accept")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(KMTheme.accent)
            .cornerRadius(6)
        }
        
        Button(action: {
          // TODO: Show edit sheet
        }) {
          Text("Edit")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(KMTheme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(KMTheme.accent.opacity(0.1))
            .cornerRadius(6)
        }
        
        Button(action: {
          Task {
            try? await ThreadService.shared.dismissProposal(requestId: message.requestId, messageId: message.id)
          }
        }) {
          Text("Dismiss")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(KMTheme.secondaryText)
        }
      }
      .padding(.top, 4)
    }
    .padding(12)
    .background(KMTheme.background.opacity(0.5))
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke((Color(hex: "#10B981") ?? .green).opacity(0.3), lineWidth: 1)
    )
  }
  
  private func proposalRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 12))
        .foregroundColor(KMTheme.tertiaryText)
      Image(systemName: "arrow.right")
        .font(.system(size: 10))
        .foregroundColor(KMTheme.tertiaryText)
      Text(value)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(KMTheme.primaryText)
    }
  }
}
