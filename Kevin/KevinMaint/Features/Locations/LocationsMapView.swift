import SwiftUI
import MapKit

struct LocationsMapView: View {
  let locations: [Location]
  let locationStats: [String: LocationStats]
  @EnvironmentObject var appState: AppState
  // Removed selectedLocation and showingLocationDetail - map pins now do nothing to prevent infinite loops
  @State private var mapRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), // Center of US
    span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
  )
  @State private var panelHeight: CGFloat = 350
  @State private var isMinimized = false
  @Environment(\.dismiss) private var dismiss
  
  private let minPanelHeight: CGFloat = 100
  private var maxPanelHeight: CGFloat {
    // Make panel fill from current position to absolute bottom of screen
    UIScreen.main.bounds.height - 200 // Leave 200pts for map viewing area
  }
  
  var isKevinAdmin: Bool {
    appState.currentAppUser?.role == .admin
  }
  
  // Filter locations that have coordinates
  var mappableLocations: [Location] {
    return locations.filter { location in
      guard let lat = location.latitude, let lng = location.longitude else {
        return false
      }
      // Filter out invalid coordinates (0,0 or extreme values)
      return !(lat == 0.0 && lng == 0.0)
    }
  }
  
  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ZStack(alignment: .bottom) {
          // Map View - Full Screen
          Map(coordinateRegion: $mapRegion, annotationItems: mappableLocations) { location in
            MapAnnotation(coordinate: CLLocationCoordinate2D(
              latitude: location.latitude ?? 0,
              longitude: location.longitude ?? 0
            )) {
              LocationMapPin(
                location: location,
                stats: locationStats[location.id],
                onTap: {
                  // Just dismiss the map instead of opening another detail view
                  // This prevents infinite loop when already in LocationDetailView
                  // Note: LocationsMapView doesn't have dismiss, so we do nothing
                }
              )
            }
          }
          .mapStyle(.standard)
          .ignoresSafeArea(.all)
          .onAppear {
            centerMapOnLocations()
          }
          .onChange(of: mappableLocations) {
            centerMapOnLocations()
          }
          
          // Top Navigation Bar - Floating
          VStack {
            modernTopBar
            Spacer()
          }
          
          // Bottom Panel - Properly positioned
          if !mappableLocations.isEmpty {
            VStack(spacing: 0) {
              Spacer()
              redesignedBottomPanel
            }
            .ignoresSafeArea(.container, edges: .bottom)
          }
          
          // Removed location detail sheet to prevent infinite loops
        }
      }
    }
    .navigationBarHidden(true)
  }
  
  // MARK: - Modern UI Components
  
  private var modernTopBar: some View {
    HStack {
      // Close Button
      Button(action: { dismiss() }) {
        HStack(spacing: 8) {
          Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .semibold))
          Text("Back")
            .font(.system(size: 16, weight: .medium))
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
      }
      
      Spacer()
      
      // Location Counter
      Text("\(mappableLocations.count) Locations")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
      
      // Map Style Toggle
      Button(action: {
        // Future: Toggle map style
      }) {
        Image(systemName: "map")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.primary)
          .frame(width: 36, height: 36)
          .background(.regularMaterial, in: Circle())
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 60)
  }
  
  private var redesignedBottomPanel: some View {
    VStack(spacing: 0) {
      // Handle Bar
      RoundedRectangle(cornerRadius: 2.5)
        .fill(Color.secondary.opacity(0.4))
        .frame(width: 36, height: 5)
        .padding(.top, 12)
        .padding(.bottom, 16)
      
      // Content based on minimized state
      if isMinimized {
        // Minimized: Show critical info in one line
        HStack(spacing: 16) {
          // Critical Alert or All Good
          if criticalCount > 0 {
            HStack(spacing: 6) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red)
              Text("\(criticalCount) Critical")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.red)
            }
          } else {
            HStack(spacing: 6) {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)
              Text("All Good")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.green)
            }
          }
          
          Spacer()
          
          // Key Metrics
          HStack(spacing: 20) {
            VStack(spacing: 2) {
              Text("\(totalActiveIssues)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(totalActiveIssues > 0 ? .orange : .secondary)
              Text("Issues")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            }
            
            VStack(spacing: 2) {
              Text("\(averageHealthScore)%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(healthColor(for: averageHealthScore))
              Text("Health")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      } else {
        // Expanded: Show detailed information
        VStack(spacing: 20) {
          // Health Status Cards
          HStack(spacing: 12) {
            HealthStatusCard(title: "Healthy", count: healthyCount, color: .green, icon: "checkmark.circle.fill")
            HealthStatusCard(title: "Warning", count: warningCount, color: .orange, icon: "exclamationmark.triangle.fill")
            HealthStatusCard(title: "Critical", count: criticalCount, color: .red, icon: "xmark.circle.fill")
          }
          
          // Quick Actions
          HStack(spacing: 12) {
            MapQuickActionButton(title: "Filter", icon: "line.3.horizontal.decrease.circle", action: {})
            MapQuickActionButton(title: "Search", icon: "magnifyingglass.circle", action: {})
            MapQuickActionButton(title: "Directions", icon: "location.circle", action: {})
          }
          
          // Stats Grid
          HStack(spacing: 16) {
            MapStatItem(title: "Total Issues", value: "\(totalActiveIssues)", icon: "exclamationmark.triangle", color: .red)
            MapStatItem(title: "Avg Health", value: "\(averageHealthScore)%", icon: "brain.head.profile", color: .blue)
            MapStatItem(title: "Online", value: "\(onlineCount)/\(mappableLocations.count)", icon: "wifi", color: .green)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
      }
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.3)) {
        isMinimized.toggle()
      }
    }
  }
  
  
  private func healthColor(for score: Int) -> Color {
    if score >= 80 { return .green }
    else if score >= 50 { return .orange }
    else { return .red }
  }
  
  private var averageResponseTime: String {
    let responseTimes = locationStats.values.compactMap { stats -> Double? in
      // Parse response time string (e.g., "2.5h" -> 2.5)
      let timeStr = stats.averageResponseTime
      if timeStr.hasSuffix("h") {
        return Double(timeStr.dropLast()) ?? 0
      } else if timeStr.hasSuffix("m") {
        return (Double(timeStr.dropLast()) ?? 0) / 60.0
      }
      return nil
    }
    
    guard !responseTimes.isEmpty else { return "N/A" }
    let avgHours = responseTimes.reduce(0, +) / Double(responseTimes.count)
    
    if avgHours < 1 {
      return "\(Int(avgHours * 60))m"
    } else {
      return String(format: "%.1fh", avgHours)
    }
  }
  
  
  // MARK: - Computed Properties
  
  private var healthyCount: Int {
    mappableLocations.filter { location in
      guard let healthScore = locationStats[location.id]?.aiHealthScore else { return false }
      return healthScore >= 80
    }.count
  }
  
  private var warningCount: Int {
    mappableLocations.filter { location in
      guard let healthScore = locationStats[location.id]?.aiHealthScore else { return false }
      return healthScore >= 50 && healthScore < 80
    }.count
  }
  
  private var criticalCount: Int {
    mappableLocations.filter { location in
      guard let healthScore = locationStats[location.id]?.aiHealthScore else { return false }
      return healthScore < 50
    }.count
  }
  
  private var totalActiveIssues: Int {
    locationStats.values.reduce(0) { $0 + $1.openIssuesCount }
  }
  
  private var averageHealthScore: Int {
    let scores = locationStats.values.map { $0.aiHealthScore }
    guard !scores.isEmpty else { return 0 }
    return scores.reduce(0, +) / scores.count
  }
  
  private var onlineCount: Int {
    locationStats.values.filter { $0.isOnline }.count
  }
  
  // MARK: - Helper Methods
  
  private func centerMapOnLocations() {
    guard !mappableLocations.isEmpty else { return }
    
    let coordinates = mappableLocations.compactMap { location -> CLLocationCoordinate2D? in
      guard let lat = location.latitude, let lon = location.longitude else { return nil }
      return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    guard !coordinates.isEmpty else { return }
    
    // If single location, center it properly in the visible map area
    if mappableLocations.count == 1, let location = mappableLocations.first,
       let lat = location.latitude, let lon = location.longitude {
      
      // Center the pin in the visible area above the bottom panel
      // Since the panel takes up bottom space, shift the map center UP
      // so the pin appears centered in the visible map area above the card
      let offsetLatitude = lat - 0.005 // Move map center up to center pin in visible area
      
      mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: offsetLatitude, longitude: lon),
        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012) // Tighter zoom for single location
      )
      return
    }
    
    // Calculate the center and span to fit all locations
    let minLat = coordinates.map { $0.latitude }.min() ?? 0
    let maxLat = coordinates.map { $0.latitude }.max() ?? 0
    let minLon = coordinates.map { $0.longitude }.min() ?? 0
    let maxLon = coordinates.map { $0.longitude }.max() ?? 0
    
    let centerLat = (minLat + maxLat) / 2
    let centerLon = (minLon + maxLon) / 2
    
    let spanLat = max(maxLat - minLat, 0.01) * 1.3 // Add 30% padding
    let spanLon = max(maxLon - minLon, 0.01) * 1.3
    
    mapRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
      span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
    )
  }
}

