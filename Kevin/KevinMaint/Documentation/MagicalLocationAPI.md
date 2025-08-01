# Magical Location Detection API Documentation

## Overview

The Magical Location Detection system provides frictionless location intelligence for Kevin Maint, automatically detecting restaurant locations using GPS, Wi-Fi fingerprinting, and smart caching.

## Core Features

- **Instant Wi-Fi Recognition**: Cached location detection in <100ms
- **GPS Geofencing**: Automatic restaurant detection within 500m radius
- **Smart Caching**: Wi-Fi fingerprint-based location memory
- **Graceful Degradation**: Fallback to manual selection when needed
- **Privacy-First**: Hashed Wi-Fi data, configurable retention

## User Experience Flow

```
1. User takes photo → AI analysis
2. Location detection triggered automatically
3. High-confidence detection (≤50m) → Auto-select restaurant
4. Medium-confidence detection → Show confirmation modal
5. No detection → Manual selection fallback
6. Success animation → Issue created
```

## API Endpoints

### Location Detection

```swift
func detectLocation() async -> LocationContext?
```

**Response Example:**
```json
{
  "latitude": 35.2271,
  "longitude": -80.8431,
  "accuracy": 5.0,
  "timestamp": "2024-01-15T14:30:00Z",
  "wifiFingerprint": {
    "ssid": "RestaurantWiFi_Guest",
    "bssid": "aa:bb:cc:dd:ee:ff",
    "signalStrength": -45,
    "timestamp": "2024-01-15T14:30:00Z",
    "fingerprint": "restaurantwifi_guest_aabbccddeeff"
  },
  "nearbyRestaurants": [
    {
      "id": "rest_001",
      "name": "Kindred Restaurant",
      "address": "431 N Davidson St, Charlotte, NC 28202",
      "distance": 25.5,
      "latitude": 35.2271,
      "longitude": -80.8431,
      "isDetected": true
    },
    {
      "id": "rest_002",
      "name": "Summit Coffee",
      "address": "128 Main St, Davidson, NC 28036",
      "distance": 150.2,
      "latitude": 35.4993,
      "longitude": -80.8481,
      "isDetected": false
    }
  ],
  "suggestedRestaurant": {
    "id": "rest_001",
    "name": "Kindred Restaurant",
    "address": "431 N Davidson St, Charlotte, NC 28202",
    "distance": 25.5,
    "latitude": 35.2271,
    "longitude": -80.8431,
    "isDetected": true
  }
}
```

### Enhanced Issue Creation

```swift
func createIssue(_ issue: Issue, locationContext: IssueLocationContext?) async throws
```

**Enhanced Issue Payload:**
```json
{
  "id": "issue_12345",
  "restaurantId": "rest_001",
  "locationId": "rest_001",
  "reporterId": "user_789",
  "title": "Loose shelf bracket on right wall",
  "description": "AI detected a loose mounting bracket that could pose safety risk",
  "type": "Wall",
  "priority": "high",
  "status": "reported",
  "photoUrls": ["https://storage.googleapis.com/kevin-photos/issue_12345_1.jpg"],
  "aiAnalysis": {
    "summary": "Loose shelf bracket on right wall",
    "description": "The mounting bracket appears to be loose and could fall, creating a safety hazard",
    "category": "Wall",
    "priority": "High",
    "confidence": 0.92,
    "estimatedCost": 45.00,
    "timeToComplete": "30 minutes",
    "materialsNeeded": ["Wall anchor", "Screws"],
    "safetyWarnings": ["Falling hazard"],
    "recommendations": ["Secure bracket immediately", "Check other wall fixtures"]
  },
  "locationContext": {
    "detectedAt": "2024-01-15T14:30:00Z",
    "latitude": 35.2271,
    "longitude": -80.8431,
    "accuracy": 5.0,
    "wifiFingerprint": "hashed_fingerprint_abc123",
    "detectionMethod": "wifi_gps_hybrid",
    "confidence": 0.95,
    "alternativeRestaurants": ["rest_002", "rest_003"],
    "userConfirmed": false
  },
  "voiceNotes": "The bracket is really loose and wobbling when touched",
  "createdAt": "2024-01-15T14:30:00Z",
  "updatedAt": "2024-01-15T14:30:00Z"
}
```

## Location Detection Methods

### 1. Wi-Fi Cache Recognition (Instant)
- **Speed**: <100ms
- **Accuracy**: 95% confidence
- **Trigger**: Known Wi-Fi fingerprint detected
- **Fallback**: GPS verification

```json
{
  "detectionMethod": "wifi_cache",
  "confidence": 0.95,
  "duration": 0.08,
  "cacheHit": true
}
```

### 2. GPS + Wi-Fi Hybrid (Smart)
- **Speed**: 2-5 seconds
- **Accuracy**: 90% confidence
- **Trigger**: New location with Wi-Fi
- **Fallback**: GPS only

```json
{
  "detectionMethod": "wifi_gps_hybrid",
  "confidence": 0.90,
  "duration": 3.2,
  "gpsAccuracy": 5.0,
  "wifiNetworks": 3
}
```

