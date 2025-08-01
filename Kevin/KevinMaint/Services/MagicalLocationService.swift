import Foundation
import CoreLocation
import Network
import SystemConfiguration.CaptiveNetwork

// FirebaseClient is a local class - no import needed

// MARK: - Location Context Models
struct LocationContext: Codable {
  let latitude: Double
  let longitude: Double
  let accuracy: Double
  let timestamp: Date
  let wifiFingerprint: WiFiFingerprint?
  let nearbyBusinesses: [NearbyBusiness]
  let suggestedBusiness: NearbyBusiness?
  
  // Legacy support for existing code that expects restaurants
  var nearbyRestaurants: [NearbyBusiness] {
    return nearbyBusinesses.filter { $0.businessType == .restaurant }
  }
  
  var suggestedRestaurant: NearbyBusiness? {
    return suggestedBusiness
  }
}

struct WiFiFingerprint: Codable {
  let ssid: String?
  let bssid: String?
  let signalStrength: Int?
  let timestamp: Date
  
  // Create a unique identifier for this Wi-Fi environment
  var fingerprint: String {
    let components = [ssid ?? "unknown", bssid ?? "unknown"].joined(separator: "_")
    return components.replacingOccurrences(of: " ", with: "_").lowercased()
  }
}

// Using NearbyBusiness from GooglePlacesService instead of NearbyRestaurant
// This allows us to show ALL types of businesses, not just restaurants

struct CachedLocation: Codable {
  let wifiFingerprint: String
  let businessId: String
  let businessName: String
  let businessType: String
  let confidence: Double
  let lastUsed: Date
  let useCount: Int
  
  // Legacy support
  var restaurantId: String { return businessId }
  var restaurantName: String { return businessName }
}

// MARK: - Magical Location Service
@MainActor
class MagicalLocationService: NSObject, ObservableObject {
  static let shared = MagicalLocationService()
  
  @Published var currentLocation: CLLocation?
  @Published var locationContext: LocationContext?
  @Published var isDetectingLocation = false
  @Published var locationError: String?
  @Published var hasLocationPermission = false
  
  private let locationManager = CLLocationManager()
  private let geocoder = CLGeocoder()
  private let googlePlacesService = GooglePlacesService.shared
  private var cachedLocations: [CachedLocation] = []
  
  // Cache the last detection result to prevent duplicate calls
  private var lastDetectionResult: LocationContext?
  private var lastDetectionTime: Date?
  private let detectionCacheDuration: TimeInterval = 5.0 // Cache for 5 seconds
  
  // Constants for location detection
  private let searchRadiusMeters: Int = 1609 // 1 mile = 1609 meters (as requested)
  private let highConfidenceRadius: Double = 150 // meters - for "You're here"
  private let mediumConfidenceRadius: Double = 500 // meters - for good suggestions
  private let cacheExpiryDays: Double = 30
  
  override init() {
    super.init()
    setupLocationManager()
    loadCachedLocations()
    // No need to load restaurants - we'll get live data from Google Places
  }
  
  // MARK: - Setup
  private func setupLocationManager() {
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 10 // Update every 10 meters
  }
  
  private func loadCachedLocations() {
    if let data = UserDefaults.standard.data(forKey: "CachedLocations"),
       let cached = try? JSONDecoder().decode([CachedLocation].self, from: data) {
      // Remove expired cache entries
      let cutoffDate = Date().addingTimeInterval(-cacheExpiryDays * 24 * 60 * 60)
      cachedLocations = cached.filter { $0.lastUsed > cutoffDate }
      saveCachedLocations()
    }
  }
  
  private func saveCachedLocations() {
    if let data = try? JSONEncoder().encode(cachedLocations) {
      UserDefaults.standard.set(data, forKey: "CachedLocations")
    }
  }
  
  // No longer needed - we get live data from Google Places API
  
