import SwiftUI
import MapKit

struct LocationDetailView: View {
  let location: Location
  @EnvironmentObject var appState: AppState
  @StateObject private var locationStatsService = LocationStatsService()
  @State private var issues: [Issue] = []
  @State private var isLoading = true
  @State private var selectedTab = 0
  @State private var showingMapView = false
  
  var isKevinAdmin: Bool {
    appState.currentAppUser?.role == .admin
  }
  
  var stats: LocationStats? {
    locationStatsService.getStats(for: location.id)
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if isLoading {
          ProgressView("Loading location details...")
            .foregroundColor(KMTheme.secondaryText)
        } else {
          ScrollView {
            VStack(spacing: 24) {
              // Header Section
              locationHeader
              
              // Quick Stats
              quickStats
              
              // Tab Selection
              tabSelector
              
              // Tab Content
              tabContent
            }
            .padding(24)
          }
        }
      }
      .navigationTitle(location.name)
      .navigationBarTitleDisplayMode(.large)
      .navigationBarBackButtonHidden(false)
      .sheet(isPresented: $showingMapView) {
        LocationsMapView(
          locations: [location],
          locationStats: [location.id: locationStatsService.getStats(for: location.id) ?? LocationStats(locationId: location.id, openIssuesCount: 0, completedIssuesCount: 0, averageResponseTime: "N/A", aiHealthScore: 75, isOnline: true, lastSync: "N/A")]
        )
      }
      .onAppear {
        loadIssues()
        locationStatsService.startListening(for: [location.id])
      }
    }
  }
  
  private var locationHeader: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 8) {
          Text(location.name)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.primaryText)
          
          if let address = location.address {
            Text(address)
              .font(.body)
              .foregroundColor(KMTheme.secondaryText)
              .lineLimit(2)
          }
          
          if let manager = location.managerName {
            HStack(spacing: 6) {
              Image(systemName: "person.circle")
                .foregroundColor(KMTheme.accent)
                .font(.caption)
              
              Text("Manager: \(manager)")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
            }
          }
        }
        
        Spacer()
        
        // Map Thumbnail
        MapThumbnail(location: location) {
          showingMapView = true
        }
      }
      
      // Contact Information
      if location.phone != nil || location.email != nil {
        HStack(spacing: 16) {
          if let phone = location.phone {
            Button(action: { callLocation(phone) }) {
              HStack(spacing: 6) {
                Image(systemName: "phone.fill")
                  .foregroundColor(KMTheme.accent)
                Text(phone)
                  .foregroundColor(KMTheme.primaryText)
              }
              .font(.caption)
            }
          }
          
          if let email = location.email {
            Button(action: { emailLocation(email) }) {
              HStack(spacing: 6) {
                Image(systemName: "envelope.fill")
                  .foregroundColor(KMTheme.accent)
                Text(email)
                  .foregroundColor(KMTheme.primaryText)
              }
              .font(.caption)
            }
          }
        }
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
  
  private var quickStats: some View {
    HStack(spacing: 12) {
      StatCard(
        title: "Reported Issues",
        value: "\(stats?.openIssuesCount ?? 0)",
        icon: "exclamationmark.triangle",
        color: KMTheme.warning
      )
      
      StatCard(
        title: "Completed",
        value: "\(stats?.completedIssuesCount ?? 0)",
        icon: "checkmark.circle",
        color: KMTheme.success
      )
      
      StatCard(
        title: "Health Score",
        value: "\(stats?.aiHealthScore ?? 0)%",
        icon: "brain.head.profile",
        color: KMTheme.aiGreen
      )
    }
  }
  
  private var tabSelector: some View {
    HStack(spacing: 0) {
      LocationTabButton(title: "Issues", isSelected: selectedTab == 0) {
        selectedTab = 0
      }
      
      LocationTabButton(title: "Details", isSelected: selectedTab == 1) {
        selectedTab = 1
      }
    }
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  @ViewBuilder
  private var tabContent: some View {
    switch selectedTab {
    case 0:
      issuesTab
    case 1:
      detailsTab
    default:
      issuesTab
    }
  }
  
  private var issuesTab: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Recent Issues")
        .font(.headline)
        .foregroundColor(KMTheme.primaryText)
      
      if issues.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "checkmark.circle")
            .font(.system(size: 40))
            .foregroundColor(KMTheme.success)
          
          Text("No Issues Found")
            .font(.headline)
            .foregroundColor(KMTheme.primaryText)
          
          Text("This location is running smoothly!")
            .font(.body)
            .foregroundColor(KMTheme.secondaryText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(KMTheme.cardBackground)
        .cornerRadius(16)
      } else {
        LazyVStack(spacing: 12) {
          ForEach(issues.prefix(10)) { issue in
            NavigationLink(destination: IssueDetailView(issue: .constant(issue))) {
              IssueRowCard(issue: issue)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      }
    }
  }
  
  
  private var detailsTab: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Location Details")
        .font(.headline)
        .foregroundColor(KMTheme.primaryText)
      
      VStack(spacing: 16) {
        if let hours = location.operatingHours {
          LocationDetailRow(title: "Operating Hours", value: hours, icon: "clock")
        }
        
        if let timezone = location.timezone {
          LocationDetailRow(title: "Timezone", value: timezone, icon: "globe")
        }
        
        LocationDetailRow(title: "Location ID", value: location.id, icon: "number")
        
        LocationDetailRow(title: "Last Updated", value: formatDate(location.updatedAt), icon: "calendar")
        
        if isKevinAdmin {
          LocationDetailRow(title: "Restaurant ID", value: location.restaurantId, icon: "building.2")
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
  }
  
  private func loadIssues() {
    Task {
      do {
        isLoading = true
        
        // Load issues for this location
        let allIssues = try await appState.firebaseClient.listIssues()
        let locationIssues = allIssues.filter { issue in
          // Filter by restaurant ID since we don't have direct location linking yet
          issue.restaurantId == location.restaurantId
        }
        
        await MainActor.run {
          self.issues = locationIssues.sorted { $0.createdAt > $1.createdAt }
          self.isLoading = false
        }
      } catch {
        print("❌ [LocationDetailView] Failed to load location data: \(error)")
        await MainActor.run {
          self.isLoading = false
        }
      }
    }
  }
  
  
  private func callLocation(_ phone: String) {
    if let url = URL(string: "tel:\(phone)") {
      UIApplication.shared.open(url)
    }
  }
  
  private func emailLocation(_ email: String) {
    if let url = URL(string: "mailto:\(email)") {
      UIApplication.shared.open(url)
    }
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}

// MARK: - Supporting Views

struct StatCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color
  
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(color)
      
      Text(value)
        .font(.title3)
        .fontWeight(.bold)
        .foregroundColor(KMTheme.primaryText)
      
      Text(title)
        .font(.caption)
        .foregroundColor(KMTheme.secondaryText)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
}

struct LocationTabButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(isSelected ? .white : KMTheme.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isSelected ? KMTheme.accent : Color.clear)
        .cornerRadius(8)
    }
    .buttonStyle(PlainButtonStyle())
  }
}

