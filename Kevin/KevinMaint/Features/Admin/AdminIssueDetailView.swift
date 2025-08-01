import SwiftUI

struct AdminIssueDetailView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.dismiss) private var dismiss
  
  let issue: Issue
  let restaurant: Restaurant?
  
  @State private var workLogs: [WorkLog] = []
  @State private var workOrder: WorkOrder?
  @State private var isLoading = true
  @State private var newMessage = ""
  @State private var isUpdatingStatus = false
  @State private var selectedStatus: IssueStatus
  @State private var showingImageViewer = false
  @State private var showingInvoiceBuilder = false
  
  init(issue: Issue, restaurant: Restaurant?) {
    self.issue = issue
    self.restaurant = restaurant
    self._selectedStatus = State(initialValue: issue.status)
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if isLoading {
          ProgressView("Loading issue details...")
            .foregroundColor(KMTheme.secondaryText)
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              // Issue Header
              issueHeader
              
              // Issue Details
              issueDetails
              
              // AI Analysis
              if let aiAnalysis = issue.aiAnalysis {
                aiAnalysisSection(aiAnalysis)
              }
              
              // Photos
              if !(issue.photoUrls?.isEmpty ?? true) {
                photosSection
              }
              
              // Work Order Info
              if let workOrder = workOrder {
                workOrderSection(workOrder)
              }
              
              // Admin Actions
              adminActionsSection
              
              // Work Logs / Messages
              workLogsSection
              
              // Message Input
              messageInputSection
            }
            .padding(24)
          }
        }
      }
      .navigationTitle("Issue Details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(KMTheme.cardBackground, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
      .onAppear {
        loadIssueDetails()
      }
      .sheet(isPresented: $showingImageViewer) {
        if let firstPhotoUrl = issue.photoUrls?.first {
          ImageViewer(imageUrl: firstPhotoUrl)
        }
      }
      .sheet(isPresented: $showingInvoiceBuilder) {
        InvoiceBuilderView(issue: issue, business: restaurant)
          .environmentObject(appState)
      }
    }
  }
  
  private var issueHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(issue.title)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.primaryText)
          
          if let restaurant = restaurant {
            Text(restaurant.name)
              .font(.subheadline)
              .foregroundColor(KMTheme.accent)
          }
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 8) {
          StatusPill(status: issue.status)
          
          Text(issue.priority.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(priorityColor(issue.priority))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor(issue.priority).opacity(0.1))
            .cornerRadius(6)
        }
      }
      
      Text("Created \(issue.createdAt.formatted(.dateTime.month().day().hour().minute()))")
        .font(.caption)
        .foregroundColor(KMTheme.tertiaryText)
    }
  }
  
  private var issueDetails: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Description")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      Text(issue.description ?? "No description provided")
        .font(.body)
        .foregroundColor(KMTheme.secondaryText)
        .padding(16)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(KMTheme.border, lineWidth: 0.5)
        )
      
      if !issue.locationId.isEmpty {
        HStack {
          Image(systemName: "location")
            .foregroundColor(KMTheme.accent)
            .font(.caption)
          
          Text("Location: \(issue.locationId)")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
      }
    }
  }
  
  private func aiAnalysisSection(_ analysis: AIAnalysis) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "brain.head.profile")
          .foregroundColor(KMTheme.aiGreen)
          .font(.headline)
        
        Text("AI Analysis")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
      }
      
      VStack(alignment: .leading, spacing: 16) {
        if !analysis.description.isEmpty {
          analysisCard(title: "Assessment", content: analysis.description, icon: "magnifyingglass")
        }
        
        if let recommendations = analysis.recommendations, !recommendations.isEmpty {
          analysisCard(title: "Recommendations", content: recommendations.joined(separator: "\n"), icon: "lightbulb")
        }
        
        if let materials = analysis.materialsNeeded, !materials.isEmpty {
          analysisCard(title: "Materials Needed", content: materials.joined(separator: "\n"), icon: "hammer")
        }
        
        if let timeEstimate = analysis.timeToComplete {
          analysisCard(title: "Time Estimate", content: timeEstimate, icon: "clock")
        }
        
        if let safetyWarnings = analysis.safetyWarnings, !safetyWarnings.isEmpty {
          analysisCard(title: "Safety Warnings", content: safetyWarnings.joined(separator: "\n"), icon: "exclamationmark.triangle", color: KMTheme.warning)
        }
      }
    }
  }
  
  private func analysisCard(title: String, content: String, icon: String, color: Color = KMTheme.accent) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(color)
          .font(.caption)
        
        Text(title)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
      }
      
      Text(content)
        .font(.body)
        .foregroundColor(KMTheme.secondaryText)
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  private var photosSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Photos")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(issue.photoUrls ?? [], id: \.self) { photoUrl in
            Button {
              showingImageViewer = true
            } label: {
              AsyncImage(url: URL(string: photoUrl)) { image in
                image
                  .resizable()
                  .aspectRatio(contentMode: .fill)
              } placeholder: {
                Rectangle()
                  .fill(KMTheme.cardBackground)
                  .overlay(
                    ProgressView()
                      .foregroundColor(KMTheme.secondaryText)
                  )
              }
              .frame(width: 120, height: 120)
              .clipShape(RoundedRectangle(cornerRadius: 12))
            }
          }
        }
        .padding(.horizontal, 24)
      }
      .padding(.horizontal, -24)
    }
  }
  
  private func workOrderSection(_ workOrder: WorkOrder) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Work Order")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("Status:")
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(workOrder.status.rawValue.capitalized)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(statusColor(workOrder.status))
        }
        
        if let cost = workOrder.estimatedCost {
          HStack {
            Text("Estimated Cost:")
              .font(.subheadline)
              .foregroundColor(KMTheme.secondaryText)
            
            Text("$\(Int(cost))")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
        }
        
        if let scheduledAt = workOrder.scheduledAt {
          HStack {
            Text("Scheduled:")
              .font(.subheadline)
              .foregroundColor(KMTheme.secondaryText)
            
            Text(scheduledAt.formatted(.dateTime.month().day().hour().minute()))
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
        }
      }
      .padding(16)
      .background(KMTheme.cardBackground)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(KMTheme.border, lineWidth: 0.5)
      )
    }
  }
  
  private var adminActionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Admin Actions")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      VStack(spacing: 12) {
        // Status Update
        HStack {
          Text("Update Status:")
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
          
          Spacer()
          
          Picker("Status", selection: $selectedStatus) {
            ForEach([IssueStatus.reported, .in_progress, .completed], id: \.self) { status in
              Text(status.rawValue.capitalized)
                .tag(status as IssueStatus?)
            }
          }
          .pickerStyle(MenuPickerStyle())
          .foregroundColor(KMTheme.accent)
        }
        
        if selectedStatus != issue.status {
          Button {
            updateIssueStatus()
          } label: {
            HStack {
              if isUpdatingStatus {
                ProgressView()
                  .scaleEffect(0.8)
                  .foregroundColor(.white)
              } else {
                Text("Update Status")
                  .fontWeight(.medium)
              }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(KMTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(8)
          }
          .disabled(isUpdatingStatus)
        }
        
        Divider()
          .background(KMTheme.border)
          .padding(.vertical, 8)
        
        // Generate Invoice Button
        Button {
          showingInvoiceBuilder = true
        } label: {
          HStack {
            Image(systemName: "doc.text.fill")
            Text("Generate Invoice")
              .fontWeight(.medium)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Color.green)
          .foregroundColor(.white)
          .cornerRadius(8)
        }
      }
      .padding(16)
      .background(KMTheme.cardBackground)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(KMTheme.border, lineWidth: 0.5)
      )
    }
  }
  
  private var workLogsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Messages & Updates")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      if workLogs.isEmpty {
        Text("No messages yet")
          .font(.body)
          .foregroundColor(KMTheme.tertiaryText)
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(KMTheme.cardBackground)
          .cornerRadius(12)
      } else {
        LazyVStack(spacing: 12) {
          ForEach(workLogs.sorted(by: { $0.createdAt < $1.createdAt })) { log in
            WorkLogCard(workLog: log)
          }
        }
      }
    }
  }
  
  private var messageInputSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Send Message")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      VStack(spacing: 12) {
        TextField("Type your message...", text: $newMessage, axis: .vertical)
          .textFieldStyle(PlainTextFieldStyle())
          .padding(12)
          .background(KMTheme.cardBackground)
          .cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(KMTheme.border, lineWidth: 0.5)
          )
        
        Button {
          sendMessage()
        } label: {
          Text("Send Message")
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? KMTheme.tertiaryText : KMTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }
  
  private func loadIssueDetails() {
    Task {
      do {
        // Load work logs
        workLogs = try await appState.firebaseClient.fetchWorkLogs(issueId: issue.id)
        
        // Load work order if exists
        let allWorkOrders = try await appState.firebaseClient.listWorkOrders()
        workOrder = allWorkOrders.first { $0.issueId == issue.id }
        
        await MainActor.run {
          isLoading = false
        }
      } catch {
        await MainActor.run {
          isLoading = false
        }
      }
    }
  }
  
  private func updateIssueStatus() {
    Task {
      do {
        isUpdatingStatus = true
        try await appState.firebaseClient.updateIssueStatus(issueId: issue.id, status: selectedStatus)
        
        // Add a work log for the status change
        let statusMessage = "Status updated to \(selectedStatus.rawValue) by Kevin Admin"
        let workLog = WorkLog(
          id: UUID().uuidString,
          issueId: issue.id,
          authorId: "admin",
          message: statusMessage,
          createdAt: Date()
        )
        try await appState.firebaseClient.addWorkLog(workLog)
        
        // Reload work logs
        workLogs = try await appState.firebaseClient.fetchWorkLogs(issueId: issue.id)
        
        await MainActor.run {
          isUpdatingStatus = false
        }
      } catch {
        await MainActor.run {
          isUpdatingStatus = false
        }
      }
    }
  }
  
  private func sendMessage() {
    let message = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { return }
    
    Task {
      do {
        let workLog = WorkLog(
          id: UUID().uuidString,
          issueId: issue.id,
          authorId: "admin",
          message: message,
          createdAt: Date()
        )
        try await appState.firebaseClient.addWorkLog(workLog)
        
        // Reload work logs
        workLogs = try await appState.firebaseClient.fetchWorkLogs(issueId: issue.id)
        
        await MainActor.run {
          newMessage = ""
        }
      } catch {
        // Handle error
      }
    }
  }
  
  private func priorityColor(_ priority: IssuePriority) -> Color {
    switch priority {
    case .low: return KMTheme.success
    case .medium: return KMTheme.warning
    case .high: return KMTheme.danger
    }
  }
  
  private func statusColor(_ status: WorkOrderStatus) -> Color {
    switch status {
    case .scheduled: return KMTheme.accent
    case .in_progress: return KMTheme.warning
    case .completed: return KMTheme.success
    case .blocked: return KMTheme.tertiaryText
    case .en_route: return KMTheme.progress
    }
  }
}

struct WorkLogCard: View {
  let workLog: WorkLog
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(workLog.authorId == "admin" ? "Kevin Admin" : "User")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(workLog.authorId == "admin" ? KMTheme.accent : KMTheme.primaryText)
        
        Spacer()
        
        Text(workLog.createdAt.formatted(.relative(presentation: .named)))
          .font(.caption)
          .foregroundColor(KMTheme.tertiaryText)
      }
      
      Text(workLog.message)
        .font(.body)
        .foregroundColor(KMTheme.secondaryText)
    }
    .padding(12)
    .background(KMTheme.cardBackground)
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
}

struct ImageViewer: View {
  let imageUrl: String
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()
        
        AsyncImage(url: URL(string: imageUrl)) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
        } placeholder: {
          ProgressView()
            .foregroundColor(.white)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
    }
  }
}
