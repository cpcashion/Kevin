import SwiftUI
import MapKit

// MARK: - Simplified Locations Map View
// Guaranteed to show all locations with proper coordinates

struct SimpleLocationsMapView: View {
    let locations: [SimpleLocation]
    let locationStats: [String: LocationStats]
    
    // Removed selectedLocation and showingLocationDetail - map pins now just dismiss the map
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), // Center of US
        span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
    )
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Map View - Full Screen
                    Map(coordinateRegion: $mapRegion, annotationItems: locationsWithCoordinates) { location in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: location.latitude ?? 0,
                            longitude: location.longitude ?? 0
                        )) {
                            SimpleLocationMapPin(
                                location: location,
                                stats: locationStats[location.id],
                                onTap: {
                                    // Just dismiss the map instead of opening another detail view
                                    dismiss()
                                }
                            )
                        }
                    }
                    .mapStyle(.standard)
                    .ignoresSafeArea(.all)
                    .onAppear {
                        centerMapOnLocations()
                    }
                    
                    // Top Navigation Bar
                    VStack {
                        topBar
                        Spacer()
                    }
                    
                    // Bottom Panel
                    if !locations.isEmpty {
                        VStack(spacing: 0) {
                            Spacer()
                            bottomPanel
                        }
                        .ignoresSafeArea(.container, edges: .bottom)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - View Components
    
    private var topBar: some View {
        HStack {
            // Back Button
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
            Text("\(locations.count) Locations")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    private var bottomPanel: some View {
        VStack(spacing: 16) {
            // Handle Bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
            
            // Stats Grid
            HStack(spacing: 12) {
                MapStatCard(
                    title: "Healthy",
                    value: "\(healthyCount)",
                    subtitle: "",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                MapStatCard(
                    title: "Warning",
                    value: "\(warningCount)",
                    subtitle: "",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
                MapStatCard(
                    title: "Critical",
                    value: "\(criticalCount)",
                    subtitle: "",
                    icon: "xmark.circle.fill",
                    color: .red
                )
            }
            
            // Quick Stats
            HStack(spacing: 16) {
                QuickStat(
                    title: "Total Issues",
                    value: "\(totalActiveIssues)",
                    icon: "exclamationmark.triangle",
                    color: .red
                )
                QuickStat(
                    title: "Avg Health",
                    value: "\(averageHealthScore)%",
                    icon: "brain.head.profile",
                    color: .blue
                )
                QuickStat(
                    title: "Online",
                    value: "\(onlineCount)/\(locations.count)",
                    icon: "wifi",
                    color: .green
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    // MARK: - Computed Properties
    
    private var locationsWithCoordinates: [SimpleLocation] {
        locations.filter { $0.latitude != nil && $0.longitude != nil }
    }
    
    private var healthyCount: Int {
        locations.filter { location in
            guard let healthScore = locationStats[location.id]?.aiHealthScore else { return false }
            return healthScore >= 80
        }.count
    }
    
    private var warningCount: Int {
        locations.filter { location in
            guard let healthScore = locationStats[location.id]?.aiHealthScore else { return false }
            return healthScore >= 50 && healthScore < 80
        }.count
    }
    
    private var criticalCount: Int {
        locations.filter { location in
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
        guard !locations.isEmpty else { return }
        
        print("🗺️ [SimpleLocationsMapView] Centering map on \(locations.count) locations")
        
        // If single location, center it properly
        if locations.count == 1, let location = locations.first,
           let lat = location.latitude, let lng = location.longitude {
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            return
        }
        
        // Calculate bounds for multiple locations
        let latitudes = locations.compactMap { $0.latitude }
        let longitudes = locations.compactMap { $0.longitude }
        
        guard !latitudes.isEmpty && !longitudes.isEmpty else { return }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2.0
        let centerLon = (minLon + maxLon) / 2.0
        
        let spanLat = max(maxLat - minLat, 0.01) * 1.3 // Add 30% padding
        let spanLon = max(maxLon - minLon, 0.01) * 1.3
        
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
        
        print("✅ [SimpleLocationsMapView] Map centered on region: \(centerLat), \(centerLon)")
    }
}

// MARK: - Simple Location Map Pin

struct SimpleLocationMapPin: View {
    let location: SimpleLocation
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
                // Pin Design
                VStack(spacing: 0) {
                    ZStack {
                        // Outer glow for critical locations
                        if (stats?.aiHealthScore ?? 100) < 50 {
                            Circle()
                                .fill(pinColor.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .blur(radius: 4)
                        }
                        
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
                    
                    // Pin pointer
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
                
                // Pulse animation for critical locations
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

// MARK: - Supporting Views

struct QuickStat: View {
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

// MARK: - Preview

struct SimpleLocationsMapView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleLocationsMapView(
            locations: Array(MasterLocationData.locations.prefix(5)),
            locationStats: [:]
        )
    }
}
