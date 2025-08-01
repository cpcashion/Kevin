import SwiftUI

struct AdminDashboardView: View {
  @EnvironmentObject var appState: AppState
  @State private var restaurants: [Restaurant] = []
  @State private var allIssues: [Issue] = []
  @State private var allWorkOrders: [WorkOrder] = []
  @State private var isLoading = true
  @State private var errorMessage: String?
  @State private var selectedTab = 0
  @State private var searchText = ""
  @State private var selectedRestaurant: Restaurant?
  @State private var selectedIssue: Issue?
  @State private var showingRestaurantDetail = false
  @State private var showingIssueDetail = false
  @State private var showingAIAccuracy = false
  @State private var showingRestaurantHealth = false
  
  private var filteredRestaurants: [Restaurant] {
    if searchText.isEmpty {
      return restaurants
    }
    return restaurants.filter { restaurant in
      restaurant.name.localizedCaseInsensitiveContains(searchText) ||
      restaurant.address?.localizedCaseInsensitiveContains(searchText) == true
    }
  }
  
  private var criticalIssues: [Issue] {
    allIssues.filter { $0.priority == .high }  // Changed from .critical
  }
  
  private var pendingWorkOrders: [WorkOrder] {
    allWorkOrders.filter { $0.status == .scheduled }
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if isLoading {
          ProgressView("Loading dashboard...")
            .foregroundColor(KMTheme.secondaryText)
        } else if let errorMessage = errorMessage {
          ErrorView(message: errorMessage) {
            loadDashboardData()
          }
        } else {
          ScrollView {
            VStack(spacing: 24) {
              // Welcome Header
              adminHeader
              
              // Data Visualization Buttons
              HStack(spacing: 12) {
                // AI Accuracy Button
                DataVizButton(
                  icon: "brain.head.profile",
                  title: "AI Accuracy",
                  subtitle: "Analysis Quality",
                  color: KMTheme.aiGreen,
                  gradientColors: [KMTheme.aiGreen.opacity(0.8), KMTheme.aiGreen.opacity(0.4)],
                  action: {
                    showingAIAccuracy = true
                  }
                )
                
                // Restaurant Health Button
                DataVizButton(
                  icon: "heart.text.square",
                  title: "Health Trends",
                  subtitle: "Restaurant Status",
                  color: KMTheme.progress,
                  gradientColors: [KMTheme.progress.opacity(0.8), KMTheme.progress.opacity(0.4)],
                  action: {
                    showingRestaurantHealth = true
                  }
                )
              }
              
              // Key Metrics
              metricsOverview
              
              // Tab Selection
              tabSelector
              
              // Content based on selected tab
              Group {
                switch selectedTab {
                case 0:
                  restaurantsSection
                case 1:
                  issuesSection
                case 2:
                  workOrdersSection
                default:
                  restaurantsSection
                }
              }
            }
            .padding(24)
          }
        }
      }
      .navigationTitle("Admin Dashboard")
      .navigationBarTitleDisplayMode(.inline)
      .kevinNavigationBarStyle()
      .searchable(text: $searchText, prompt: "Search restaurants...")
      .configureSearchBarAppearance()
      .onAppear {
        loadDashboardData()
      }
      .refreshable {
        await refreshDashboard()
      }
      .sheet(isPresented: $showingRestaurantDetail) {
        if let restaurant = selectedRestaurant {
          AdminRestaurantDetailView(restaurant: restaurant)
        }
      }
      .sheet(isPresented: $showingIssueDetail) {
        if let issue = selectedIssue {
          AdminIssueDetailView(
            issue: issue,
            restaurant: restaurants.first { $0.id == issue.restaurantId }
          )
        }
      }
      .sheet(isPresented: $showingAIAccuracy) {
        AIAccuracyView()
      }
      .sheet(isPresented: $showingRestaurantHealth) {
        RestaurantHealthView()
      }
    }
  }
  
  private var adminHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Welcome back, Kevin!")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.primaryText)
          
          Text("Managing \(restaurants.count) restaurants")
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
        }
        
        Spacer()
        
        Button(action: { loadDashboardData() }) {
          Image(systemName: "arrow.clockwise")
            .foregroundColor(KMTheme.accent)
            .font(.title3)
        }
      }
      
      // AI Insights
      if !criticalIssues.isEmpty {
        HStack {
          Image(systemName: "brain.head.profile")
            .foregroundColor(KMTheme.aiGreen)
            .font(.caption)
          
          Text("AI Alert: \(criticalIssues.count) critical issues need immediate attention")
            .font(.caption)
            .foregroundColor(KMTheme.warning)
          
          Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(KMTheme.warning.opacity(0.1))
        .cornerRadius(8)
      }
    }
  }
  
  private var metricsOverview: some View {
    VStack(spacing: 16) {
      HStack {
        Text("System Overview")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
      }
      
      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
        EnhancedMetricCard(
          number: "\(restaurants.count)",
          label: "Active Restaurants",
          color: KMTheme.accent,
          icon: "building.2",
          isSelected: false
        )
        
        MetricCard(
          number: "\(allIssues.count)",
          label: "Total Issues",
          color: KMTheme.warning
        )
        
        MetricCard(
          number: "\(pendingWorkOrders.count)",
          label: "Pending Work Orders",
          color: KMTheme.accent
        )
        
        MetricCard(
          number: "\(criticalIssues.count)",
          label: "Critical Issues",
          color: KMTheme.danger
        )
      }
    }
  }
  
  private var tabSelector: some View {
    HStack(spacing: 0) {
      AdminTabButton(title: "Restaurants", isSelected: selectedTab == 0) {
        selectedTab = 0
      }
      
      AdminTabButton(title: "Issues", isSelected: selectedTab == 1) {
        selectedTab = 1
      }
      
      AdminTabButton(title: "Work Orders", isSelected: selectedTab == 2) {
        selectedTab = 2
      }
    }
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  private var restaurantsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Restaurants")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        Text("\(filteredRestaurants.count) total")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      LazyVStack(spacing: 12) {
        ForEach(filteredRestaurants) { restaurant in
          AdminRestaurantCard(
            restaurant: restaurant,
            issues: allIssues.filter { $0.restaurantId == restaurant.id },
            workOrders: allWorkOrders.filter { $0.restaurantId == restaurant.id },
            onViewDetails: {
              selectedRestaurant = restaurant
              showingRestaurantDetail = true
            },
            onViewIssues: {
              selectedRestaurant = restaurant
              showingRestaurantDetail = true
            }
          )
        }
      }
    }
  }
  
  private var issuesSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("All Issues")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        Text("\(allIssues.count) total")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      LazyVStack(spacing: 12) {
        ForEach(allIssues.sorted(by: { $0.createdAt > $1.createdAt })) { issue in
          Button {
            selectedIssue = issue
            showingIssueDetail = true
          } label: {
            AdminIssueCard(
              issue: issue,
              restaurant: restaurants.first { $0.id == issue.restaurantId }
            )
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
    }
  }
  
  private var workOrdersSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Work Orders")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        Text("\(allWorkOrders.count) total")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      LazyVStack(spacing: 12) {
        ForEach(allWorkOrders.sorted(by: { 
          ($0.scheduledAt ?? Date.distantFuture) < ($1.scheduledAt ?? Date.distantFuture)
        })) { workOrder in
          AdminWorkOrderCard(
            workOrder: workOrder,
            restaurant: restaurants.first { $0.id == workOrder.restaurantId },
            issue: allIssues.first { $0.id == workOrder.issueId }
          )
        }
      }
    }
  }
  
  private func loadDashboardData() {
    Task {
      do {
        isLoading = true
        errorMessage = nil
        
        async let restaurantsTask = appState.firebaseClient.listRestaurants()
        async let issuesTask = appState.firebaseClient.listIssues()
        async let workOrdersTask = appState.firebaseClient.listWorkOrders()
        
        let (loadedRestaurants, loadedIssues, loadedWorkOrders) = try await (
          restaurantsTask,
          issuesTask,
          workOrdersTask
        )
        
        await MainActor.run {
          self.restaurants = loadedRestaurants
          self.allIssues = loadedIssues
          self.allWorkOrders = loadedWorkOrders
          self.isLoading = false
        }
      } catch {
        await MainActor.run {
          self.errorMessage = "Failed to load dashboard: \(error.localizedDescription)"
          self.isLoading = false
        }
      }
    }
  }
  
  private func refreshDashboard() async {
    await withCheckedContinuation { continuation in
      loadDashboardData()
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        continuation.resume()
      }
    }
  }
}

