import SwiftUI

struct MessagesView: View {
  @EnvironmentObject var appState: AppState
  @ObservedObject private var messagingService = MessagingService.shared
  @State private var showingNewConversation = false
  @State private var selectedConversation: Conversation?
  @State private var searchText = ""
  @State private var hasRunDiagnostic = false
  
  private var isAdmin: Bool {
    appState.currentAppUser?.role == .admin
  }
  
  private var filteredConversations: [Conversation] {
    if searchText.isEmpty {
      return messagingService.conversations
    }
    return messagingService.conversations.filter { conversation in
      conversation.title?.localizedCaseInsensitiveContains(searchText) == true
    }
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if messagingService.conversations.isEmpty {
          emptyStateView
        } else {
          conversationsList
        }
      }
      
      .navigationTitle("Messages")
      .navigationBarTitleDisplayMode(.inline)
      .kevinNavigationBarStyle()
      .background(KMTheme.background.ignoresSafeArea(edges: .bottom))
      .searchable(text: $searchText, prompt: "Search conversations...")
      .configureSearchBarAppearance()
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingNewConversation = true }) {
            Image(systemName: "plus.message")
              .foregroundColor(KMTheme.accent)
          }
        }
      }
      .sheet(isPresented: $showingNewConversation) {
        NewConversationView()
          .environmentObject(appState)
      }
      .sheet(item: $selectedConversation) { conversation in
        ChatView(conversation: conversation)
          .environmentObject(appState)
      }
      .onAppear {
        startListening()
        // Clear badge when user opens Messages tab (they're viewing notifications)
        NotificationService.shared.clearBadgeCount()
      }
      .onDisappear {
        messagingService.stopListening()
      }
    }
  }
  
  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "message.circle")
        .font(.system(size: 64))
        .foregroundColor(KMTheme.accent.opacity(0.5))
      
      VStack(spacing: 8) {
        Text("No Messages Yet")
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Text("Start a conversation with Kevin Maint support or about a specific issue")
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
          .multilineTextAlignment(.center)
      }
      
      Button(action: { showingNewConversation = true }) {
        HStack {
          Image(systemName: "plus.message")
          Text("Start New Conversation")
        }
        .font(.headline)
.foregroundColor(KMTheme.surfaceBackground)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(KMTheme.accent)
        .cornerRadius(12)
      }
    }
    .padding(40)
  }
  
  private var conversationsList: some View {
    List {
      ForEach(filteredConversations) { conversation in
        ConversationRow(conversation: conversation) {
          selectedConversation = conversation
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button("Delete") {
            print("🔥 [MessagesView] Delete swipe action tapped for conversation: \(conversation.id)")
            print("🔥 [MessagesView] - Title: \(conversation.title ?? "nil")")
            print("🔥 [MessagesView] - Type: \(conversation.type)")
            deleteConversation(conversation)
          }
          .tint(.red)
        }
      }
    }
    .listStyle(PlainListStyle())
    .scrollContentBackground(.hidden)
  }
  
  private func startListening() {
    print("🎧 [MessagesView] startListening() called")
    
    guard let currentUser = appState.currentAppUser else { 
      print("❌ [MessagesView] No current user, cannot start listening")
      return 
    }
    
    print("🎧 [MessagesView] Starting listener for user: \(currentUser.id)")
    print("🎧 [MessagesView] Is admin: \(isAdmin)")
    
    // SECURITY: Pass explicit admin status to prevent privacy leaks
    messagingService.startListeningToConversations(
      for: currentUser.id,
      isAdmin: isAdmin
    )
    
    print("🎧 [MessagesView] Listener started, current conversations: \(messagingService.conversations.count)")
  }
  
  private func deleteConversation(_ conversation: Conversation) {
    print("🔥 [MessagesView] deleteConversation called")
    print("🔥 [MessagesView] - Conversation ID: \(conversation.id)")
    print("🔥 [MessagesView] - Title: \(conversation.title ?? "nil")")
    
    Task {
      do {
        print("🔥 [MessagesView] Calling MessagingService.deleteConversation...")
        try await MessagingService.shared.deleteConversation(conversationId: conversation.id)
        print("✅ [MessagesView] Conversation deleted successfully")
      } catch {
        print("❌ [MessagesView] Failed to delete conversation: \(error)")
        print("❌ [MessagesView] Error details: \(error.localizedDescription)")
      }
    }
  }
}

