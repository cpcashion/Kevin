import SwiftUI

struct AddWorkUpdateView: View {
  let issueId: String
  let issueTitle: String
  let restaurantName: String
  let onWorkLogAdded: (WorkLog) -> Void
  
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState
  @State private var message = ""
  @State private var voiceNote = ""
  @State private var isSubmitting = false
  @State private var errorMessage: String?
  
  private var hasContent: Bool {
    !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
    !voiceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 16) {
          Text("Add Work Update")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.primaryText)
          
          Text("Share progress, notes, or updates about this maintenance issue.")
            .font(.body)
            .foregroundColor(KMTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        VStack(alignment: .leading, spacing: 12) {
          Text("Update Message")
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
          
          ZStack(alignment: .topLeading) {
            TextEditor(text: $message)
              .font(.body)
              .foregroundColor(KMTheme.primaryText)
              .scrollContentBackground(.hidden)
              .background(Color.clear)
              .padding(16)
              .frame(minHeight: 120)
              .overlay(
                Group {
                  if message.isEmpty {
                    HStack {
                      Text("I'm working on it...")
                        .foregroundColor(KMTheme.tertiaryText.opacity(0.6))
                        .font(.body)
                        .padding(.leading, 20)
                        .padding(.top, 24)
                      Spacer()
                    }
                  }
                },
                alignment: .topLeading
              )
          }
          .background(KMTheme.cardBackground)
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(KMTheme.border, lineWidth: 1)
          )
        }
        
        // Voice Note section temporarily removed - will be replaced with new unified component
        
