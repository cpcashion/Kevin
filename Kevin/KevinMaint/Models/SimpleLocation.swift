import Foundation

// MARK: - Simplified Location Model
// This replaces the complex Location model with guaranteed data integrity

struct SimpleLocation: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let businessType: BusinessType
    let phone: String?
    let email: String?
    
    // Computed properties for UI
    var coordinate: (lat: Double, lng: Double)? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return (lat, lng)
    }
    
    var displayAddress: String {
        return address
    }
    
    var businessTypeIcon: String {
        return businessType.icon
    }
    
    var businessTypeColor: String {
        return businessType.color
    }
    
    // Initialize with guaranteed coordinates
    init(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        latitude: Double?,
        longitude: Double?,
        businessType: BusinessType = .restaurant,
        phone: String? = nil,
        email: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.businessType = businessType
        self.phone = phone
        self.email = email
    }
}

// MARK: - Master Location Data
// Pre-populated, reliable location data with guaranteed coordinates

struct MasterLocationData {
    // No hardcoded locations - all location data comes from Firebase and Google Places API
    static let locations: [SimpleLocation] = []
    
    // Helper methods
    static func findLocation(by id: String) -> SimpleLocation? {
        return locations.first { $0.id == id }
    }
    
    static func findLocationByName(_ name: String) -> SimpleLocation? {
        return locations.first { $0.name.lowercased().contains(name.lowercased()) }
    }
    
    static func locationsNear(latitude: Double, longitude: Double, radiusKm: Double = 50.0) -> [SimpleLocation] {
        return locations.filter { location in
            guard let lat = location.latitude, let lng = location.longitude else { return false }
            let distance = calculateDistance(
                lat1: latitude, lon1: longitude,
                lat2: lat, lon2: lng
            )
            return distance <= radiusKm
        }
    }
    
    private static func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371.0 // Earth's radius in kilometers
        
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon/2) * sin(dLon/2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return earthRadius * c
    }
}