struct IssueRowCard: View {
  let issue: Issue
  
  var body: some View {
    HStack(spacing: 12) {
      // Status indicator
      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(issue.title)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
          .lineLimit(1)
        
        Text(issue.description ?? "No description")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
          .lineLimit(2)
      }
      
      Spacer()
      
      VStack(alignment: .trailing, spacing: 4) {
        Text(issue.status.displayName)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(statusColor)
        
        Text(formatDate(issue.createdAt))
          .font(.caption2)
          .foregroundColor(KMTheme.tertiaryText)
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
  
  private var statusColor: Color {
    switch issue.status {
    case .reported: return KMTheme.warning
    case .in_progress: return KMTheme.accent
    case .completed: return KMTheme.success
    }
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

struct AnalyticsCard: View {
  let title: String
  let value: String
  let subtitle: String
  let icon: String
  let color: Color
  
  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(color)
        .frame(width: 40)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        Text(subtitle)
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      Spacer()
      
      Text(value)
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(color)
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
}

struct LocationDetailRow: View {
  let title: String
  let value: String
  let icon: String
  
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundColor(KMTheme.accent)
        .frame(width: 20)
      
      Text(title)
        .font(.subheadline)
        .foregroundColor(KMTheme.secondaryText)
      
      Spacer()
      
      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(KMTheme.primaryText)
        .multilineTextAlignment(.trailing)
    }
    .padding(.vertical, 8)
  }
}

