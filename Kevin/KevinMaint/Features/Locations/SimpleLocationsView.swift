import SwiftUI

// MARK: - Simplified Locations View
// Clean, reliable locations display with guaranteed map functionality

struct SimpleLocationsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingMapView = false
    @State private var hasTriggeredLoad = false
    @State private var refreshTrigger = false
    @State private var locationsService: SimpleLocationsService?
    
    // Use shared service from AppState for consistency
    private var service: SimpleLocationsService {
        locationsService ?? appState.locationsService
    }
    
    var isKevinAdmin: Bool {
        appState.currentAppUser?.role == .admin
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KMTheme.background.ignoresSafeArea()
                
                Group {
                    if service.isLoading {
                        loadingView
                    } else if service.locations.isEmpty {
                        emptyStateView
                    } else {
                        contentView
                    }
                }
                // Force UI refresh when data changes
                .id(refreshTrigger)
            }
            .navigationTitle("Business Locations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    mapButton
                }
            }
            .sheet(isPresented: $showingMapView) {
                SimpleLocationsMapView(
                    locations: service.locations,
                    locationStats: service.locationStats
                )
            }
            .onAppear {
                // Set the service reference to ensure observation
                if locationsService == nil {
                    locationsService = appState.locationsService
                }
                
                print("🎯 [SimpleLocationsView] onAppear - locations: \(service.locations.count), isLoading: \(service.isLoading), hasTriggeredLoad: \(hasTriggeredLoad)")
                
                // Always load if we don't have data, regardless of hasTriggeredLoad
                if service.locations.isEmpty && !service.isLoading && appState.currentAppUser != nil {
                    print("🚀 [SimpleLocationsView] Starting location load task (locations empty)")
                    hasTriggeredLoad = true
                    Task {
                        await service.loadLocations()
                        // Force UI refresh after loading
                        await MainActor.run {
                            refreshTrigger.toggle()
                        }
                    }
                } else {
                    print("⚡ [SimpleLocationsView] Skipping load - locations: \(service.locations.count), isLoading: \(service.isLoading), user: \(appState.currentAppUser?.id ?? "nil")")
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(KMTheme.accent)
            
            Text("Loading locations...")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(KMTheme.accent.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "building.2")
                        .font(.system(size: 32))
                        .foregroundColor(KMTheme.accent)
                }
                
                VStack(spacing: 8) {
                    Text("No Locations Found")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(KMTheme.primaryText)
                    
                    Text("Unable to load business locations")
                        .font(.system(size: 16))
                        .foregroundColor(KMTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 12) {
                Button("Retry") {
                    hasTriggeredLoad = false
                    Task {
                        await service.loadLocations()
                        await MainActor.run {
                            refreshTrigger.toggle()
                        }
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(KMTheme.accent)
                .cornerRadius(12)
                
                Button("Force Refresh") {
                    Task {
                        await service.forceRefresh()
                        await MainActor.run {
                            refreshTrigger.toggle()
                        }
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KMTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(KMTheme.accent.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(32)
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overview Stats
                locationOverview
                
                // Locations List
                locationsList
            }
            .padding(24)
        }
    }
    
    private var locationOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(KMTheme.accent)
                    .font(.title3)
                
                Text(isKevinAdmin ? "All Business Locations" : "Location Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                MetricCard(
                    number: "\(service.locations.count)",
                    label: isKevinAdmin ? "Total Sites" : "Sites",
                    color: KMTheme.accent
                )
                MetricCard(
                    number: "\(totalActiveIssues)",
                    label: "Active Issues",
                    color: KMTheme.warning
                )
                MetricCard(
                    number: "\(averageHealthScore)%",
                    label: "Avg Health",
                    color: KMTheme.success
                )
            }
        }
    }
    
    private var locationsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(service.locations) { location in
                NavigationLink(destination: SimpleLocationDetailView(location: location)) {
                    SimpleLocationCard(
                        location: location,
                        stats: service.getLocationStats(for: location.id)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var mapButton: some View {
        Button(action: { showingMapView = true }) {
            HStack(spacing: 6) {
                Image(systemName: "map")
                    .font(.subheadline)
                Text("Map")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(KMTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    
    private var totalActiveIssues: Int {
        service.locationStats.values.reduce(0) { $0 + $1.openIssuesCount }
    }
    
    private var averageHealthScore: Int {
        let scores = service.locationStats.values.map { $0.aiHealthScore }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / scores.count
    }
}

// MARK: - Simple Location Card

struct SimpleLocationCard: View {
    let location: SimpleLocation
    let stats: LocationStats?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Text(location.displayAddress)
                        .font(.body)
                        .foregroundColor(KMTheme.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(stats?.isOnline == true ? KMTheme.success : KMTheme.warning)
                            .frame(width: 8, height: 8)
                        
                        Text(stats?.isOnline == true ? "Online" : "Offline")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(stats?.isOnline == true ? KMTheme.success : KMTheme.warning)
                    }
                    
                    Text("Last sync: \(stats?.lastSync ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(KMTheme.tertiaryText)
                }
            }
            
            // Stats Row
            HStack(spacing: 20) {
                StatItem(
                    icon: "wrench.and.screwdriver",
                    value: "\(stats?.openIssuesCount ?? 0)",
                    label: "Reported Issues",
                    color: KMTheme.warning
                )
                StatItem(
                    icon: "checkmark.circle",
                    value: "\(stats?.completedIssuesCount ?? 0)",
                    label: "Completed",
                    color: KMTheme.success
                )
                StatItem(
                    icon: "clock",
                    value: stats?.averageResponseTime ?? "N/A",
                    label: "Avg Response",
                    color: KMTheme.accent
                )
            }
            
            // Health Score
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(KMTheme.aiGreen)
                    .font(.caption)
                
                Text("AI Health Score")
                    .font(.caption)
                    .foregroundColor(KMTheme.secondaryText)
                
                Spacer()
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(KMTheme.borderSecondary)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                        
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [KMTheme.aiGreen, KMTheme.aiGreenDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(
                                width: geometry.size.width * Double(stats?.aiHealthScore ?? 0) / 100.0,
                                height: 3
                            )
                            .cornerRadius(1.5)
                    }
                }
                .frame(width: 80, height: 3)
                
                Text("\(stats?.aiHealthScore ?? 0)%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.aiGreen)
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

// MARK: - Supporting Components

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(KMTheme.tertiaryText)
        }
    }
}

// MARK: - Preview

struct SimpleLocationsView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleLocationsView()
            .environmentObject(AppState())
    }
}