struct ConversationRow: View {
  let conversation: Conversation
  let onTap: () -> Void
  @EnvironmentObject var appState: AppState
  
  private var isAdmin: Bool {
    appState.currentAppUser?.role == .admin
  }
  
  private var unreadCount: Int {
    guard let userId = appState.currentAppUser?.id else { return 0 }
    return conversation.unreadCount[userId] ?? 0
  }
  
  private var lastMessageTime: String {
    guard let lastMessageAt = conversation.lastMessageAt else {
      return conversation.createdAt.formatted(.dateTime.hour().minute())
    }
    
    let calendar = Calendar.current
    let now = Date()
    
    if calendar.isDate(lastMessageAt, inSameDayAs: now) {
      return lastMessageAt.formatted(.dateTime.hour().minute())
    } else if calendar.isDate(lastMessageAt, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
      return "Yesterday"
    } else {
      return lastMessageAt.formatted(.dateTime.month().day())
    }
  }
  
  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 0) {
        // Restaurant Context Header (for admins)
        if isAdmin, conversation.restaurantName != nil {
          restaurantContextHeader
        }
        
        HStack(spacing: 16) {
          // Conversation Icon
          ZStack {
            Circle()
              .fill(conversationColor.opacity(0.2))
              .frame(width: 50, height: 50)
            
            Image(systemName: conversation.type.icon)
              .font(.title3)
              .foregroundColor(conversationColor)
          }
        
          // Conversation Details
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(conversationTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
                .lineLimit(1)
              
              if conversation.priority == .high {
                Image(systemName: "exclamationmark.triangle.fill")
                  .font(.caption)
                  .foregroundColor(KMTheme.danger)
              }
              
              Spacer()
              
              Text(lastMessageTime)
                .font(.caption)
                .foregroundColor(KMTheme.tertiaryText)
            }
            
            HStack {
              // Conversation Type Badge
              Text(conversation.type.displayName)
                .font(.caption)
                .foregroundColor(conversationColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(conversationColor.opacity(0.1))
                .cornerRadius(4)
              
              // Context Info
              if let contextInfo = getContextInfo() {
                Text(contextInfo)
                  .font(.caption2)
                  .foregroundColor(KMTheme.tertiaryText)
                  .lineLimit(1)
              }
              
              Spacer()
              
              if unreadCount > 0 {
                Text("\(unreadCount)")
                  .font(.caption)
                  .fontWeight(.bold)
          .foregroundColor(KMTheme.surfaceBackground)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(KMTheme.accent)
                  .cornerRadius(10)
              }
            }
          }
        
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(KMTheme.tertiaryText)
        }
        .padding(16)
      }
      .background(KMTheme.cardBackground)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(borderColor, lineWidth: borderWidth)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private var restaurantContextHeader: some View {
    HStack(spacing: 8) {
      Image(systemName: "building.2")
        .font(.caption2)
        .foregroundColor(KMTheme.accent)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(conversation.restaurantName ?? "Unknown Restaurant")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        if let address = conversation.restaurantAddress {
          Text(address)
            .font(.caption2)
            .foregroundColor(KMTheme.secondaryText)
            .lineLimit(1)
        }
      }
      
      Spacer()
      
      if let managerName = conversation.managerName {
        HStack(spacing: 4) {
          Image(systemName: "person.circle")
            .font(.caption2)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(managerName)
            .font(.caption2)
            .foregroundColor(KMTheme.secondaryText)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(KMTheme.accent.opacity(0.05))
  }
  
  private var conversationColor: Color {
    switch conversation.type.color {
    case "danger": return KMTheme.danger
    case "warning": return KMTheme.warning
    case "success": return KMTheme.success
    case "aiGreen": return KMTheme.aiGreen
    default: return KMTheme.accent
    }
  }
  
  private var conversationTitle: String {
    if let title = conversation.title, !title.isEmpty {
      return title
    }
    
    switch conversation.type {
    case .emergency:
      return "Emergency Support"
    case .issue_specific:
      return "Issue Discussion"
    case .general:
      return "General Support"
    case .work_order:
      return "Work Order Updates"
    case .ai_review:
      return "AI Analysis Review"
    }
  }
  
  private var borderColor: Color {
    if conversation.priority == .high {
      return KMTheme.danger.opacity(0.5)
    } else if unreadCount > 0 {
      return KMTheme.accent.opacity(0.3)
    } else {
      return KMTheme.border
    }
  }
  
  private var borderWidth: CGFloat {
    if conversation.priority == .high {
      return 2
    } else if unreadCount > 0 {
      return 2
    } else {
      return 0.5
    }
  }
  
  private func getContextInfo() -> String? {
    if let contextData = conversation.contextData {
      if let issueType = contextData["issueType"] {
        return "Issue: \(issueType)"
      }
      if let workOrderStatus = contextData["workOrderStatus"] {
        return "Status: \(workOrderStatus)"
      }
    }
    return nil
  }
}

struct NewConversationView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.dismiss) private var dismiss
  @State private var selectedType: ConversationType = .issue_specific
  @State private var selectedIssue: Issue?
  @State private var availableIssues: [Issue] = []
  @State private var isCreating = false
  @State private var errorMessage: String?
  @State private var showingIssueSelection = false
  
  private var isAdmin: Bool {
    appState.currentAppUser?.role == .admin
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 24) {
            Text("Select an Issue to Discuss")
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(KMTheme.primaryText)
            
            issueSelectionButton
            
            if let errorMessage = errorMessage {
              Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
            }
            
            createButton
          }
          .padding(24)
        }
      }
      .navigationTitle("New Conversation")
      .navigationBarTitleDisplayMode(.inline)
      .kevinNavigationBarStyle()
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
      .task {
        await loadIssues()
      }
      .sheet(isPresented: $showingIssueSelection) {
        IssueSelectionSheet(
          availableIssues: availableIssues,
          selectedIssue: $selectedIssue
        )
        .environmentObject(appState)
      }
    }
  }
  
  
  private var issueSelectionButton: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Select Issue")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      Button(action: { showingIssueSelection = true }) {
        HStack(spacing: 12) {
          // Icon
          ZStack {
            Circle()
              .fill(selectedIssue != nil ? KMTheme.accent.opacity(0.2) : KMTheme.cardBackground)
              .frame(width: 40, height: 40)
            
            Image(systemName: selectedIssue != nil ? "checkmark.circle.fill" : "plus.circle")
              .font(.title3)
              .foregroundColor(selectedIssue != nil ? KMTheme.accent : KMTheme.secondaryText)
          }
          
          // Content
          VStack(alignment: .leading, spacing: 4) {
            if let issue = selectedIssue {
              Text(issue.title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
                .lineLimit(1)
              
              HStack {
                StatusPill(status: issue.status)
                
                Text(issue.priority.rawValue.capitalized)
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(priorityColorForIssue(issue.priority))
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(priorityColorForIssue(issue.priority).opacity(0.1))
                  .cornerRadius(4)
              }
            } else {
              Text(availableIssues.isEmpty ? "No issues available" : "Choose an issue to discuss")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(availableIssues.isEmpty ? KMTheme.secondaryText : KMTheme.primaryText)
              
              if !availableIssues.isEmpty {
                Text("\(availableIssues.count) active issue\(availableIssues.count == 1 ? "" : "s") available")
                  .font(.body)
                  .foregroundColor(KMTheme.secondaryText)
              }
            }
          }
          
          Spacer()
          
          // Arrow or count badge
          if availableIssues.isEmpty {
            Image(systemName: "exclamationmark.triangle")
              .font(.caption)
              .foregroundColor(KMTheme.warning)
          } else {
            HStack(spacing: 4) {
              if availableIssues.count > 0 {
                Text("\(availableIssues.count)")
                  .font(.caption)
                  .fontWeight(.bold)
          .foregroundColor(KMTheme.surfaceBackground)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(KMTheme.accent)
                  .cornerRadius(8)
              }
              
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(KMTheme.tertiaryText)
            }
          }
        }
        .padding(16)
        .background(selectedIssue != nil ? KMTheme.accent.opacity(0.05) : KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(selectedIssue != nil ? KMTheme.accent.opacity(0.3) : KMTheme.border, lineWidth: selectedIssue != nil ? 2 : 0.5)
        )
      }
      .buttonStyle(PlainButtonStyle())
      .disabled(availableIssues.isEmpty)
    }
  }
  
  private var createButton: some View {
    Button("Start Discussion") {
      print("🔥 [NewConversationView] Create Conversation button tapped!")
      print("🔥 [NewConversationView] - Type: \(selectedType)")
      print("🔥 [NewConversationView] - Selected issue: \(selectedIssue?.id ?? "nil")")
      createConversation()
    }
    .font(.headline)
    .fontWeight(.semibold)
    .foregroundColor(canCreate ? KMTheme.surfaceBackground : KMTheme.accent)
    .frame(maxWidth: .infinity)
    .padding(16)
    .background(canCreate ? KMTheme.accent : Color.clear)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.accent, lineWidth: canCreate ? 0 : 2)
    )
    .cornerRadius(12)
    .disabled(!canCreate || isCreating)
  }
  
  private var canCreate: Bool {
    return selectedIssue != nil
  }
  
  private func createConversation() {
    print("🔥 [NewConversationView] createConversation called")
    print("🔥 [NewConversationView] - Selected type: \(selectedType)")
    print("🔥 [NewConversationView] - Selected issue: \(selectedIssue?.id ?? "nil")")
    
    guard let currentUser = appState.currentAppUser,
          let userName = currentUser.name.isEmpty ? currentUser.email : currentUser.name else {
      print("❌ NewConversationView: No current user or name found")
      return
    }
    
    print("🔄 NewConversationView: Creating conversation")
    print("🔄 NewConversationView: - Type: \(selectedType)")
    print("🔄 NewConversationView: - User: \(userName)")
    print("🔄 NewConversationView: - User ID: \(currentUser.id)")
    
    isCreating = true
    errorMessage = nil
    
    Task {
      do {
        let conversation: Conversation
        
        print("🔥 [NewConversationView] Creating issue-specific conversation")
        print("🔥 [NewConversationView] - Selected issue: \(selectedIssue?.id ?? "nil")")
        print("🔥 [NewConversationView] - Available issues count: \(availableIssues.count)")
        
        guard let issue = selectedIssue else {
          print("❌ NewConversationView: No issue selected for issue conversation")
          print("❌ NewConversationView: Available issues: \(availableIssues.map { $0.id })")
          throw NSError(domain: "MessagingError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Please select an issue to start a discussion"])
        }
        
        print("🔧 NewConversationView: Creating issue conversation for issue: \(issue.id)")
        conversation = try await MessagingService.shared.createIssueConversation(
          for: issue,
          userId: currentUser.id,
          userName: userName
        )
        
        print("✅ NewConversationView: Conversation created successfully: \(conversation.id)")
        
        await MainActor.run {
          dismiss()
          // The conversation will appear in the list automatically due to the listener
        }
      } catch {
        print("❌ NewConversationView: Failed to create conversation: \(error)")
        print("❌ NewConversationView: Error code: \((error as NSError).code)")
        print("❌ NewConversationView: Error domain: \((error as NSError).domain)")
        
        await MainActor.run {
          errorMessage = error.localizedDescription
          isCreating = false
        }
      }
    }
  }
  
  private func loadIssues() async {
    do {
      let issues: [Issue]
      if appState.currentAppUser?.role == .admin {
        // Admin sees all issues
        issues = try await appState.firebaseClient.listIssues(restaurantId: nil)
        print("🔄 MessagesView: Admin loading all issues")
      } else if let restaurantId = appState.currentRestaurant?.id {
        // Restaurant owner sees only their restaurant's issues
        issues = try await appState.firebaseClient.listIssues(restaurantId: restaurantId)
        print("🔄 MessagesView: Loading issues for restaurantId: \(restaurantId)")
      } else {
        // No restaurant context - show only issues reported by current user
        let allIssues = try await appState.firebaseClient.listIssues(restaurantId: nil)
        issues = allIssues.filter { $0.reporterId == appState.currentAppUser?.id }
        print("👤 MessagesView: No restaurant context, showing \(issues.count) issues reported by current user")
      }
      print("✅ MessagesView: Loaded \(issues.count) total issues")
      
      await MainActor.run {
        // Only show active issues (not completed)
        let activeIssues = issues.filter { $0.status != .completed }
        print("📋 MessagesView: Filtered to \(activeIssues.count) active issues")
        self.availableIssues = activeIssues
      }
    } catch {
      print("❌ MessagesView: Failed to load issues: \(error)")
    }
  }
  
  private func priorityColorForIssue(_ priority: IssuePriority) -> Color {
    switch priority {
    case .low: return KMTheme.success
    case .medium: return KMTheme.warning
    case .high: return KMTheme.danger
    }
  }
}