// MARK: - Modern UI Components

struct HealthStatusCard: View {
  let title: String
  let count: Int
  let color: Color
  let icon: String
  
  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(color)
        
        Text("\(count)")
          .font(.system(size: 20, weight: .bold, design: .rounded))
          .foregroundColor(.primary)
      }
      
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(color.opacity(0.2), lineWidth: 1)
    )
  }
}

struct MapQuickActionButton: View {
  let title: String
  let icon: String
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(.blue)
        
        Text(title)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.primary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(PlainButtonStyle())
  }
}

struct MapStatItem: View {
  let title: String
  let value: String
  let icon: String
  let color: Color
  
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(color)
      
      Text(value)
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundColor(.primary)
      
      Text(title)
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

struct MapStatCard: View {
  let title: String
  let value: String
  let subtitle: String
  let icon: String
  let color: Color
  
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(color)
      
      VStack(spacing: 2) {
        Text(value)
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundColor(.primary)
        
        Text(title)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
        
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 9, weight: .regular))
            .foregroundColor(.secondary.opacity(0.7))
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

// MARK: - Supporting Views

struct LocationMapPin: View {
  let location: Location
  let stats: LocationStats?
  let onTap: () -> Void
  
  private var pinColor: Color {
    guard let healthScore = stats?.aiHealthScore else { return .gray }
    
    if healthScore >= 80 {
      return .green
    } else if healthScore >= 50 {
      return .orange
    } else {
      return .red
    }
  }
  
