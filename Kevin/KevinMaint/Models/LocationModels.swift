import Foundation
import CoreLocation

// MARK: - Enhanced Location Models for Magical Location Detection

// Enhanced Issue with Location Context (extends base Issue model)
struct IssueWithLocationContext: Codable {
  let issue: Issue
  let locationContext: IssueLocationContext?
  let detectionMethod: LocationDetectionMethod?
  let locationConfidence: Double? // 0.0 to 1.0
  
  init(issue: Issue, locationContext: IssueLocationContext? = nil) {
    self.issue = issue
    self.locationContext = locationContext
    self.detectionMethod = locationContext?.detectionMethod
    self.locationConfidence = locationContext?.confidence
  }
}

struct IssueLocationContext: Codable {
  let detectedAt: Date
  let latitude: Double
  let longitude: Double
  let accuracy: Double
  let wifiFingerprint: String? // Hashed for privacy
  let detectionMethod: LocationDetectionMethod
  let confidence: Double
  let alternativeRestaurants: [String]? // IDs of other nearby restaurants
  let userConfirmed: Bool // Whether user manually confirmed the location
}

enum LocationDetectionMethod: String, Codable {
  case gps_only = "gps_only"
  case wifi_cache = "wifi_cache" 
  case wifi_gps_hybrid = "wifi_gps_hybrid"
  case manual_selection = "manual_selection"
  case admin_override = "admin_override"
  
  var displayName: String {
    switch self {
    case .gps_only: return "GPS Detection"
    case .wifi_cache: return "Wi-Fi Recognition"
    case .wifi_gps_hybrid: return "Smart Detection"
    case .manual_selection: return "Manual Selection"
    case .admin_override: return "Admin Override"
    }
  }
  
  var confidence: Double {
    switch self {
    case .wifi_cache: return 0.95
    case .wifi_gps_hybrid: return 0.90
    case .gps_only: return 0.75
    case .manual_selection: return 1.0
    case .admin_override: return 1.0
    }
  }
}

// MARK: - Location Analytics
struct LocationAnalytics: Codable {
  let restaurantId: String
  let date: Date
  let totalDetections: Int
  let successfulDetections: Int
  let detectionMethods: [LocationDetectionMethod: Int]
  let averageAccuracy: Double
  let wifiCacheHitRate: Double
  let userConfirmationRate: Double
}

struct RestaurantLocationProfile: Codable {
  let restaurantId: String
  let name: String
  let primaryLocation: CLLocationCoordinate2D
  let geofenceRadius: Double // in meters
  let wifiFingerprints: [String] // Known Wi-Fi networks
  let detectionStats: LocationDetectionStats
  let lastUpdated: Date
}

struct LocationDetectionStats: Codable {
  var totalAttempts: Int
  var successfulDetections: Int
  var wifiCacheHits: Int
  var gpsOnlyDetections: Int
  var manualSelections: Int
  var averageAccuracy: Double
  var lastSuccessfulDetection: Date?
  
  var successRate: Double {
    guard totalAttempts > 0 else { return 0.0 }
    return Double(successfulDetections) / Double(totalAttempts)
  }
  
  var wifiCacheEfficiency: Double {
    guard totalAttempts > 0 else { return 0.0 }
    return Double(wifiCacheHits) / Double(totalAttempts)
  }
}

// MARK: - Location Permissions & Privacy
struct LocationPrivacySettings: Codable {
  var allowWifiFingerprinting: Bool
  var allowLocationCaching: Bool
  var shareLocationAnalytics: Bool
  var automaticDetection: Bool
  var cacheRetentionDays: Int
  
  static let `default` = LocationPrivacySettings(
    allowWifiFingerprinting: true,
    allowLocationCaching: true,
    shareLocationAnalytics: true,
    automaticDetection: true,
    cacheRetentionDays: 30
  )
}

// MARK: - Firebase Schema Extensions
extension Issue {
  // Create Issue with Location Context
  func withLocationContext(_ locationContext: IssueLocationContext? = nil) -> IssueWithLocationContext {
    return IssueWithLocationContext(
      issue: self,
      locationContext: locationContext
    )
  }
}

// MARK: - Location Utilities
extension CLLocationCoordinate2D: @retroactive Codable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(latitude, forKey: .latitude)
    try container.encode(longitude, forKey: .longitude)
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let latitude = try container.decode(Double.self, forKey: .latitude)
    let longitude = try container.decode(Double.self, forKey: .longitude)
    self.init(latitude: latitude, longitude: longitude)
  }
  
  private enum CodingKeys: String, CodingKey {
    case latitude, longitude
  }
}

// MARK: - Location Error Handling
enum LocationDetectionError: Error, LocalizedError {
  case permissionDenied
  case locationUnavailable
  case noRestaurantsFound
  case wifiUnavailable
  case cacheCorrupted
  case networkError
  case timeout
  
  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      return "Location permission is required for automatic restaurant detection"
    case .locationUnavailable:
      return "Unable to determine your current location"
    case .noRestaurantsFound:
      return "No restaurants found in your area"
    case .wifiUnavailable:
      return "Wi-Fi information unavailable"
    case .cacheCorrupted:
      return "Location cache needs to be reset"
    case .networkError:
      return "Network error while detecting location"
    case .timeout:
      return "Location detection timed out"
    }
  }
  
  var recoverySuggestion: String? {
    switch self {
    case .permissionDenied:
      return "Please enable location access in Settings"
    case .locationUnavailable:
      return "Make sure you're outdoors or near a window"
    case .noRestaurantsFound:
      return "Try manual restaurant selection"
    case .wifiUnavailable:
      return "Connect to Wi-Fi for better detection"
    case .cacheCorrupted:
      return "Clear app data and try again"
    case .networkError:
      return "Check your internet connection"
    case .timeout:
      return "Try again in a moment"
    }
  }
}

// MARK: - Location Detection Configuration
struct LocationDetectionConfig {
  static let maxDetectionRadius: Double = 500 // meters
  static let highConfidenceRadius: Double = 50 // meters
  static let detectionTimeout: TimeInterval = 10 // seconds
  static let cacheExpiryDays: Double = 30
  static let minAccuracyThreshold: Double = 100 // meters
  static let maxCacheEntries: Int = 100
  
  // Wi-Fi fingerprinting settings
  static let enableWiFiFingerprinting: Bool = true
  static let wifiCacheConfidenceThreshold: Double = 0.8
  static let maxWiFiCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
  
  // Privacy settings
  static let hashWiFiData: Bool = true
  static let anonymizeLocationData: Bool = true
  static let shareAnalytics: Bool = true
}
