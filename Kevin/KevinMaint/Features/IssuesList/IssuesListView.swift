import SwiftUI

enum IssueStatusFilter {
  case all, reported, inProgress, completed
}

// MARK: - Helper Functions

// Convert MaintenanceRequest to Issue for compatibility with IssueDetailView
func convertToIssue(_ request: MaintenanceRequest) -> Issue {
  return Issue(
    id: request.id,
    restaurantId: request.businessId,
    locationId: request.locationId ?? "",
    reporterId: request.reporterId,
    title: request.title,
    description: request.description,
    type: request.category.displayName,
    priority: IssuePriority(rawValue: request.priority.rawValue) ?? .medium,
    status: IssueStatus(rawValue: request.status.rawValue) ?? .reported,
    photoUrls: request.photoUrls,
    aiAnalysis: request.aiAnalysis,
    voiceNotes: nil, // MaintenanceRequest doesn't have voiceNotes
    createdAt: request.createdAt,
    updatedAt: request.updatedAt
  )
}

// MARK: - V2 Helpers
extension RequestStatus {
  var displayName: String {
    switch self {
    case .reported: return "Reported"
    case .in_progress: return "In Progress"
    case .completed: return "Completed"
    }
  }
  var isActive: Bool {
    switch self {
    case .completed: return false
    default: return true
    }
  }
}

// MARK: - V2 Request Card
struct RequestCardV2: View {
  @Binding var request: MaintenanceRequest
  let onStatusUpdate: ((MaintenanceRequest, RequestStatus) -> Void)?
  let hasUnread: Bool
  let isAdmin: Bool
  @State private var showingStatusActions = false
  
  init(request: Binding<MaintenanceRequest>, onStatusUpdate: ((MaintenanceRequest, RequestStatus) -> Void)? = nil, hasUnread: Bool = false, isAdmin: Bool = false) {
    self._request = request
    self.onStatusUpdate = onStatusUpdate
    self.hasUnread = hasUnread
    self.isAdmin = isAdmin
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Title and Status
      HStack {
        Text(request.title)
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
          .lineLimit(1)
        Spacer()
        if hasUnread {
          Circle()
            .fill(KMTheme.accent)
            .frame(width: 8, height: 8)
        }
        Text(request.status.displayName)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(statusColor(request.status))
          .clipShape(Capsule())
      }
      
      // Description
      Text(request.description)
        .font(.body)
        .foregroundColor(KMTheme.secondaryText)
        .lineLimit(2)
      
      // Meta row
      HStack(spacing: 12) {
        HStack(spacing: 4) {
          Image(systemName: "wrench.fill").foregroundColor(KMTheme.secondaryText).font(.caption)
          Text(request.category.displayName).font(.caption).foregroundColor(KMTheme.secondaryText)
        }
        
        HStack(spacing: 4) {
          Image(systemName: "flag.fill").foregroundColor(priorityColor(request.priority)).font(.caption)
          Text(request.priority.rawValue.capitalized).font(.caption).foregroundColor(KMTheme.secondaryText)
        }
        Spacer()
        Text(request.createdAt, style: .date)
          .font(.caption)
          .foregroundColor(KMTheme.tertiaryText)
      }
      
      if request.status.isActive && onStatusUpdate != nil {
        quickStatusActions
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
    .contentShape(Rectangle())
  }
  
  private var quickStatusActions: some View {
    let nextStatuses = getNextStatusActions()
    return Group {
      // Only show Quick Actions for admin users
      if isAdmin && !nextStatuses.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Quick Actions")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.secondaryText)
            .textCase(.uppercase)
          HStack(spacing: 6) {
            ForEach(nextStatuses.prefix(3), id: \.self) { nextStatus in
              QuickActionButtonV2(
                status: nextStatus,
                color: statusColor(nextStatus)
              ) {
                onStatusUpdate?(request, nextStatus)
              }
            }
            Spacer(minLength: 0)
          }
        }
      }
    }
  }
  
  private func getNextStatusActions() -> [RequestStatus] {
    switch request.status {
    case .reported: return [.in_progress, .completed]
    case .in_progress: return [.completed, .reported]
    case .completed: return []
    }
  }
  
  private func statusColor(_ status: RequestStatus) -> Color {
    switch status {
    case .reported: return KMTheme.danger  // Changed from secondaryText for better contrast
    case .in_progress: return KMTheme.accent
    case .completed: return KMTheme.success
    }
  }
  
  private func priorityColor(_ priority: MaintenancePriority) -> Color {
    switch priority {
    case .low: return KMTheme.success      // Green
    case .medium: return KMTheme.accent    // Blue
    case .high: return Color.pink          // Pink
    }
  }
}