  private var hasIssues: Bool {
    (stats?.openIssuesCount ?? 0) > 0
  }
  
  var body: some View {
    Button(action: onTap) {
      ZStack {
        // Modern pin design
        VStack(spacing: 0) {
          ZStack {
            // Outer glow
            Circle()
              .fill(pinColor.opacity(0.3))
              .frame(width: 44, height: 44)
              .blur(radius: 4)
            
            // Main pin body
            Circle()
              .fill(.white)
              .frame(width: 36, height: 36)
              .overlay(
                Circle()
                  .fill(pinColor)
                  .frame(width: 28, height: 28)
              )
              .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            // Status indicator
            if hasIssues {
              Image(systemName: "exclamationmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            } else {
              Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            }
          }
          
          // Modern pin pointer
          Triangle()
            .fill(.white)
            .frame(width: 14, height: 10)
            .overlay(
              Triangle()
                .fill(pinColor)
                .frame(width: 10, height: 7)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .offset(y: -3)
        }
        
        // Enhanced pulse animation for critical locations
        if (stats?.aiHealthScore ?? 100) < 50 {
          Circle()
            .stroke(pinColor.opacity(0.6), lineWidth: 3)
            .frame(width: 60, height: 60)
            .scaleEffect(1.2)
            .opacity(0.8)
            .animation(
              Animation.easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true),
              value: stats?.aiHealthScore
            )
        }
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}

struct Triangle: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.closeSubpath()
    return path
  }
}

struct LegendItem: View {
  let color: Color
  let label: String
  let count: Int
  
  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 12, height: 12)
      
      Text(label)
        .font(.caption)
        .foregroundColor(.white)
      
      Text("(\(count))")
        .font(.caption)
        .foregroundColor(.white.opacity(0.8))
    }
  }
}

struct QuickStatItem: View {
  let title: String
  let value: String
  let icon: String
  
  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.caption)
          .foregroundColor(.white.opacity(0.8))
        
        Text(value)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.white)
      }
      
      Text(title)
        .font(.caption2)
        .foregroundColor(.white.opacity(0.7))
    }
  }
}

// MARK: - Preview

struct LocationsMapView_Previews: PreviewProvider {
  static var previews: some View {
    LocationsMapView(
      locations: [
        Location(
          restaurantId: "test1",
          name: "Test Restaurant 1",
          address: "123 Main St",
          latitude: 40.7128,
          longitude: -74.0060
        ),
        Location(
          restaurantId: "test2",
          name: "Test Restaurant 2",
          address: "456 Oak Ave",
          latitude: 34.0522,
          longitude: -118.2437
        )
      ],
      locationStats: [:]
    )
    .environmentObject(AppState())
  }
}