  // MARK: - Permission Management
  func requestLocationPermission() async -> Bool {
    print("📍 [MagicalLocationService] Requesting location permission...")
    print("📍 [MagicalLocationService] Current authorization status: \(locationManager.authorizationStatus.rawValue)")
    
    return await withCheckedContinuation { continuation in
      switch locationManager.authorizationStatus {
      case .authorizedWhenInUse, .authorizedAlways:
        print("✅ [MagicalLocationService] Already authorized")
        hasLocationPermission = true
        continuation.resume(returning: true)
      case .denied, .restricted:
        print("❌ [MagicalLocationService] Permission denied or restricted")
        hasLocationPermission = false
        continuation.resume(returning: false)
      case .notDetermined:
        print("⏳ [MagicalLocationService] Permission not determined, requesting...")
        // Store continuation to resume when permission is granted/denied
        permissionContinuation = continuation
        locationManager.requestWhenInUseAuthorization()
        
        // Add timeout safety mechanism (10 seconds)
        Task {
          try? await Task.sleep(nanoseconds: 10_000_000_000)
          if permissionContinuation != nil {
            print("⚠️ [MagicalLocationService] Permission request timed out after 10 seconds")
            permissionContinuation?.resume(returning: false)
            permissionContinuation = nil
          }
        }
      @unknown default:
        print("⚠️ [MagicalLocationService] Unknown authorization status")
        hasLocationPermission = false
        continuation.resume(returning: false)
      }
    }
  }
  
  private var permissionContinuation: CheckedContinuation<Bool, Never>?
  
  // MARK: - Magical Location Detection
  func detectLocation() async -> LocationContext? {
    print("🔮 [MagicalLocationService] Starting magical location detection...")
    
    // GUARD: If already detecting, return cached result if available
    if isDetectingLocation {
      print("⚠️ [MagicalLocationService] Already detecting location, returning cached result")
      return lastDetectionResult
    }
    
    // GUARD: Return cached result if recent (within 5 seconds)
    if let lastResult = lastDetectionResult,
       let lastTime = lastDetectionTime,
       Date().timeIntervalSince(lastTime) < detectionCacheDuration {
      print("✅ [MagicalLocationService] Returning cached location result (age: \(Date().timeIntervalSince(lastTime))s)")
      return lastResult
    }
    
    // Reset state
    locationError = nil
    isDetectingLocation = true
    
    defer {
      isDetectingLocation = false
    }
    
    // Step 1: Check Wi-Fi fingerprint for instant recognition
    if let wifiContext = await checkWiFiFingerprint() {
      print("✨ [MagicalLocationService] Instant Wi-Fi recognition successful!")
      return wifiContext
    }
    
    // Step 2: Request location permission if needed
    guard await requestLocationPermission() else {
      locationError = "Location permission is required for automatic restaurant detection"
      return nil
    }
    
    // Step 3: Get current GPS location
    guard let location = await getCurrentLocation() else {
      locationError = "Unable to determine your current location"
      return nil
    }
    
    // Step 4: Find ALL nearby businesses using Google Places API
    let nearbyBusinesses = await findAllNearbyBusinesses(location: location)
    
    // Step 5: Get Wi-Fi fingerprint for future caching
    let wifiFingerprint = await getCurrentWiFiFingerprint()
    
    // Step 6: Determine suggested business
    let suggestedBusiness = determineSuggestedBusiness(
      location: location,
      nearbyBusinesses: nearbyBusinesses
    )
    
    // Step 7: Cache this location for future instant recognition
    if let suggested = suggestedBusiness,
       let wifi = wifiFingerprint {
      cacheLocationMapping(
        wifiFingerprint: wifi.fingerprint,
        business: suggested
      )
    }
    
    let context = LocationContext(
      latitude: location.coordinate.latitude,
      longitude: location.coordinate.longitude,
      accuracy: location.horizontalAccuracy,
      timestamp: Date(),
      wifiFingerprint: wifiFingerprint,
      nearbyBusinesses: nearbyBusinesses,
      suggestedBusiness: suggestedBusiness
    )
    
    locationContext = context
    
    // Cache this result
    lastDetectionResult = context
    lastDetectionTime = Date()
    
    print("✅ [MagicalLocationService] Location context created with \(nearbyBusinesses.count) nearby businesses")
    
    return context
  }
  
  // MARK: - Wi-Fi Fingerprinting
  private func checkWiFiFingerprint() async -> LocationContext? {
    guard let wifiFingerprint = await getCurrentWiFiFingerprint() else {
      return nil
    }
    
    // Check if we have a cached location for this Wi-Fi fingerprint
    if let cached = cachedLocations.first(where: { $0.wifiFingerprint == wifiFingerprint.fingerprint }) {
      print("🎯 [MagicalLocationService] Found cached location for Wi-Fi: \(cached.restaurantName)")
      
      // For cached locations, we'll still do a fresh Google Places search
      // to get the most up-to-date business information
      print("💾 [MagicalLocationService] Found cached location but will refresh with live data")
      // Fall through to do fresh search
    }
    
    return nil
  }
  