struct QuickActionButtonV2: View {
  let status: RequestStatus
  let color: Color
  let action: () -> Void
  @State private var isPressed = false
  
  var body: some View {
    Button(action: action) {
      Text(status.displayName)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(isPressed ? .white : .white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
          Group {
            if isPressed { color } else { Color.clear }
          }
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    .buttonStyle(PlainButtonStyle())
    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
      isPressed = pressing
    }, perform: {})
  }
}

// MARK: - V2 Request Detail (minimal)
struct RequestDetailViewV2: View {
  @Binding var request: MaintenanceRequest
  var onDismiss: () -> Void
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    // Convert MaintenanceRequest to Issue for IssueDetailView
    let issue = convertToIssue(request)
    
    NavigationStack {
      IssueDetailView(issue: .constant(issue)) {
        onDismiss()
        dismiss()
      }
    }
  }
}

struct IssuesListView: View {
  @EnvironmentObject var appState: AppState
  @StateObject private var aiInsights = AIInsightsService.shared
  @State private var requests: [MaintenanceRequest] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var searchText = ""
  @State private var selectedFilter: IssueStatusFilter = .all
  @State private var showingFilters = false
  @State private var updatingRequestIds: Set<String> = []
  @State private var search = ""
  @State private var selectedRequest: MaintenanceRequest?
  @State private var unreadRequestIds: Set<String> = []
  
  var isKevinAdmin: Bool {
    appState.currentAppUser?.role == .admin
  }
  
  @State private var issueStats: (open: Int, inProgress: Int, completed: Int) = (0, 0, 0)
  
  @Binding var filterBinding: IssueStatusFilter
  @Binding var selectedTab: Int
  @Binding var selectedIssueId: String?
  
  init(filterBinding: Binding<IssueStatusFilter>, selectedTab: Binding<Int>, selectedIssueId: Binding<String?>) {
    self._filterBinding = filterBinding
    self._selectedTab = selectedTab
    self._selectedIssueId = selectedIssueId
  }
  
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Search bar at the top
        searchBarSection
        