struct AdminRestaurantCard: View {
  let restaurant: Restaurant
  let issues: [Issue]
  let workOrders: [WorkOrder]
  let onViewDetails: () -> Void
  let onViewIssues: () -> Void
  
  private var criticalIssuesCount: Int {
    issues.filter { $0.priority == .high }.count  // Changed from .critical
  }
  
  private var pendingWorkOrdersCount: Int {
    workOrders.filter { $0.status == .scheduled }.count
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        // Restaurant Logo
        AsyncImage(url: URL(string: restaurant.logoUrl ?? "")) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Rectangle()
            .fill(KMTheme.accent.opacity(0.2))
            .overlay(
              Text(String(restaurant.name.prefix(1)))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(KMTheme.accent)
            )
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        
        VStack(alignment: .leading, spacing: 4) {
          Text(restaurant.name)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          if let address = restaurant.address {
            Text(address)
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
              .lineLimit(1)
          }
          
          if let cuisine = restaurant.category {
            Text(cuisine)
              .font(.caption2)
              .foregroundColor(KMTheme.accent)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(KMTheme.accent.opacity(0.1))
              .cornerRadius(4)
          }
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          if let rating = restaurant.rating {
            HStack(spacing: 2) {
              Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.caption2)
              Text(String(format: "%.1f", rating))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            }
          }
          
          Text("ID: \(String(restaurant.id.prefix(8)))")
            .font(.caption2)
            .foregroundColor(KMTheme.tertiaryText)
        }
      }
      
      // Restaurant Stats
      HStack(spacing: 16) {
        StatBadge(
          icon: "exclamationmark.triangle.fill",
          count: issues.count,
          label: "Issues",
          color: issues.isEmpty ? KMTheme.success : (criticalIssuesCount > 0 ? KMTheme.danger : KMTheme.warning)
        )
        
        StatBadge(
          icon: "wrench.and.screwdriver.fill",
          count: workOrders.count,
          label: "Work Orders",
          color: workOrders.isEmpty ? KMTheme.tertiaryText : KMTheme.accent
        )
        
        if criticalIssuesCount > 0 {
          StatBadge(
            icon: "flame.fill",
            count: criticalIssuesCount,
            label: "Critical",
            color: KMTheme.danger
          )
        }
        
        Spacer()
      }
      
      // Quick Actions
      HStack(spacing: 12) {
        Button("View Details") {
          onViewDetails()
        }
        .font(.caption)
        .foregroundColor(KMTheme.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(KMTheme.accent.opacity(0.1))
        .cornerRadius(6)
        
        if !issues.isEmpty {
          Button("View Issues") {
            onViewIssues()
          }
          .font(.caption)
          .foregroundColor(KMTheme.warning)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(KMTheme.warning.opacity(0.1))
          .cornerRadius(6)
        }
        
        Spacer()
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

struct AdminIssueCard: View {
  let issue: Issue
  let restaurant: Restaurant?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(issue.title)
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
            .lineLimit(1)
          
          if let restaurant = restaurant {
            Text(restaurant.name)
              .font(.caption)
              .foregroundColor(KMTheme.accent)
          }
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          StatusPill(status: issue.status)
          
          Text(issue.priority.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(priorityColor(issue.priority))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor(issue.priority).opacity(0.1))
            .cornerRadius(4)
        }
      }
      
      Text(issue.description ?? "No description provided")
        .font(.body)
        .foregroundColor(KMTheme.secondaryText)
        .lineLimit(2)
      
      HStack {
        Text("Created \(issue.createdAt.formatted(.relative(presentation: .named)))")
          .font(.caption)
          .foregroundColor(KMTheme.tertiaryText)
        
        Spacer()
        
        if let aiAnalysis = issue.aiAnalysis {
          HStack(spacing: 4) {
            Image(systemName: "brain.head.profile")
              .foregroundColor(KMTheme.aiGreen)
              .font(.caption2)
            
            Text("AI Analyzed")
              .font(.caption2)
              .foregroundColor(KMTheme.aiGreen)
          }
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
  
  private func priorityColor(_ priority: IssuePriority) -> Color {
    switch priority {
    case .low: return KMTheme.success
    case .medium: return KMTheme.warning
    case .high: return KMTheme.danger
    }
  }
}

struct AdminWorkOrderCard: View {
  let workOrder: WorkOrder
  let restaurant: Restaurant?
  let issue: Issue?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          if let issue = issue {
            Text(issue.title)
              .font(.headline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
              .lineLimit(1)
          } else {
            Text("Work Order #\(String(workOrder.id.prefix(8)))")
              .font(.headline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
          
          if let restaurant = restaurant {
            Text(restaurant.name)
              .font(.caption)
              .foregroundColor(KMTheme.accent)
          }
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          Text(workOrder.status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(statusColor(workOrder.status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(workOrder.status).opacity(0.1))
            .cornerRadius(6)
          
          if let cost = workOrder.estimatedCost {
            Text("$\(Int(cost))")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
          }
        }
      }
      
      HStack {
        if let scheduledAt = workOrder.scheduledAt {
          Text("Scheduled: \(scheduledAt.formatted(.dateTime.month().day().hour().minute()))")
            .font(.caption)
            .foregroundColor(KMTheme.tertiaryText)
        }
        
        Spacer()
        
        if let assigneeId = workOrder.assigneeId, !assigneeId.isEmpty {
          Text("Assigned")
            .font(.caption2)
            .foregroundColor(KMTheme.success)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(KMTheme.success.opacity(0.1))
            .cornerRadius(4)
        } else {
          Text("Unassigned")
            .font(.caption2)
            .foregroundColor(KMTheme.warning)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(KMTheme.warning.opacity(0.1))
            .cornerRadius(4)
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

struct AdminTabButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline)
        .fontWeight(isSelected ? .semibold : .regular)
        .foregroundColor(isSelected ? KMTheme.accent : KMTheme.secondaryText)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
          isSelected ? KMTheme.accent.opacity(0.1) : Color.clear
        )
        .cornerRadius(8)
    }
  }
}

struct StatBadge: View {
  let icon: String
  let count: Int
  let label: String
  let color: Color
  
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .foregroundColor(color)
        .font(.caption2)
      
      Text("\(count)")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(color)
      
      Text(label)
        .font(.caption2)
        .foregroundColor(KMTheme.tertiaryText)
    }
  }
}

struct ErrorView: View {
  let message: String
  let retry: () -> Void
  
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundColor(KMTheme.warning)
      
      Text(message)
        .foregroundColor(KMTheme.secondaryText)
        .multilineTextAlignment(.center)
      
      Button("Retry") {
        retry()
      }
      .foregroundColor(KMTheme.accent)
      .padding(.horizontal, 20)
      .padding(.vertical, 8)
      .background(KMTheme.accent.opacity(0.1))
      .cornerRadius(8)
    }
    .padding()
  }
}