struct ConversationTypeOption: View {
  let type: ConversationType
  let title: String
  let description: String
  let icon: String
  let isSelected: Bool
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 16) {
        ZStack {
          Circle()
            .fill(isSelected ? KMTheme.accent.opacity(0.2) : KMTheme.cardBackground)
            .frame(width: 50, height: 50)
          
          Image(systemName: icon)
            .font(.title3)
            .foregroundColor(isSelected ? KMTheme.accent : KMTheme.secondaryText)
        }
        
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          Text(description)
            .font(.body)
            .foregroundColor(KMTheme.secondaryText)
        }
        
        Spacer()
        
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.title2)
            .foregroundColor(KMTheme.accent)
        } else {
          Circle()
            .stroke(KMTheme.border, lineWidth: 2)
            .frame(width: 24, height: 24)
        }
      }
      .padding(16)
      .background(isSelected ? KMTheme.accent.opacity(0.05) : KMTheme.cardBackground)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? KMTheme.accent.opacity(0.3) : KMTheme.border, lineWidth: isSelected ? 2 : 0.5)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

struct IssueSelectionRow: View {
  let issue: Issue
  let isSelected: Bool
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(issue.title)
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
            .lineLimit(1)
          
          HStack {
            StatusPill(status: issue.status)
            
            Text(issue.priority.rawValue.capitalized)
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(priorityColor(issue.priority))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(priorityColor(issue.priority).opacity(0.1))
              .cornerRadius(4)
          }
        }
        
        Spacer()
        
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.title2)
            .foregroundColor(KMTheme.accent)
        } else {
          Circle()
            .stroke(KMTheme.border, lineWidth: 2)
            .frame(width: 24, height: 24)
        }
      }
      .padding(12)
      .background(isSelected ? KMTheme.accent.opacity(0.05) : KMTheme.cardBackground)
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isSelected ? KMTheme.accent.opacity(0.3) : KMTheme.border, lineWidth: isSelected ? 2 : 0.5)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private func priorityColor(_ priority: IssuePriority) -> Color {
    switch priority {
    case .low: return KMTheme.success
    case .medium: return KMTheme.warning
    case .high: return KMTheme.danger
    }
  }
}