        // Main content
        mainContent
      }
      .navigationTitle(isKevinAdmin ? "Kevin's Dashboard" : restaurantTitle)
      .navigationBarTitleDisplayMode(.inline)
      .kevinNavigationBarStyle()
      .background(KMTheme.background.ignoresSafeArea(edges: .bottom))
        .sheet(item: $selectedRequest) { request in
          RequestDetailViewV2(request: .constant(request)) {
            Task {
              await loadRequests()
            }
          }
        }
        .task {
          LaunchTimeProfiler.shared.checkpoint("IssuesListView task started")
          await loadRequests()
          LaunchTimeProfiler.shared.checkpoint("IssuesListView issues loaded")
        }
        .refreshable {
          await loadRequests()
        }
        .onChange(of: selectedIssueId) { _, newId in
          guard let id = newId, !id.isEmpty else { return }
          if let req = requests.first(where: { $0.id == id }) {
            selectedRequest = req
          }
        }
        .onChange(of: appState.currentRestaurant?.id) { oldValue, newValue in
          print("🔄 [IssuesListView] Restaurant changed: \(oldValue ?? "nil") -> \(newValue ?? "nil")")
          Task {
            await loadRequests()
          }
        }
    }
  }
  
  private var searchBarSection: some View {
    HStack {
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundColor(KMTheme.secondaryText)
          .font(.system(size: 16))
        
        TextField("Search issues...", text: $search)
          .foregroundColor(KMTheme.primaryText)
          .font(.system(size: 16))
          .textFieldStyle(PlainTextFieldStyle())
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(Color.clear)
      .cornerRadius(10)
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(KMTheme.border.opacity(0.3), lineWidth: 1)
      )
      
      if !search.isEmpty {
        Button("Cancel") {
          search = ""
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .foregroundColor(KMTheme.accent)
        .font(.system(size: 16))
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 12)
    .background(KMTheme.background)
  }
  
  private var mainContent: some View {
    ZStack {
      KMTheme.background.ignoresSafeArea()
      
      ScrollView {
        VStack(spacing: 24) {
          // Dashboard Metrics
          dashboardMetrics
          
          // AI Insights Header
          aiInsightsHeader
          
          // Issues List
          issuesList
        }
        .padding(24)
      }
    }
  }
  
  private var dashboardMetrics: some View {
    HStack(spacing: 12) {
      Button(action: { filterBinding = .reported }) {
        EnhancedMetricCard(number: "\(issueStats.open)", label: "Reported", color: KMTheme.danger, icon: "exclamationmark.circle.fill", isSelected: filterBinding == .reported)
      }
      .buttonStyle(PlainButtonStyle())
      
      Button(action: { filterBinding = .inProgress }) {
        EnhancedMetricCard(number: "\(issueStats.inProgress)", label: "In Progress", color: KMTheme.accent, icon: "gear.circle.fill", isSelected: filterBinding == .inProgress)
      }
      .buttonStyle(PlainButtonStyle())
      
      Button(action: { filterBinding = .completed }) {
        EnhancedMetricCard(number: "\(issueStats.completed)", label: "Completed", color: KMTheme.success, icon: "checkmark.circle.fill", isSelected: filterBinding == .completed)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }
  
  private var aiInsightsHeader: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "brain.head.profile")
          .foregroundColor(KMTheme.aiGreen)
          .font(.title3)
        
        Text("AI Insights")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.aiGreen)
        
        Spacer()
        
        HStack(spacing: 6) {
          Circle()
            .fill(KMTheme.aiGreen)
            .frame(width: 6, height: 6)
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 2).repeatForever(), value: true)
          
          Text("Active")
            .font(.caption)
            .foregroundColor(KMTheme.aiGreen)
        }
      }
      
      if aiInsights.isAnalyzing {
        HStack {
          ProgressView()
            .scaleEffect(0.8)
          Text("Analyzing maintenance patterns...")
            .font(.body)
            .foregroundColor(KMTheme.secondaryText)
        }
      } else if let insight = aiInsights.currentInsight {
        Text(insight.description)
          .font(.body)
          .foregroundColor(KMTheme.primaryText)
          .lineLimit(nil)
      } else {
        Text("AI analysis will appear here once you have reported issues.")
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
          .lineLimit(nil)
      }
      
      HStack {
        Text("Prediction Confidence")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
        
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Rectangle()
              .fill(KMTheme.borderSecondary)
              .frame(height: 4)
              .cornerRadius(2)
            
            Rectangle()
              .fill(LinearGradient(colors: [KMTheme.warning, KMTheme.danger], startPoint: .leading, endPoint: .trailing))
              .frame(width: geometry.size.width * (aiInsights.currentInsight?.confidence ?? 0.0), height: 4)
              .cornerRadius(2)
          }
        }
        .frame(height: 4)
        
        Text("\(Int((aiInsights.currentInsight?.confidence ?? 0.0) * 100))%")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
    }
    .padding(20)
    .background(KMTheme.warning.opacity(0.1))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.warning.opacity(0.3), lineWidth: 0.5)
    )
  }
  
  private var issuesList: some View {
    LazyVStack(spacing: 12) {
      if isLoading {
        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
            .tint(KMTheme.accent)
          
          Text("Loading requests...")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, minHeight: 120)
      } else if requests.isEmpty {
        VStack(spacing: 24) {
          VStack(spacing: 16) {
            ZStack {
              Circle()
                .fill(KMTheme.accent.opacity(0.1))
                .frame(width: 80, height: 80)
              
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(KMTheme.success)
            }
            
            VStack(spacing: 8) {
              Text("All caught up!")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
              
              Text("No maintenance issues to display. Your locations are running smoothly.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            }
          }
          
          Button("Report New Issue") {
            selectedTab = 0
          }
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(KMTheme.accent)
          .cornerRadius(12)
        }
        .padding(32)
      } else {
        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, request in
          Button {
            selectedRequest = request
          } label: {
            RequestCardV2(
              request: Binding(
                get: { filtered[index] },
                set: { newValue in
                  if let originalIndex = requests.firstIndex(where: { $0.id == newValue.id }) {
                    requests[originalIndex] = newValue
                  }
                }
              ),
              onStatusUpdate: { request, newStatus in
                updateRequestStatus(request, to: newStatus)
              },
              hasUnread: unreadRequestIds.contains(request.id),
              isAdmin: appState.currentAppUser?.role == .admin
            )
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
    }
  }
  
  var filtered: [MaintenanceRequest] {
    let statusFiltered: [MaintenanceRequest]
    switch filterBinding {
    case .all:
      statusFiltered = requests
    case .reported:
      statusFiltered = requests.filter { $0.status == .reported }
    case .inProgress:
      statusFiltered = requests.filter { $0.status == .in_progress }
    case .completed:
      statusFiltered = requests.filter { $0.status == .completed }
    }
    
    if search.isEmpty {
      return statusFiltered
    } else {
      return statusFiltered.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }
  }
  
  private var restaurantTitle: String {
    if let restaurant = appState.currentRestaurant {
      return "\(restaurant.name) Issues"
    }
    return "Issues"
  }
  
  
  @MainActor
  func loadRequests() async {
    print("🔄 [IssuesListView] ===== LOAD REQUESTS STARTED =====")
    print("🔄 [IssuesListView] Current user: \(appState.currentAppUser?.id ?? "NO USER")")
    print("🔄 [IssuesListView] Current user email: \(appState.currentAppUser?.email ?? "NO EMAIL")")
    print("🔄 [IssuesListView] Is admin: \(isKevinAdmin)")
    print("🔄 [IssuesListView] Current restaurant: \(appState.currentRestaurant?.id ?? "NO RESTAURANT")")
    
    do {
      isLoading = true
      errorMessage = nil
      
      // TESTING MODE: Only show issues created after Oct 28, 2025 at 6:00 PM
      let testingCutoffDate = Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 29, hour: 1, minute: 0))!
      
      let loadedRequests: [MaintenanceRequest]
      if isKevinAdmin {
        // Admin users see all requests across all businesses
        print("🔄 [IssuesListView] Loading ALL requests (admin mode)...")
        print("🧪 [TESTING MODE] Only showing issues created after \(testingCutoffDate)")
        loadedRequests = try await MaintenanceServiceV2.shared.listRequests(createdAfter: testingCutoffDate)
        print("✅ [IssuesListView] Loaded \(loadedRequests.count) requests (admin)")
      } else if let currentUserId = appState.currentAppUser?.id {
        // CRITICAL FIX: Always filter by reporter ID for non-admin users
        // This works with both restaurant ownership AND location detection systems
        // Restaurant is informational only, not a filter
        print("🔄 [IssuesListView] Loading requests for reporter: \(currentUserId)...")
        print("🧪 [TESTING MODE] Only showing issues created after \(testingCutoffDate)")
        if let restaurantId = appState.currentRestaurant?.id {
          print("🔄 [IssuesListView] User has restaurant: \(restaurantId) (informational only)")
        }
        loadedRequests = try await MaintenanceServiceV2.shared.listRequests(reporterId: currentUserId, createdAfter: testingCutoffDate)
        print("✅ [IssuesListView] Loaded \(loadedRequests.count) requests reported by current user")
      } else {
        print("❌ [IssuesListView] No user context - returning empty list")
        loadedRequests = []
      }
      
      self.requests = loadedRequests
      self.issueStats = (
        open: loadedRequests.filter { $0.status == .reported }.count,
        inProgress: loadedRequests.filter { $0.status == .in_progress }.count,
        completed: loadedRequests.filter { $0.status == .completed }.count
      )
      self.isLoading = false
      await computeUnread(for: loadedRequests)
      
      // Trigger AI analysis on the loaded issues
      let issues = loadedRequests.map { convertToIssue($0) }
      await aiInsights.analyzeIssues(issues)
    } catch {
      // Handle Firebase index errors gracefully - just show empty state
      self.requests = []
      self.issueStats = (0, 0, 0)
      self.isLoading = false
      self.errorMessage = nil // Don't show technical errors to users
    }
  }

  private func updateRequestStatus(_ request: MaintenanceRequest, to newStatus: RequestStatus) {
    // Prevent multiple simultaneous updates for the same request
    guard !updatingRequestIds.contains(request.id) else {
      print("⚠️ Request \(request.id) update already in progress, ignoring duplicate request")
      return
    }
    
    Task {
      // Add to updating set
      await MainActor.run {
        updatingRequestIds.insert(request.id)
      }
      
      do {
        print("🔄 Updating request \(request.id) status from \(request.status) to \(newStatus)")
        
        // Update the request in Firestore
        try await MaintenanceServiceV2.shared.updateStatus(requestId: request.id, to: newStatus)
        
        // Update local state
        await MainActor.run {
          if let index = self.requests.firstIndex(where: { $0.id == request.id }) {
            self.requests[index].status = newStatus
          }
          // Update stats
          self.issueStats = (
            open: self.requests.filter { $0.status == .reported }.count,
            inProgress: self.requests.filter { $0.status == .in_progress }.count,
            completed: self.requests.filter { $0.status == .completed }.count
          )
        }
        
        // Create an update entry for the status change
        if let currentUser = appState.currentAppUser {
          let statusChangeMessage = "Status updated to \(newStatus.displayName)"
          let update = RequestUpdate(
            requestId: request.id,
            authorId: currentUser.id,
            message: statusChangeMessage
          )
          try await MaintenanceServiceV2.shared.addUpdate(update)
        }
        
        print("✅ Request status updated successfully")
      } catch {
        print("❌ Error updating request status: \(error)")
        // Reload requests to revert any local changes
        await loadRequests()
      }
      
      // Always remove from updating set
      await MainActor.run {
        updatingRequestIds.remove(request.id)
      }
    }
  }

  @MainActor
  private func setUnread(ids: Set<String>) {
    unreadRequestIds = ids
  }

  private func computeUnread(for loadedRequests: [MaintenanceRequest]) async {
    let ids = loadedRequests.map { $0.id }
    guard let uid = appState.currentAppUser?.id else {
      await MainActor.run { self.unreadRequestIds = [] }
      return
    }
    let lastActivity = await ThreadService.shared.getThreadActivityMap(requestIds: ids)
    let lastRead = await ThreadService.shared.getLastReadMap(userId: uid, requestIds: ids)
    var unread: Set<String> = []
    for id in ids {
      if let activity = lastActivity[id] {
        let read = lastRead[id] ?? .distantPast
        if activity > read { unread.insert(id) }
      }
    }
    await MainActor.run { setUnread(ids: unread) }
  }
}

