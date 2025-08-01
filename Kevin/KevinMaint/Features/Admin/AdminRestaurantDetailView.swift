import SwiftUI

struct AdminRestaurantDetailView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.dismiss) private var dismiss
  
  let restaurant: Restaurant
  
  @State private var issues: [Issue] = []
  @State private var workOrders: [WorkOrder] = []
  @State private var users: [AppUser] = []
  @State private var isLoading = true
  @State private var selectedTab = 0
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if isLoading {
          ProgressView("Loading restaurant details...")
            .foregroundColor(KMTheme.secondaryText)
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              // Restaurant Header
              restaurantHeader
              
              // Key Metrics
              metricsSection
              
              // Tab Selection
              tabSelector
              
              // Content based on selected tab
              Group {
                switch selectedTab {
                case 0:
                  issuesSection
                case 1:
                  workOrdersSection
                case 2:
                  usersSection
                default:
                  issuesSection
                }
              }
            }
            .padding(24)
          }
        }
      }
      .navigationTitle(restaurant.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(KMTheme.cardBackground, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Back") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
      .onAppear {
        loadRestaurantDetails()
      }
    }
  }
  
  private var restaurantHeader: some View {
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
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(KMTheme.accent)
            )
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        
        VStack(alignment: .leading, spacing: 8) {
          Text(restaurant.name)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.primaryText)
          
          if let address = restaurant.address {
            HStack {
              Image(systemName: "location")
                .foregroundColor(KMTheme.accent)
                .font(.caption)
              
              Text(address)
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
                .lineLimit(2)
            }
          }
          
          if let phone = restaurant.phone {
            HStack {
              Image(systemName: "phone")
                .foregroundColor(KMTheme.accent)
                .font(.caption)
              
              Text(phone)
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
            }
          }
        }
        
        Spacer()
      }
      
      // Restaurant Info
      HStack(spacing: 16) {
        if let cuisine = restaurant.category {
          InfoBadge(icon: "fork.knife", text: cuisine, color: KMTheme.accent)
        }
        
        if let rating = restaurant.rating {
          InfoBadge(icon: "star.fill", text: String(format: "%.1f", rating), color: .yellow)
        }
        
        InfoBadge(icon: "calendar", text: "Since \(restaurant.createdAt.formatted(.dateTime.month().day().year()))", color: KMTheme.tertiaryText)
        
        Spacer()
      }
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  private var metricsSection: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
      MetricCard(
        number: "\(issues.count)",
        label: "Total Issues",
        color: issues.isEmpty ? KMTheme.success : (criticalIssuesCount > 0 ? KMTheme.danger : KMTheme.warning)
      )
      
      MetricCard(
        number: "\(workOrders.count)",
        label: "Work Orders",
        color: KMTheme.accent
      )
      
      MetricCard(
        number: "\(users.count)",
        label: "Team Members",
        color: KMTheme.progress
      )
    }
  }
  
  private var tabSelector: some View {
    HStack(spacing: 0) {
      AdminTabButton(title: "Issues (\(issues.count))", isSelected: selectedTab == 0) {
        selectedTab = 0
      }
      
      AdminTabButton(title: "Work Orders (\(workOrders.count))", isSelected: selectedTab == 1) {
        selectedTab = 1
      }
      
      AdminTabButton(title: "Team (\(users.count))", isSelected: selectedTab == 2) {
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
  
  private var issuesSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Issues")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        if criticalIssuesCount > 0 {
          Text("\(criticalIssuesCount) Critical")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.danger)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(KMTheme.danger.opacity(0.1))
            .cornerRadius(6)
        }
      }
      
      if issues.isEmpty {
        Text("No issues reported")
          .font(.body)
          .foregroundColor(KMTheme.tertiaryText)
          .padding(20)
          .frame(maxWidth: .infinity)
          .background(KMTheme.cardBackground)
          .cornerRadius(12)
      } else {
        LazyVStack(spacing: 12) {
          ForEach(issues.sorted(by: { $0.createdAt > $1.createdAt })) { issue in
            NavigationLink {
              AdminIssueDetailView(issue: issue, restaurant: restaurant)
            } label: {
              AdminIssueCard(issue: issue, restaurant: restaurant)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      }
    }
  }
  
  private var workOrdersSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Work Orders")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      if workOrders.isEmpty {
        Text("No work orders created")
          .font(.body)
          .foregroundColor(KMTheme.tertiaryText)
          .padding(20)
          .frame(maxWidth: .infinity)
          .background(KMTheme.cardBackground)
          .cornerRadius(12)
      } else {
        LazyVStack(spacing: 12) {
          ForEach(workOrders.sorted(by: { 
            ($0.scheduledAt ?? Date.distantFuture) < ($1.scheduledAt ?? Date.distantFuture)
          })) { workOrder in
            AdminWorkOrderCard(
              workOrder: workOrder,
              restaurant: restaurant,
              issue: issues.first { $0.id == workOrder.issueId }
            )
          }
        }
      }
    }
  }
  
  private var usersSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Team Members")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      if users.isEmpty {
        Text("No team members found")
          .font(.body)
          .foregroundColor(KMTheme.tertiaryText)
          .padding(20)
          .frame(maxWidth: .infinity)
          .background(KMTheme.cardBackground)
          .cornerRadius(12)
      } else {
        LazyVStack(spacing: 12) {
          ForEach(users) { user in
            UserCard(user: user)
          }
        }
      }
    }
  }
  
  private var criticalIssuesCount: Int {
    issues.filter { $0.priority == .high }.count  // Changed from .critical
  }
  
  private func loadRestaurantDetails() {
    Task {
      do {
        async let issuesTask = appState.firebaseClient.listIssues(restaurantId: restaurant.id)
        async let workOrdersTask = appState.firebaseClient.listWorkOrders(restaurantId: restaurant.id)
        async let usersTask = appState.firebaseClient.listUsers(restaurantId: restaurant.id)
        
        let (loadedIssues, loadedWorkOrders, loadedUsers) = try await (
          issuesTask,
          workOrdersTask,
          usersTask
        )
        
        await MainActor.run {
          self.issues = loadedIssues
          self.workOrders = loadedWorkOrders
          self.users = loadedUsers
          self.isLoading = false
        }
      } catch {
        await MainActor.run {
          self.isLoading = false
        }
      }
    }
  }
}

