import Foundation
import CoreLocation

/// Service to determine if Kevin maintenance services are available in a user's area
class ServiceAvailabilityService {
    static let shared = ServiceAvailabilityService()
    
    // MARK: - Service Area Definition
    
    /// Charlotte, NC metro area center point
    private let charlotteCenter = CLLocationCoordinate2D(
        latitude: 35.2271,
        longitude: -80.8431
    )
    
    /// Service radius in meters (approximately 50 miles from Charlotte center)
    /// Covers Charlotte metro area including: Charlotte, Concord, Gastonia, Rock Hill, Huntersville, Matthews, Mint Hill, etc.
    private let serviceRadiusMeters: Double = 80_467 // 50 miles
    
    // MARK: - Availability Check
    
    /// Check if Kevin services are available at the given location
    func isServiceAvailable(at coordinate: CLLocationCoordinate2D) -> ServiceAvailability {
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let charlotteLocation = CLLocation(latitude: charlotteCenter.latitude, longitude: charlotteCenter.longitude)
        
        let distanceInMeters = userLocation.distance(from: charlotteLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMeters <= serviceRadiusMeters {
            return .available(distanceFromCenter: distanceInMiles)
        } else {
            return .unavailable(
                distanceFromCenter: distanceInMiles,
                nearestServiceCity: "Charlotte, NC"
            )
        }
    }
    
    /// Check if a business location is within service area
    func isServiceAvailable(for business: NearbyBusiness) -> ServiceAvailability {
        let coordinate = CLLocationCoordinate2D(latitude: business.latitude, longitude: business.longitude)
        return isServiceAvailable(at: coordinate)
    }
    
    /// Get user-friendly message about service availability
    func getAvailabilityMessage(for availability: ServiceAvailability) -> AvailabilityMessage {
        switch availability {
        case .available:
            return AvailabilityMessage(
                isAvailable: true,
                title: "Kevin is Available! 🎉",
                message: "Great news! Kevin provides maintenance services in your area.",
                detailMessage: "",
                actionText: "Continue",
                showWarning: false
            )
            
        case .unavailable:
            return AvailabilityMessage(
                isAvailable: false,
                title: "Coming Soon to Your Area",
                message: "Kevin isn't available in your location yet, but we're expanding! We're currently serving the greater Charlotte, NC metro area.",
                detailMessage: "",
                actionText: "Join Waitlist",
                showWarning: true
            )
        }
    }
}

// MARK: - Models

enum ServiceAvailability {
    case available(distanceFromCenter: Double)
    case unavailable(distanceFromCenter: Double, nearestServiceCity: String)
    
    var isAvailable: Bool {
        switch self {
        case .available: return true
        case .unavailable: return false
        }
    }
}

struct AvailabilityMessage {
    let isAvailable: Bool
    let title: String
    let message: String
    let detailMessage: String
    let actionText: String
    let showWarning: Bool
}