struct EnhancedMetricCard: View {
  let number: String
  let label: String
  let color: Color
  let icon: String
  let isSelected: Bool
  
  var body: some View {
    VStack(spacing: 8) {
      Text(label)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(isSelected ? .white : KMTheme.secondaryText)
        .textCase(.uppercase)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .center)
      
      Text(number)
        .font(.title)
        .fontWeight(.bold)
        .foregroundColor(isSelected ? .white : KMTheme.primaryText)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    .frame(maxWidth: .infinity)
    .padding(12)
    .background(isSelected ? color : KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(color, lineWidth: 1)
    )
  }
}

struct IssueCard: View {
  @Binding var issue: Issue
  let onStatusUpdate: ((Issue, IssueStatus) -> Void)?
  let isAdmin: Bool
  @State private var showingStatusActions = false
  
  init(issue: Binding<Issue>, onStatusUpdate: ((Issue, IssueStatus) -> Void)? = nil, isAdmin: Bool = false) {
    self._issue = issue
    self.onStatusUpdate = onStatusUpdate
    self.isAdmin = isAdmin
  }
  
  // Legacy initializer for backward compatibility
  init(issue: Issue) {
    self._issue = .constant(issue)
    self.onStatusUpdate = nil
    self.isAdmin = false
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Title and Status
      HStack {
        Text(issue.title)
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
          .lineLimit(1)
        
        Spacer()
        
        StatusPill(status: issue.status)
      }
      
      // Description (if available)
      if let description = issue.description, !description.isEmpty {
        Text(description)
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
          .lineLimit(2)
      }
      
      // Bottom metadata row
      HStack {
        Text(issue.createdAt, style: .date)
          .font(.caption)
          .foregroundColor(KMTheme.tertiaryText)
        
        Spacer()
        
        // AI Analysis indicator (simplified)
        if let aiAnalysis = issue.aiAnalysis {
          HStack(spacing: 4) {
            Image(systemName: "brain.head.profile")
              .foregroundColor(KMTheme.aiGreen)
              .font(.caption2)
            
            Text("AI \(Int((aiAnalysis.confidence ?? 0.0) * 100))%")
              .font(.caption2)
              .foregroundColor(KMTheme.aiGreen)
          }
        }
      }
      
      // Quick Status Actions (only show for active issues)
      if issue.status.isActive && onStatusUpdate != nil {
        quickStatusActions
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
    .contentShape(Rectangle())
  }
  
  // Returns the next valid status actions based on the current issue status
  private func getNextStatusActions() -> [IssueStatus] {
    switch issue.status {
    case .reported:
      // From reported, you can move to in progress or completed
      return [.in_progress, .completed]
    case .in_progress:
      // From in progress, you can move to completed or back to reported
      return [.completed, .reported]
    case .completed:
      // No further actions once completed
      return []
    }
  }
  
  private func colorForStatus(_ status: IssueStatus) -> Color {
    switch status {
    case .reported:
      return KMTheme.secondaryText
    case .in_progress:
      return KMTheme.accent
    case .completed:
      return KMTheme.success
    }
  }
  
  private func priorityColor(_ priority: String) -> Color {
    switch priority.lowercased() {
    case "urgent": return KMTheme.danger
    case "high": return KMTheme.warning
    case "normal": return KMTheme.accent
    case "low": return KMTheme.success
    default: return KMTheme.secondaryText
    }
  }
  
  private var quickStatusActions: some View {
    let nextStatuses = getNextStatusActions()
    return Group {
      // Only show Quick Actions for admin users
      if isAdmin && !nextStatuses.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          // Quick Actions Header
          Text("Quick Actions")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.secondaryText)
            .textCase(.uppercase)
          
          // Action Buttons
          HStack(spacing: 6) {
            ForEach(nextStatuses.prefix(3), id: \.self) { nextStatus in
              QuickActionButton(
                status: nextStatus,
                color: colorForStatus(nextStatus)
              ) {
                onStatusUpdate?(issue, nextStatus)
              }
            }
            Spacer(minLength: 0)
          }
        }
      }
    }
  }
}

struct QuickActionButton: View {
  let status: IssueStatus
  let color: Color
  let action: () -> Void
  @State private var isPressed = false
  
  var body: some View {
    Button(action: action) {
      Text(status.displayName)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(isPressed ? .white : .white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
          Group {
            if isPressed {
              color
            } else {
              Color.clear
            }
          }
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    .buttonStyle(PlainButtonStyle())
    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
      isPressed = pressing
    }, perform: {})
  }
}

