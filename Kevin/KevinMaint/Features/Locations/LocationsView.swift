import SwiftUI

struct LocationsView: View {
  @EnvironmentObject var appState: AppState
  @State private var showingMapView = false
  // Scroll position will be maintained by the shared service state
  
  // Use shared service from AppState for persistence
  private var locationsService: SimpleLocationsService {
    appState.locationsService
  }
  
  // Computed properties for overview stats
  private var totalActiveIssues: Int {
    locationsService.locationStats.values.reduce(0) { $0 + $1.openIssuesCount }
  }
  
  private var overallUptime: String {
    let scores = locationsService.locationStats.values.map { $0.aiHealthScore }
    guard !scores.isEmpty else { return "N/A" }
    let average = scores.reduce(0, +) / scores.count
    return "\(average)%"
  }
  
  var isKevinAdmin: Bool {
    appState.currentAppUser?.role == .admin
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if locationsService.isLoading && locationsService.locations.isEmpty {
          ProgressView("Loading locations...")
            .foregroundColor(KMTheme.secondaryText)
        } else if locationsService.locations.isEmpty && !locationsService.isLoading {
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
                Text("Loading locations...")
                  .font(.system(size: 20, weight: .semibold))
                  .foregroundColor(.white)
                
                Text("We're setting up your business locations")
                  .font(.system(size: 16))
                  .foregroundColor(.white.opacity(0.8))
                  .multilineTextAlignment(.center)
              }
            }
            
            Button("Refresh") {
              Task {
                await locationsService.loadLocations()
              }
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
          ScrollView {
            VStack(spacing: 24) {
              // Location Overview
              locationOverview
              
              // Locations List
              locationsList
            }
            .padding(24)
          }
          .refreshable {
            await locationsService.loadLocations()
          }
        }
      }
      .navigationTitle("All Business Locations")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
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
            .background(KMTheme.accent.opacity(0.1))
            .cornerRadius(12)
          }
        }
      }
      .sheet(isPresented: $showingMapView) {
        SimpleLocationsMapView(
          locations: locationsService.locations,
          locationStats: locationsService.locationStats
        )
      }
      .onAppear {
        print("🎯 [LocationsView] onAppear - locations: \(locationsService.locations.count), isLoading: \(locationsService.isLoading)")
        
        // Only load if we don't have data yet - instant loading for cached data
        if locationsService.locations.isEmpty && !locationsService.isLoading {
          print("🚀 [LocationsView] Starting location load task")
          Task {
            await locationsService.loadLocations()
          }
        } else {
          print("⚡ [LocationsView] Skipping load - already have \(locationsService.locations.count) locations")
        }
      }
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
        MetricCard(number: "\(locationsService.locations.count)", label: isKevinAdmin ? "Total Sites" : "Sites", color: KMTheme.accent)
        MetricCard(number: "\(totalActiveIssues)", label: "Active Issues", color: KMTheme.warning)
        MetricCard(number: overallUptime, label: "Uptime", color: KMTheme.success)
      }
    }
  }
  
  private var locationsList: some View {
    LazyVStack(spacing: 12) {
      ForEach(locationsService.locations) { simpleLocation in
        NavigationLink(destination: SimpleLocationDetailView(location: simpleLocation)) {
          SimpleLocationCard(
            location: simpleLocation,
            stats: locationsService.getLocationStats(for: simpleLocation.id)
          )
        }
        .buttonStyle(PlainButtonStyle())
      }
    }
  }
}