struct IssueSelectionSheet: View {
  let availableIssues: [Issue]
  @Binding var selectedIssue: Issue?
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState
  @State private var searchText = ""
  @State private var selectedStatusFilter: IssueStatus? = nil
  
  private var filteredIssues: [Issue] {
    var issues = availableIssues
    
    // Apply search filter
    if !searchText.isEmpty {
      issues = issues.filter { issue in
        issue.title.localizedCaseInsensitiveContains(searchText) ||
        (issue.aiAnalysis?.category?.localizedCaseInsensitiveContains(searchText) ?? false)
      }
    }
    
    // Apply status filter
    if let statusFilter = selectedStatusFilter {
      issues = issues.filter { $0.status == statusFilter }
    }
    
    // Sort by priority (critical first) then by creation date (newest first)
    return issues.sorted { lhs, rhs in
      if lhs.priority != rhs.priority {
        return lhs.priority.sortOrder < rhs.priority.sortOrder
      }
      return lhs.createdAt > rhs.createdAt
    }
  }
  
  private var statusFilters: [IssueStatus] {
    let uniqueStatuses = Set(availableIssues.map { $0.status })
    let allStatuses: [IssueStatus] = [.reported, .in_progress, .completed]
    return allStatuses.filter { uniqueStatuses.contains($0) }
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        VStack(spacing: 0) {
          // Search and filters
          VStack(spacing: 16) {
            // Search bar
            HStack {
              Image(systemName: "magnifyingglass")
                .foregroundColor(KMTheme.secondaryText)
              
              TextField("Search issues...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(KMTheme.primaryText)
            }
            .padding(12)
            .background(KMTheme.cardBackground)
            .cornerRadius(10)
            
            // Status filters
            if statusFilters.count > 1 {
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                  FilterChip(
                    title: "All",
                    isSelected: selectedStatusFilter == nil
                  ) {
                    selectedStatusFilter = nil
                  }
                  
                  ForEach(statusFilters, id: \.self) { status in
                    FilterChip(
                      title: status.displayName,
                      isSelected: selectedStatusFilter == status
                    ) {
                      selectedStatusFilter = selectedStatusFilter == status ? nil : status
                    }
                  }
                }
                .padding(.horizontal, 24)
              }
            }
          }
          .padding(.horizontal, 24)
          .padding(.top, 16)
          
          // Issues list
          if filteredIssues.isEmpty {
            emptyStateView
          } else {
            issuesList
          }
        }
      }
      .navigationTitle("Select Issue")
      .navigationBarTitleDisplayMode(.inline)
      .kevinNavigationBarStyle()
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
        
        if selectedIssue != nil {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
              dismiss()
            }
            .foregroundColor(KMTheme.accent)
            .fontWeight(.semibold)
          }
        }
      }
    }
  }
  
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
        .font(.system(size: 48))
        .foregroundColor(KMTheme.secondaryText)
      
      VStack(spacing: 8) {
        Text(searchText.isEmpty ? "No Issues Available" : "No Matching Issues")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Text(searchText.isEmpty ? "Create an issue first to start a discussion" : "Try adjusting your search or filters")
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
          .multilineTextAlignment(.center)
      }
      
      if searchText.isEmpty {
        Button("Create New Issue") {
          // TODO: Navigate to create issue
          dismiss()
        }
        .font(.headline)
.foregroundColor(KMTheme.surfaceBackground)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(KMTheme.accent)
        .cornerRadius(12)
      }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  private var issuesList: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(filteredIssues) { issue in
          IssueSelectionCard(
            issue: issue,
            isSelected: selectedIssue?.id == issue.id
          ) {
            selectedIssue = issue
            dismiss()
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
    }
  }
}

