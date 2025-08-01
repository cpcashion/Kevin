import SwiftUI
import CoreLocation
import UIKit

// MARK: - Error Handling Components for Magical Location Detection

struct LocationErrorView: View {
  let error: LocationDetectionError
  let onRetry: () -> Void
  let onManualSelection: () -> Void
  let onDismiss: () -> Void
  
  @State private var isVisible = false
  
  var body: some View {
    ZStack {
      // Background overlay
      Color.black.opacity(0.4)
        .ignoresSafeArea()
        .onTapGesture { onDismiss() }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: isVisible)
      
      VStack {
        Spacer()
        
        // Error card
        VStack(spacing: 20) {
          errorIcon
          errorContent
          errorActions
        }
        .padding(24)
        .background(KMTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .offset(y: isVisible ? 0 : 300)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
      }
    }
    .onAppear {
      withAnimation {
        isVisible = true
      }
    }
  }
  
  private var errorIcon: some View {
    ZStack {
      Circle()
        .fill(KMTheme.danger.opacity(0.1))
        .frame(width: 60, height: 60)
      
      Image(systemName: errorIconName)
        .font(.title2)
        .foregroundColor(KMTheme.danger)
    }
  }
  
  private var errorIconName: String {
    switch error {
    case .permissionDenied:
      return "location.slash"
    case .locationUnavailable:
      return "location.slash.fill"
    case .noRestaurantsFound:
      return "building.2.crop.circle"
    case .wifiUnavailable:
      return "wifi.slash"
    case .networkError:
      return "network.slash"
    case .timeout:
      return "clock.badge.exclamationmark"
    case .cacheCorrupted:
      return "externaldrive.badge.exclamationmark"
    }
  }
  
  private var errorContent: some View {
    VStack(spacing: 12) {
      Text(errorTitle)
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
        .multilineTextAlignment(.center)
      
      Text(error.localizedDescription)
        .font(.subheadline)
        .foregroundColor(KMTheme.secondaryText)
        .multilineTextAlignment(.center)
      
      if let suggestion = error.recoverySuggestion {
        Text(suggestion)
          .font(.caption)
          .foregroundColor(KMTheme.tertiaryText)
          .multilineTextAlignment(.center)
          .padding(.top, 4)
      }
    }
  }
  
  private var errorTitle: String {
    switch error {
    case .permissionDenied:
      return "Location Permission Required"
    case .locationUnavailable:
      return "Location Unavailable"
    case .noRestaurantsFound:
      return "No Restaurants Found"
    case .wifiUnavailable:
      return "Wi-Fi Unavailable"
    case .networkError:
      return "Network Error"
    case .timeout:
      return "Detection Timed Out"
    case .cacheCorrupted:
      return "Cache Error"
    }
  }
  
  private var errorActions: some View {
    VStack(spacing: 12) {
      // Primary action
      Button(action: primaryAction) {
        HStack {
          Spacer()
          Text(primaryActionText)
            .font(.headline)
            .fontWeight(.semibold)
          Spacer()
        }
        .foregroundColor(.white)
        .padding(16)
        .background(KMTheme.accent)
        .cornerRadius(12)
      }
      
      // Secondary actions
      HStack(spacing: 12) {
        if showRetryButton {
          Button("Try Again") {
            onRetry()
          }
          .font(.subheadline)
          .foregroundColor(KMTheme.accent)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(KMTheme.accent.opacity(0.1))
          .cornerRadius(20)
        }
        
        Button("Select Manually") {
          onManualSelection()
        }
        .font(.subheadline)
        .foregroundColor(KMTheme.secondaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(KMTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(KMTheme.border, lineWidth: 1)
        )
      }
      
      // Dismiss button
      Button("Cancel") {
        onDismiss()
      }
      .font(.subheadline)
      .foregroundColor(KMTheme.tertiaryText)
    }
  }
  
  private var primaryActionText: String {
    switch error {
    case .permissionDenied:
      return "Open Settings"
    case .locationUnavailable, .timeout:
      return "Try Again"
    case .noRestaurantsFound:
      return "Select Manually"
    case .wifiUnavailable, .networkError:
      return "Continue Anyway"
    case .cacheCorrupted:
      return "Clear Cache"
    }
  }
  
  private var showRetryButton: Bool {
    switch error {
    case .permissionDenied, .noRestaurantsFound:
      return false
    default:
      return true
    }
  }
  
  private func primaryAction() {
    switch error {
    case .permissionDenied:
      openSettings()
    case .cacheCorrupted:
      clearCache()
    case .noRestaurantsFound:
      onManualSelection()
    default:
      onRetry()
    }
  }
  
  private func openSettings() {
    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(settingsUrl)
  }
  
  private func clearCache() {
    MagicalLocationService.shared.clearCache()
    onRetry()
  }
}

// MARK: - Network Error Handling
struct NetworkErrorHandler {
  static func handleLocationError(_ error: Error) -> LocationDetectionError {
    if let locationError = error as? LocationDetectionError {
      return locationError
    }
    
    // Map common errors to LocationDetectionError
    let nsError = error as NSError
    
    switch nsError.code {
    case 1: // kCLErrorLocationUnknown
      return .locationUnavailable
    case 0: // kCLErrorDenied
      return .permissionDenied
    case 15: // kCLErrorNetwork
      return .networkError
    case 10: // kCLErrorHeadingFailure
      return .locationUnavailable
    default:
      if nsError.domain.contains("NSURLError") {
        return .networkError
      }
      return .locationUnavailable
    }
  }
}

// MARK: - Retry Logic
class LocationRetryManager: ObservableObject {
  @Published var retryCount = 0
  @Published var isRetrying = false
  