  private func getCurrentWiFiFingerprint() async -> WiFiFingerprint? {
    // Note: iOS has restrictions on Wi-Fi scanning for privacy
    // We'll use available network information when possible
    return await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .utility).async {
        var ssid: String?
        var bssid: String?
        
        // Try to get current Wi-Fi SSID (requires location permission and entitlements)
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
          for interface in interfaces {
            if let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any] {
              ssid = info[kCNNetworkInfoKeySSID as String] as? String
              bssid = info[kCNNetworkInfoKeyBSSID as String] as? String
              break
            }
          }
        }
        
        let fingerprint = WiFiFingerprint(
          ssid: ssid,
          bssid: bssid,
          signalStrength: nil, // Not available through public APIs
          timestamp: Date()
        )
        
        DispatchQueue.main.async {
          continuation.resume(returning: ssid != nil ? fingerprint : nil)
        }
      }
    }
  }
  
  // MARK: - GPS Location
  private func getCurrentLocation() async -> CLLocation? {
    return await withCheckedContinuation { continuation in
      locationContinuation = continuation
      locationManager.requestLocation()
    }
  }
  
  private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
  
  // MARK: - Business Discovery using Google Places API
  private func findAllNearbyBusinesses(location: CLLocation) async -> [NearbyBusiness] {
    do {
      print("🌍 [MagicalLocationService] Searching Google Places for ALL businesses within 1 mile...")
      
      let businesses = try await googlePlacesService.findAllNearbyBusinesses(
        location: location,
        radiusInMeters: searchRadiusMeters
      )
      
      print("✅ [MagicalLocationService] Found \(businesses.count) businesses from Google Places API")
      
      // Print breakdown by business type
      let breakdown = Dictionary(grouping: businesses, by: { $0.businessType })
      for (type, businessList) in breakdown.sorted(by: { $0.value.count > $1.value.count }) {
        print("   \(type.icon) \(type.displayName): \(businessList.count)")
      }
      
      return businesses
      
    } catch {
      print("❌ [MagicalLocationService] Google Places search failed: \(error)")
      return []
    }
  }
  
  private func determineSuggestedBusiness(
    location: CLLocation,
    nearbyBusinesses: [NearbyBusiness]
  ) -> NearbyBusiness? {
    guard !nearbyBusinesses.isEmpty else { return nil }
    
    // Sort all businesses by distance to ensure consistency
    let sortedBusinesses = nearbyBusinesses.sorted { $0.distance < $1.distance }
    
    // Prioritize restaurants for suggestions, but allow any business type
    let restaurants = sortedBusinesses.filter { $0.businessType == .restaurant }
    let businessesToConsider = restaurants.isEmpty ? sortedBusinesses : restaurants
    
    // Log the top 3 businesses being considered
    print("🔍 [MagicalLocationService] Top businesses being considered:")
    for (index, business) in businessesToConsider.prefix(3).enumerated() {
      print("   \(index + 1). \(business.name) (\(business.businessType.displayName)) - \(String(format: "%.0f", business.distance))m")
    }
    
    // Return the closest business if within high confidence radius
    if let closest = businessesToConsider.first,
       closest.distance <= highConfidenceRadius {
      print("✅ [MagicalLocationService] High confidence suggestion: \(closest.name) (\(closest.businessType.displayName)) at \(String(format: "%.0f", closest.distance))m")
      return closest
    }
    
    // If no high-confidence match, return the closest one if within medium confidence radius
    if let closest = businessesToConsider.first,
       closest.distance <= mediumConfidenceRadius {
      print("⚡ [MagicalLocationService] Medium confidence suggestion: \(closest.name) (\(closest.businessType.displayName)) at \(String(format: "%.0f", closest.distance))m")
      return closest
    }
    
    // If still no match but we have nearby businesses, suggest the closest one
    if let closest = businessesToConsider.first,
       closest.distance <= Double(searchRadiusMeters) {
      print("🤔 [MagicalLocationService] Low confidence suggestion: \(closest.name) (\(closest.businessType.displayName)) at \(String(format: "%.0f", closest.distance))m")
      return closest
    }
    
    print("❌ [MagicalLocationService] No suitable business suggestion found")
    return nil
  }
  
  // MARK: - Caching
  private func cacheLocationMapping(wifiFingerprint: String, business: NearbyBusiness) {
    // Remove existing cache for this Wi-Fi fingerprint
    cachedLocations.removeAll { $0.wifiFingerprint == wifiFingerprint }
    
    // Add new cache entry
    let cached = CachedLocation(
      wifiFingerprint: wifiFingerprint,
      businessId: business.id,
      businessName: business.name,
      businessType: business.businessType.rawValue,
      confidence: business.distance <= highConfidenceRadius ? 1.0 : 0.8,
      lastUsed: Date(),
      useCount: 1
    )
    
    cachedLocations.append(cached)
    saveCachedLocations()
    
    print("💾 [MagicalLocationService] Cached location mapping: \(business.name) (\(business.businessType.displayName)) -> \(wifiFingerprint)")
  }
  
  private func updateCacheUsage(fingerprint: String) {
    if let index = cachedLocations.firstIndex(where: { $0.wifiFingerprint == fingerprint }) {
      let cached = cachedLocations[index]
      cachedLocations[index] = CachedLocation(
        wifiFingerprint: cached.wifiFingerprint,
        businessId: cached.businessId,
        businessName: cached.businessName,
        businessType: cached.businessType,
        confidence: cached.confidence,
        lastUsed: Date(),
        useCount: cached.useCount + 1
      )
      saveCachedLocations()
    }
  }
  
  // MARK: - Utility Methods
  func clearCache() {
    cachedLocations.removeAll()
    saveCachedLocations()
    print("🗑️ [MagicalLocationService] Location cache cleared")
  }
  
  func getCacheStats() -> (entries: Int, oldestEntry: Date?) {
    let oldest = cachedLocations.min(by: { $0.lastUsed < $1.lastUsed })?.lastUsed
    return (cachedLocations.count, oldest)
  }
  
  /// Force refresh of Google Places data (no caching)
  func refreshBusinesses() {
    print("🔄 [MagicalLocationService] Will refresh businesses on next location detection...")
    // Google Places API is always live, no caching needed
  }
  
  /// Get businesses near a location for debugging
  func getBusinessesNear(location: CLLocation) async -> [NearbyBusiness] {
    return await findAllNearbyBusinesses(location: location)
  }
  
  /// Test Google Places API connectivity
  func testGooglePlacesAPI() async -> Bool {
    // Test with a known location (Seattle downtown)
    let testLocation = CLLocation(latitude: 47.6062, longitude: -122.3321)
    let businesses = await findAllNearbyBusinesses(location: testLocation)
    return !businesses.isEmpty
  }
}