struct FilterChip: View {
  let title: String
  let isSelected: Bool
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      Text(title)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(isSelected ? KMTheme.surfaceBackground : KMTheme.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? KMTheme.accent : KMTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(isSelected ? KMTheme.accent : KMTheme.border, lineWidth: 1)
        )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

struct IssueSelectionCard: View {
  let issue: Issue
  let isSelected: Bool
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 12) {
        // Header with title and selection indicator
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(issue.title)
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(KMTheme.primaryText)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
            
            if let category = issue.aiAnalysis?.category {
              Text("AI Detected: \(category)")
                .font(.caption)
                .foregroundColor(KMTheme.aiGreen)
            }
          }
          
          Spacer()
          
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .font(.title2)
              .foregroundColor(KMTheme.accent)
          } else {
            Circle()
              .stroke(KMTheme.border, lineWidth: 2)
              .frame(width: 24, height: 24)
          }
        }
        
        // Status and priority badges
        HStack {
          StatusPill(status: issue.status)
          
          Text(issue.priority.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(priorityColor(issue.priority))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor(issue.priority).opacity(0.1))
            .cornerRadius(4)
          
          Spacer()
          
          Text(issue.createdAt.formatted(.dateTime.month().day().hour().minute()))
            .font(.caption2)
            .foregroundColor(KMTheme.tertiaryText)
        }
        
        // Description preview
        if let description = issue.description, !description.isEmpty {
          Text(description)
            .font(.body)
            .foregroundColor(KMTheme.secondaryText)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
      }
      .padding(16)
      .background(isSelected ? KMTheme.accent.opacity(0.05) : KMTheme.cardBackground)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? KMTheme.accent.opacity(0.3) : KMTheme.border, lineWidth: isSelected ? 2 : 0.5)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private func priorityColor(_ priority: IssuePriority) -> Color {
    switch priority {
    case .low: return KMTheme.success
    case .medium: return KMTheme.warning
    case .high: return KMTheme.danger
    }
  }
}

// Extension to add sort order to IssuePriority
fileprivate extension IssuePriority {
  var sortOrder: Int {
    switch self {
    case .high: return 0
    case .medium: return 1
    case .low: return 2
    }
  }
}

// Extension removed - displayName now defined in EnhancedEntities.swift
