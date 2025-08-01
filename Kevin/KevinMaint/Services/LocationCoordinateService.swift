import Foundation
import CoreLocation

// MARK: - Location Coordinate Service (Real GPS/Google Places Only)

class LocationCoordinateService {
  
  static func enrichLocationWithCoordinates(_ location: Location) -> Location {
    // Only return locations that already have real coordinates
    // No hardcoded fallbacks - locations without real coordinates should be nil
    if location.latitude != nil && location.longitude != nil {
      return location
    }
    
    // If no real coordinates available, return location as-is with nil coordinates
    // This forces the app to use Google Places API or device GPS
    return location
  }
  
  static func enrichLocations(_ locations: [Location]) -> [Location] {
    return locations.map { enrichLocationWithCoordinates($0) }
  }
}