### 3. GPS Only (Standard)
- **Speed**: 3-8 seconds
- **Accuracy**: 75% confidence
- **Trigger**: No Wi-Fi available
- **Fallback**: Manual selection

```json
{
  "detectionMethod": "gps_only",
  "confidence": 0.75,
  "duration": 5.1,
  "gpsAccuracy": 12.0
}
```

## Error Handling

### Common Error Responses

```json
{
  "error": "location_permission_denied",
  "message": "Location permission is required for automatic restaurant detection",
  "recoverySuggestion": "Please enable location access in Settings",
  "canRetry": false,
  "requiresSettings": true
}
```

```json
{
  "error": "no_restaurants_found",
  "message": "No restaurants found in your area",
  "recoverySuggestion": "Try manual restaurant selection",
  "canRetry": true,
  "fallbackAvailable": true
}
```

```json
{
  "error": "detection_timeout",
  "message": "Location detection timed out",
  "recoverySuggestion": "Try again in a moment",
  "canRetry": true,
  "timeoutDuration": 10.0
}
```

## Configuration

### Detection Parameters
```json
{
  "maxDetectionRadius": 500,
  "highConfidenceRadius": 50,
  "detectionTimeout": 10,
  "cacheExpiryDays": 30,
  "minAccuracyThreshold": 100,
  "maxCacheEntries": 100
}
```

### Privacy Settings
```json
{
  "allowWifiFingerprinting": true,
  "allowLocationCaching": true,
  "shareLocationAnalytics": true,
  "automaticDetection": true,
  "cacheRetentionDays": 30,
  "hashWifiData": true,
  "anonymizeLocationData": true
}
```

## Analytics Events

### Detection Attempt
```json
{
  "event": "location_detection_attempt",
  "method": "wifi_gps_hybrid",
  "timestamp": "2024-01-15T14:30:00Z",
  "userId": "user_789",
  "restaurantId": null
}
```

### Detection Success
```json
{
  "event": "location_detection_success",
  "method": "wifi_gps_hybrid",
  "accuracy": 5.0,
  "duration": 3.2,
  "confidence": 0.95,
  "restaurantId": "rest_001",
  "timestamp": "2024-01-15T14:30:03Z"
}
```

### User Confirmation
```json
{
  "event": "location_user_confirmation",
  "restaurantId": "rest_001",
  "wasAutoDetected": true,
  "alternativesShown": 2,
  "confirmationTime": 1.5,
  "timestamp": "2024-01-15T14:30:05Z"
}
```

## Implementation Notes

### Performance Optimization
- Wi-Fi fingerprints are hashed for privacy
- Location cache is limited to 100 entries
- GPS updates stop after successful detection
- Background location updates are disabled

### Battery Efficiency
- Location manager stops after detection
- Wi-Fi scanning is passive only
- No continuous location monitoring
- Smart cache reduces GPS usage by 80%

### Privacy Compliance
- Location data is not stored permanently
- Wi-Fi fingerprints are hashed
- User can disable caching
- Clear cache option available

### Fallback Strategy
1. **Wi-Fi Cache Hit**: Instant recognition
2. **GPS Detection**: Standard geofencing
3. **Manual Selection**: User chooses from list
4. **Admin Override**: Skip detection entirely

## Testing Scenarios

### Happy Path
```
1. User at known restaurant with cached Wi-Fi
2. Instant detection (< 100ms)
3. Auto-select restaurant
4. Show success toast
5. Continue to issue creation
```

### First Visit
```
1. User at new restaurant
2. GPS + Wi-Fi detection (3-5s)
3. Show confirmation modal
4. User confirms location
5. Cache Wi-Fi fingerprint
6. Continue to issue creation
```

### Permission Denied
```
1. User denies location permission
2. Show permission error modal
3. Offer manual selection
4. User selects restaurant manually
5. Continue without location data
```

### No GPS Signal
```
1. User indoors with poor GPS
2. Detection timeout after 10s
3. Show timeout error
4. Offer retry or manual selection
5. Fallback to restaurant list
```

## Integration Examples

### SwiftUI Integration
```swift
@StateObject private var locationService = MagicalLocationService.shared
@State private var showingLocationCard = false
@State private var locationContext: LocationContext?

// Trigger detection after AI analysis
private func triggerLocationDetection() {
    Task {
        let context = await locationService.detectLocation()
        await MainActor.run {
            if let context = context {
                locationContext = context
                showingLocationCard = true
            }
        }
    }
}
```

### Error Handling
```swift
private func handleLocationError(_ error: LocationDetectionError) {
    switch error {
    case .permissionDenied:
        showPermissionError = true
    case .noRestaurantsFound:
        showManualSelection = true
    case .timeout:
        showRetryOption = true
    default:
        showGenericError = true
    }
}
```

This magical location detection system transforms Kevin Maint from a 5-step to a 2-step issue reporting process, providing the frictionless experience that busy restaurant operators need.