struct InfoBadge: View {
  let icon: String
  let text: String
  let color: Color
  
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .foregroundColor(color)
        .font(.caption2)
      
      Text(text)
        .font(.caption)
        .foregroundColor(KMTheme.secondaryText)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(color.opacity(0.1))
    .cornerRadius(6)
  }
}

struct UserCard: View {
  let user: AppUser
  
  var body: some View {
    HStack {
      // User Avatar
      Circle()
        .fill(KMTheme.accent.opacity(0.2))
        .frame(width: 40, height: 40)
        .overlay(
          Text(String((user.name ?? user.email ?? "U").prefix(1)).uppercased())
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.accent)
        )
      
      VStack(alignment: .leading, spacing: 4) {
        Text(user.name ?? "Unknown User")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        Text(user.email ?? "No email")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
        
        Text(user.role.rawValue.capitalized)
          .font(.caption2)
          .fontWeight(.medium)
          .foregroundColor(roleColor(user.role))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(roleColor(user.role).opacity(0.1))
          .cornerRadius(4)
      }
      
      Spacer()
      
      Text("Member")
        .font(.caption2)
        .foregroundColor(KMTheme.tertiaryText)
    }
    .padding(12)
    .background(KMTheme.cardBackground)
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  private func roleColor(_ role: Role) -> Color {
    switch role {
    case .owner: return KMTheme.accent
    case .admin: return KMTheme.progress
    case .gm: return KMTheme.warning
    case .tech: return KMTheme.success
    }
  }
}
