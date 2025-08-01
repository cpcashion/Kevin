import SwiftUI
import MapKit

struct MapThumbnail: View {
    let location: Location
    let onTap: () -> Void
    
    @State private var position: MapCameraPosition
    
    init(location: Location, onTap: @escaping () -> Void) {
        self.location = location
        self.onTap = onTap
        
        // Initialize camera position with location coordinates or default
        let coordinate = CLLocationCoordinate2D(
            latitude: location.latitude ?? 35.2271, // Default to Charlotte, NC
            longitude: location.longitude ?? -80.8431
        )
        
        self._position = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Map background with modern iOS 17+ API
                Map(position: .constant(position), interactionModes: []) {
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude ?? 35.2271,
                        longitude: location.longitude ?? -80.8431
                    )) {
                        Circle()
                            .fill(KMTheme.accent)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                .allowsHitTesting(false) // Disable all map interactions including legal links
                .cornerRadius(12)
                
                // Full overlay to capture all taps
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .contentShape(Rectangle()) // Ensure entire area is tappable
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KMTheme.border, lineWidth: 1)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 100, height: 90)
    }
}