        if let errorMessage = errorMessage {
          Text(errorMessage)
            .font(.caption)
            .foregroundColor(KMTheme.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        Spacer()
        
        VStack(spacing: 12) {
          Button(action: submitUpdate) {
            HStack {
              if isSubmitting {
                ProgressView()
                  .scaleEffect(0.8)
                  .tint(.white)
              } else {
                Text("Add Update")
                  .fontWeight(.medium)
              }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(hasContent ? KMTheme.accent : KMTheme.borderSecondary)
            .foregroundColor(.white)
            .cornerRadius(12)
          }
          .disabled(!hasContent || isSubmitting)
          
          Button("Cancel") {
            dismiss()
          }
          .frame(maxWidth: .infinity)
          .padding(16)
          .background(KMTheme.cardBackground)
          .foregroundColor(KMTheme.accent)
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(KMTheme.accent, lineWidth: 1)
          )
        }
      }
      .padding(24)
      .background(KMTheme.background)
      .navigationBarHidden(true)
    }
  }
  
  private func submitUpdate() {
    guard hasContent else { return }
    
    isSubmitting = true
    errorMessage = nil
    
    Task {
      do {
        // First, get or create a work order for this issue
        let workOrderId = try await getOrCreateWorkOrder()
        
        // Combine message and voice note
        var finalMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let voiceText = voiceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !voiceText.isEmpty {
          if !finalMessage.isEmpty {
            finalMessage += "\n\n🎤 Voice Note: \(voiceText)"
          } else {
            finalMessage = "🎤 Voice Note: \(voiceText)"
          }
        }
        
        let workLog = WorkLog(
          id: UUID().uuidString,
          issueId: issueId,
          authorId: appState.currentAppUser?.id ?? "DEMO_USER",
          message: finalMessage,
          createdAt: Date()
        )
        
        try await FirebaseClient.shared.addWorkLog(workLog)
        
        // NOTIFICATION: Send work update notification
        await sendWorkUpdateNotification(workLog: workLog)
        
        await MainActor.run {
          onWorkLogAdded(workLog)
          dismiss()
        }
      } catch {
        await MainActor.run {
          errorMessage = "Failed to add update: \(error.localizedDescription)"
          isSubmitting = false
        }
      }
    }
  }
  
  private func getOrCreateWorkOrder() async throws -> String {
    // Check if work order already exists for this issue
    let workOrders = try await FirebaseClient.shared.fetchWorkOrders()
    
    if let existingWorkOrder = workOrders.first(where: { $0.issueId == issueId }) {
      return existingWorkOrder.id
    }
    
    // Create new work order
    let workOrder = WorkOrder(
      id: UUID().uuidString,
      restaurantId: "demo_restaurant", // TODO: Get from current restaurant context
      issueId: issueId,
      assigneeId: "DEMO_USER",
      status: .scheduled,
      scheduledAt: Date(),
      startedAt: nil,
      completedAt: nil,
      estimatedCost: nil,
      actualCost: nil,
      notes: nil,
      createdAt: Date()
    )
    
    try await FirebaseClient.shared.createWorkOrder(workOrder)
    return workOrder.id
  }
  
  // MARK: - Notification Functions
  
  private func sendWorkUpdateNotification(workLog: WorkLog) async {
    guard let currentUser = appState.currentAppUser else { return }
    
    // Get all relevant users to notify
    var userIdsToNotify: [String] = []
    
    // Try to get the issue to find the reporter
    do {
      let issue = try await FirebaseClient.shared.getIssue(issueId: issueId)
      // Notify the issue reporter (if different from current user)
      if issue.reporterId != currentUser.id {
        userIdsToNotify.append(issue.reporterId)
        print("🔔 Added issue reporter to notifications: \(issue.reporterId)")
      }
    } catch {
      print("⚠️ Could not fetch issue for reporter notification: \(error)")
    }
    
    // Notify admins
    let adminUserIds = await getAdminUserIds()
    userIdsToNotify.append(contentsOf: adminUserIds.filter { $0 != currentUser.id })
    
    // Remove duplicates
    userIdsToNotify = Array(Set(userIdsToNotify))
    
    guard !userIdsToNotify.isEmpty else {
      print("🔔 No users to notify for work update")
      return
    }
    
    // Determine update type based on message content
    let updateType: String
    let messageContent = workLog.message.lowercased()
    if messageContent.contains("photo") || messageContent.contains("image") || messageContent.contains("picture") {
      updateType = "photos"
    } else if messageContent.contains("complete") || messageContent.contains("finished") || messageContent.contains("done") {
      updateType = "completion"
    } else {
      updateType = "progress"
    }
    
    // Send notification
    await NotificationService.shared.sendWorkUpdateNotification(
      to: userIdsToNotify,
      issueTitle: issueTitle,
      restaurantName: restaurantName,
      updateType: updateType,
      issueId: issueId,
      updatedBy: currentUser.name
    )
  }
  
  private func getAdminUserIds() async -> [String] {
    do {
      // Get admin users from Firebase based on admin emails
      let adminEmails = AdminConfig.adminEmails
      let adminUserIds = try await FirebaseClient.shared.getAdminUserIds(adminEmails: adminEmails)
      
      print("🔔 Found \(adminUserIds.count) admin users: \(adminUserIds)")
      
      // If no admin users found, try to get all users with admin emails as fallback
      if adminUserIds.isEmpty {
        print("⚠️ No admin users found via query, using fallback approach")
        return try await getAdminUserIdsFallback()
      }
      
      return adminUserIds
    } catch {
      print("❌ Failed to get admin user IDs: \(error)")
      // Fallback approach
      return await getAdminUserIdsFallback()
    }
  }
  
  private func getAdminUserIdsFallback() async -> [String] {
    // Try to find users by checking if any current users have admin emails
    // This is a more permissive approach for notification delivery
    var fallbackIds: [String] = []
    
    do {
      // Get all users and filter by admin emails
      let allUsers = try await FirebaseClient.shared.getAllUsers()
      for user in allUsers {
        if let email = user.email, AdminConfig.adminEmails.contains(email) {
          fallbackIds.append(user.id)
          print("🔔 Found admin user via fallback: \(email) -> \(user.id)")
        }
      }
    } catch {
      print("❌ Fallback admin lookup failed: \(error)")
    }
    
    // If still no admins found, at least notify the issue reporter
    if fallbackIds.isEmpty {
      print("⚠️ No admin users found at all, will only notify issue participants")
    }
    
    return fallbackIds
  }
}

#Preview {
  AddWorkUpdateView(
    issueId: "test-issue",
    issueTitle: "Test Issue",
    restaurantName: "Test Restaurant"
  ) { _ in }
    .environmentObject(AppState())
}
