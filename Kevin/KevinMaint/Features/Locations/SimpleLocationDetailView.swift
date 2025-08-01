import SwiftUI
import MapKit

// MARK: - Simple Location Detail View
// Clean location detail with guaranteed data display

struct SimpleLocationDetailView: View {
    let location: SimpleLocation
    @EnvironmentObject var appState: AppState
    @State private var showingMap = false
    @State private var presentedIssue: Issue?
    @State private var isIssuesExpanded = false
    
    // Use the shared service from AppState instead of creating a new one
    private var locationsService: SimpleLocationsService {
        appState.locationsService
    }
    
    private var locationStats: LocationStats? {
        locationsService.getLocationStats(for: location.id)
    }
    
    private var locationIssues: [Issue] {
        locationsService.getIssuesForLocation(location)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Quick Stats
                    quickStatsSection
                    
                    // Issues at this location
                    issuesSection
                    
                    // Contact Information
                    contactSection
                    
                    // Map Preview
                    mapPreviewSection
                    
                    // Business Information
                    businessInfoSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100) // Extra padding to clear tab bar
            }
            .background(KMTheme.background)
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingMap) {
                SimpleLocationsMapView(
                    locations: [location],
                    locationStats: locationsService.locationStats
                )
            }
            .sheet(item: $presentedIssue) { issue in
                IssueDetailView(
                    issue: Binding(
                        get: { issue },
                        set: { _ in }
                    ),
                    onIssueUpdated: {
                        // Refresh location data when issue is updated
                        Task {
                            await locationsService.loadLocations()
                        }
                    }
                )
                .environmentObject(appState)
                .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            // Only load if we don't have data yet and user is authenticated
            if locationsService.locations.isEmpty && !locationsService.isLoading && appState.currentAppUser != nil {
                Task {
                    await locationsService.loadLocations()
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(location.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    HStack(spacing: 8) {
                        Text(location.businessType.icon)
                            .font(.title3)
                        
                        Text(location.businessType.displayName)
                            .font(.subheadline)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                    
                    Text(location.displayAddress)
                        .font(.body)
                        .foregroundColor(KMTheme.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    // Status Indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(locationStats?.isOnline == true ? KMTheme.success : KMTheme.warning)
                            .frame(width: 8, height: 8)
                        
                        Text(locationStats?.isOnline == true ? "Online" : "Offline")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(locationStats?.isOnline == true ? KMTheme.success : KMTheme.warning)
                    }
                    
                    // Health Score
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(locationStats?.aiHealthScore ?? 95)%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(healthScoreColor)
                        
                        Text("Health Score")
                            .font(.caption)
                            .foregroundColor(KMTheme.tertiaryText)
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
    
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Issues",
                value: "\(locationIssues.count)",
                icon: "list.bullet",
                color: KMTheme.accent
            )
            
            StatCard(
                title: "Active Issues",
                value: "\(locationIssues.filter { $0.status != .completed }.count)",
                icon: "exclamationmark.triangle",
                color: KMTheme.warning
            )
            
            StatCard(
                title: "Completed",
                value: "\(locationIssues.filter { $0.status == .completed }.count)",
                icon: "checkmark.circle",
                color: KMTheme.success
            )
        }
    }
    
    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Always visible and tappable
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isIssuesExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundColor(KMTheme.accent)
                        .font(.title3)
                    
                    Text("Issues at this Location")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Spacer()
                    
                    Text("\(locationIssues.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(locationIssues.isEmpty ? KMTheme.success : KMTheme.accent)
                        .cornerRadius(8)
                    
                    Image(systemName: isIssuesExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.tertiaryText)
                        .padding(.leading, 4)
                }
                .padding(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Collapsible content
            if isIssuesExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(KMTheme.border)
                        .padding(.horizontal, 20)
                    
                    if locationIssues.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.title2)
                                .foregroundColor(KMTheme.success)
                            
                            Text("No Issues")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(KMTheme.primaryText)
                            
                            Text("This location has no reported issues")
                                .font(.caption)
                                .foregroundColor(KMTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(locationIssues) { issue in
                                LocationIssueCard(issue: issue) {
                                    presentedIssue = issue
                                }
                            }
                        }
                        .padding(20)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(KMTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(KMTheme.border, lineWidth: 0.5)
        )
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(KMTheme.accent)
                    .font(.title3)
                
                Text("Contact Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                if let phone = location.phone {
                    ContactRow(
                        icon: "phone.fill",
                        title: "Phone",
                        value: phone,
                        action: {
                            if let url = URL(string: "tel:\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                }
                
                if let email = location.email {
                    ContactRow(
                        icon: "envelope.fill",
                        title: "Email",
                        value: email,
                        action: {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                }
                
                ContactRow(
                    icon: "location.fill",
                    title: "Address",
                    value: location.displayAddress,
                    action: {
                        let query = location.displayAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
                            UIApplication.shared.open(url)
                        }
                    }
                )
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
    
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(KMTheme.accent)
                    .font(.title3)
                
                Text("Location")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                
                Spacer()
            }
            
            // Map Preview - Multiple tap detection methods
            ZStack {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: location.latitude ?? 0, longitude: location.longitude ?? 0),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [location]) { location in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude ?? 0,
                        longitude: location.longitude ?? 0
                    )) {
                        Circle()
                            .fill(KMTheme.accent)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 3)
                            )
                    }
                }
                .allowsHitTesting(false) // Disable map interactions
                .frame(height: 200)
                .cornerRadius(12)
                
                // Invisible overlay to capture taps
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle()) // Make entire area tappable
                    .frame(height: 200)
                    .onTapGesture {
                        print("🗺️ [SimpleLocationDetailView] Map tapped! Opening full map...")
                        showingMap = true
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
    
    private var businessInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(KMTheme.accent)
                    .font(.title3)
                
                Text("Business Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                InfoRow(title: "Business Type", value: location.businessType.displayName)
                InfoRow(title: "Coordinates", value: String(format: "%.6f, %.6f", location.latitude ?? 0, location.longitude ?? 0))
                InfoRow(title: "Last Updated", value: locationStats?.lastSync ?? "Unknown")
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
    
    // MARK: - Computed Properties
    
    private var healthScoreColor: Color {
        let score = locationStats?.aiHealthScore ?? 95
        if score >= 80 {
            return KMTheme.success
        } else if score >= 50 {
            return KMTheme.warning
        } else {
            return KMTheme.danger
        }
    }
}

// MARK: - Supporting Views

struct ContactRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(KMTheme.accent)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                    
                    Text(value)
                        .font(.body)
                        .foregroundColor(KMTheme.primaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(KMTheme.tertiaryText)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(KMTheme.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(KMTheme.primaryText)
        }
        .padding(.vertical, 4)
    }
}

struct LocationIssueCard: View {
    let issue: Issue
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Text(issue.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor)
                            .cornerRadius(4)
                        
                        Text(formatRelativeTime(issue.createdAt))
                            .font(.caption)
                            .foregroundColor(KMTheme.tertiaryText)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(KMTheme.tertiaryText)
            }
            .padding(12)
            .background(KMTheme.background)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KMTheme.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch issue.status {
        case .reported:
            return KMTheme.warning
        case .in_progress:
            return KMTheme.accent
        case .completed:
            return KMTheme.success
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// IssueStatus.displayName extension already exists in the main models

// MARK: - Preview

struct SimpleLocationDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleLocationDetailView(location: SimpleLocation(
            id: "preview",
            name: "Preview Location",
            address: "123 Main St",
            latitude: 35.2271,
            longitude: -80.8431,
            businessType: .restaurant,
            phone: nil,
            email: nil
        ))
        .environmentObject(AppState())
    }
}