  private let maxRetries = 3
  private let retryDelays: [TimeInterval] = [1.0, 2.0, 5.0] // Progressive delays
  
  func canRetry() -> Bool {
    return retryCount < maxRetries
  }
  
  func performRetry(operation: @escaping () async -> Void) async {
    guard canRetry() else { return }
    
    isRetrying = true
    retryCount += 1
    
    // Progressive delay
    let delay = retryDelays[min(retryCount - 1, retryDelays.count - 1)]
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    
    await operation()
    isRetrying = false
  }
  
  func reset() {
    retryCount = 0
    isRetrying = false
  }
}

// MARK: - Location Permission Helper
struct LocationPermissionHelper {
  static func checkPermissionStatus() -> LocationPermissionStatus {
    let status = CLLocationManager().authorizationStatus
    
    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      return .granted
    case .denied, .restricted:
      return .denied
    case .notDetermined:
      return .notDetermined
    @unknown default:
      return .unknown
    }
  }
  
  static func shouldShowPermissionRationale() -> Bool {
    // Check if user has previously denied permission
    let status = CLLocationManager().authorizationStatus
    return status == .denied
  }
}

enum LocationPermissionStatus {
  case granted, denied, notDetermined, unknown
  
  var canRequestPermission: Bool {
    return self == .notDetermined
  }
  
  var requiresSettings: Bool {
    return self == .denied
  }
}

// MARK: - Graceful Degradation
struct LocationFallbackManager {
  static func createManualSelectionContext(restaurants: [Restaurant]) -> LocationContext? {
    guard !restaurants.isEmpty else { return nil }
    
    // Create a fallback context with all restaurants as options
    let nearbyBusinesses = restaurants.map { restaurant in
      NearbyBusiness(
        id: restaurant.id,
        name: restaurant.name,
        address: restaurant.address,
        distance: 999999, // Unknown distance
        latitude: restaurant.latitude ?? 0,
        longitude: restaurant.longitude ?? 0,
        businessType: .restaurant, // All from Firebase are restaurants
        rating: restaurant.rating,
        priceLevel: restaurant.priceLevel,
        isOpen: nil, // Unknown
        photoReference: nil
      )
    }
    
    return LocationContext(
      latitude: 0,
      longitude: 0,
      accuracy: 0,
      timestamp: Date(),
      wifiFingerprint: nil,
      nearbyBusinesses: nearbyBusinesses,
      suggestedBusiness: nil
    )
  }
  
  static func createAdminOverrideContext(selectedRestaurant: Restaurant) -> LocationContext {
    let business = NearbyBusiness(
      id: selectedRestaurant.id,
      name: selectedRestaurant.name,
      address: selectedRestaurant.address,
      distance: 0,
      latitude: selectedRestaurant.latitude ?? 0,
      longitude: selectedRestaurant.longitude ?? 0,
      businessType: .restaurant, // All from Firebase are restaurants
      rating: selectedRestaurant.rating,
      priceLevel: selectedRestaurant.priceLevel,
      isOpen: nil, // Unknown
      photoReference: nil
    )
    
    return LocationContext(
      latitude: selectedRestaurant.latitude ?? 0,
      longitude: selectedRestaurant.longitude ?? 0,
      accuracy: 1.0, // Perfect accuracy for admin override
      timestamp: Date(),
      wifiFingerprint: nil,
      nearbyBusinesses: [business],
      suggestedBusiness: business
    )
  }
}

// MARK: - Analytics & Monitoring
struct LocationAnalyticsTracker {
  static func trackLocationDetectionAttempt(method: LocationDetectionMethod) {
    print("📊 [LocationAnalytics] Detection attempt: \(method.displayName)")
    // In production, send to analytics service
  }
  
  static func trackLocationDetectionSuccess(method: LocationDetectionMethod, accuracy: Double, duration: TimeInterval) {
    print("📊 [LocationAnalytics] Detection success: \(method.displayName), accuracy: \(accuracy)m, duration: \(duration)s")
    // In production, send to analytics service
  }
  
  static func trackLocationDetectionFailure(error: LocationDetectionError, method: LocationDetectionMethod?) {
    print("📊 [LocationAnalytics] Detection failure: \(error), method: \(method?.displayName ?? "unknown")")
    // In production, send to analytics service
  }
  
  static func trackUserLocationConfirmation(restaurantId: String, wasAutoDetected: Bool, alternativesShown: Int) {
    print("📊 [LocationAnalytics] User confirmation: \(restaurantId), auto: \(wasAutoDetected), alternatives: \(alternativesShown)")
    // In production, send to analytics service
  }
}

// MARK: - Preview
struct LocationErrorView_Previews: PreviewProvider {
  static var previews: some View {
    LocationErrorView(
      error: .permissionDenied,
      onRetry: { },
      onManualSelection: { },
      onDismiss: { }
    )
    .preferredColorScheme(.dark)
  }
}