// MARK: - CLLocationManagerDelegate
extension MagicalLocationService: CLLocationManagerDelegate {
  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    Task { @MainActor in
      guard let location = locations.last else { return }
    
      currentLocation = location
      locationContinuation?.resume(returning: location)
      locationContinuation = nil
      
      // Stop location updates to save battery
      locationManager.stopUpdatingLocation()
    }
  }
  
  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      print("❌ [MagicalLocationService] Location error: \(error)")
      locationError = error.localizedDescription
      locationContinuation?.resume(returning: nil)
      locationContinuation = nil
    }
  }
  
  nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    Task { @MainActor in
      print("📍 [MagicalLocationService] Authorization status changed to: \(status.rawValue)")
      
      switch status {
      case .authorizedWhenInUse, .authorizedAlways:
        hasLocationPermission = true
        if let continuation = permissionContinuation {
          print("✅ [MagicalLocationService] Resuming continuation with TRUE")
          continuation.resume(returning: true)
          permissionContinuation = nil
        }
      case .denied, .restricted:
        hasLocationPermission = false
        if let continuation = permissionContinuation {
          print("❌ [MagicalLocationService] Resuming continuation with FALSE")
          continuation.resume(returning: false)
          permissionContinuation = nil
        }
      case .notDetermined:
        print("⏳ [MagicalLocationService] Status still not determined, waiting...")
        break // Wait for user decision
      @unknown default:
        hasLocationPermission = false
        if let continuation = permissionContinuation {
          print("⚠️ [MagicalLocationService] Unknown status, resuming continuation with FALSE")
          continuation.resume(returning: false)
          permissionContinuation = nil
        }
      }
    }
  }
}
