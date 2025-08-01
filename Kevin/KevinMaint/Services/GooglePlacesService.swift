import Foundation
import CoreLocation

// MARK: - Persistent Cache Models
struct CachedPlaceData: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String
    let cachedAt: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > 86400 // 24 hours
    }
}

class GooglePlacesPersistentCache {
    private static let cacheKey = "GooglePlacesCache"
    private static var memoryCache: [String: CachedPlaceData] = [:]
    
    static func get(placeId: String) -> CachedPlaceData? {
        // Check memory cache first
        if let cached = memoryCache[placeId], !cached.isExpired {
            return cached
        }
        
        // Check UserDefaults cache
        if let data = UserDefaults.standard.data(forKey: "\(cacheKey)_\(placeId)"),
           let cached = try? JSONDecoder().decode(CachedPlaceData.self, from: data),
           !cached.isExpired {
            memoryCache[placeId] = cached // Update memory cache
            return cached
        }
        
        return nil
    }
    
    static func set(placeId: String, data: CachedPlaceData) {
        // Update memory cache
        memoryCache[placeId] = data
        
        // Update persistent cache
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "\(cacheKey)_\(placeId)")
        }
    }
    
    static func preloadCommonPlaces() {
        // Pre-cache frequently accessed places in background
        let commonPlaceIds = [
            "ChIJW-CX62ETkFQRWANui6ltZno", // The Banana Stand
            "ChIJ17bj5_cTkFQRufkt2lLuh6k", // The Maple
            "ChIJOxWO3PcTkFQRYayAXrsAuEg"  // Snappy Dragon
        ]
        
        Task {
            for placeId in commonPlaceIds {
                if get(placeId: placeId) == nil {
                    do {
                        _ = try await GooglePlacesService.shared.fetchPlaceDetails(placeId: placeId)
                    } catch {
                        print("⚠️ [GooglePlacesPersistentCache] Failed to preload \(placeId): \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Google Places Models
struct GooglePlacesResponse: Codable {
    let results: [GooglePlace]
    let status: String
    let nextPageToken: String?
    
    enum CodingKeys: String, CodingKey {
        case results, status
        case nextPageToken = "next_page_token"
    }
}

struct GooglePlaceDetailsResponse: Codable {
    let result: GooglePlace
    let status: String
}

struct GooglePlace: Codable, Identifiable {
    let id = UUID()
    let placeId: String?
    let name: String
    let vicinity: String?
    let formattedAddress: String?
    let geometry: PlaceGeometry
    let types: [String]
    let businessStatus: String?
    let rating: Double?
    let userRatingsTotal: Int?
    let priceLevel: Int?
    let photos: [PlacePhoto]?
    let openingHours: PlaceOpeningHours?
    let formattedPhoneNumber: String?
    let internationalPhoneNumber: String?
    let website: String?
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name, vicinity, geometry, types, rating, website
        case formattedAddress = "formatted_address"
        case businessStatus = "business_status"
        case userRatingsTotal = "user_ratings_total"
        case priceLevel = "price_level"
        case photos
        case openingHours = "opening_hours"
        case formattedPhoneNumber = "formatted_phone_number"
        case internationalPhoneNumber = "international_phone_number"
    }
    
    // Convert to NearbyBusiness for UI
    func toNearbyBusiness(userLocation: CLLocation) -> NearbyBusiness {
        let businessLocation = CLLocation(
            latitude: geometry.location.lat,
            longitude: geometry.location.lng
        )
        let distance = userLocation.distance(from: businessLocation)
        
        return NearbyBusiness(
            id: placeId ?? "unknown_place_id",
            name: name,
            address: formattedAddress ?? vicinity,
            distance: distance,
            latitude: geometry.location.lat,
            longitude: geometry.location.lng,
            businessType: getBusinessType(),
            rating: rating,
            priceLevel: priceLevel,
            isOpen: openingHours?.openNow,
            photoReference: photos?.first?.photoReference
        )
    }
    
    private func getBusinessType() -> BusinessType {
        // Categorize based on Google Place types
        if types.contains("restaurant") || types.contains("food") || types.contains("meal_takeaway") {
            return .restaurant
        } else if types.contains("cafe") || types.contains("coffee_shop") {
            return .cafe
        } else if types.contains("bar") || types.contains("night_club") {
            return .bar
        } else if types.contains("gas_station") {
            return .gasStation
        } else if types.contains("grocery_or_supermarket") || types.contains("supermarket") {
            return .grocery
        } else if types.contains("pharmacy") {
            return .pharmacy
        } else if types.contains("hospital") || types.contains("doctor") {
            return .healthcare
        } else if types.contains("bank") || types.contains("atm") {
            return .financial
        } else if types.contains("lodging") {
            return .hotel
        } else if types.contains("shopping_mall") || types.contains("store") {
            return .retail
        } else if types.contains("gym") || types.contains("spa") {
            return .gym
        } else if types.contains("beauty_salon") || types.contains("hair_care") {
            return .salon
        } else if types.contains("dentist") || types.contains("physiotherapist") {
            return .clinic
        } else if types.contains("car_repair") || types.contains("car_wash") {
            return .automotive
        } else {
            return .other
        }
    }
}

struct PlaceGeometry: Codable {
    let location: PlaceLocation
}

struct PlaceLocation: Codable {
    let lat: Double
    let lng: Double
}

struct PlacePhoto: Codable {
    let photoReference: String
    let height: Int
    let width: Int
    
    enum CodingKeys: String, CodingKey {
        case photoReference = "photo_reference"
        case height, width
    }
}

struct PlaceOpeningHours: Codable {
    let openNow: Bool?
    
    enum CodingKeys: String, CodingKey {
        case openNow = "open_now"
    }
}

// MARK: - Business Models for UI
struct NearbyBusiness: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let address: String?
    let distance: Double // in meters
    let latitude: Double
    let longitude: Double
    let businessType: BusinessType
    let rating: Double?
    let priceLevel: Int?
    let isOpen: Bool?
    let photoReference: String?
    
    var distanceText: String {
        let distanceInFeet = distance * 3.28084 // Convert meters to feet
        
        if distance < 50 {
            return "You're here"
        } else if distanceInFeet < 1000 {
            return "\(Int(distanceInFeet)) ft away"
        } else {
            let miles = distanceInFeet / 5280
            return String(format: "%.1f mi away", miles)
        }
    }
    
    var typeIcon: String {
        return businessType.icon
    }
    
    var typeColor: String {
        return businessType.color
    }
}


// MARK: - Google Places Service
@MainActor
class GooglePlacesService: ObservableObject {
    static let shared = GooglePlacesService()
    
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiKey = APIKeys.googlePlacesAPIKey
    private let baseURL = "https://maps.googleapis.com/maps/api/place"
    private let session = URLSession.shared
    
    // MARK: - Find All Nearby Businesses
    func findAllNearbyBusinesses(
        location: CLLocation,
        radiusInMeters: Int = 1609 // 1 mile = 1609 meters
    ) async throws -> [NearbyBusiness] {
        
        print("🔍 [GooglePlacesService] Searching for ALL businesses within \(radiusInMeters)m of (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        // Get ALL business types in parallel for maximum coverage
        // This app serves ALL small businesses with physical locations
        
        // Food & Dining
        async let restaurants = searchByType(location: location, type: "restaurant", radius: radiusInMeters)
        async let food = searchByType(location: location, type: "food", radius: radiusInMeters)
        async let mealTakeaway = searchByType(location: location, type: "meal_takeaway", radius: radiusInMeters)
        async let mealDelivery = searchByType(location: location, type: "meal_delivery", radius: radiusInMeters)
        async let cafe = searchByType(location: location, type: "cafe", radius: radiusInMeters)
        async let bar = searchByType(location: location, type: "bar", radius: radiusInMeters)
        async let bakery = searchByType(location: location, type: "bakery", radius: radiusInMeters)
        
        // Retail & Shopping
        async let grocery = searchByType(location: location, type: "grocery_or_supermarket", radius: radiusInMeters)
        async let convenienceStore = searchByType(location: location, type: "convenience_store", radius: radiusInMeters)
        async let retail = searchByType(location: location, type: "shopping_mall", radius: radiusInMeters)
        async let clothingStore = searchByType(location: location, type: "clothing_store", radius: radiusInMeters)
        async let shoeStore = searchByType(location: location, type: "shoe_store", radius: radiusInMeters)
        async let jewelryStore = searchByType(location: location, type: "jewelry_store", radius: radiusInMeters)
        async let bookStore = searchByType(location: location, type: "book_store", radius: radiusInMeters)
        async let electronicsStore = searchByType(location: location, type: "electronics_store", radius: radiusInMeters)
        async let furnitureStore = searchByType(location: location, type: "furniture_store", radius: radiusInMeters)
        async let hardwareStores = searchByType(location: location, type: "hardware_store", radius: radiusInMeters)
        async let homeGoods = searchByType(location: location, type: "home_goods_store", radius: radiusInMeters)
        async let petStore = searchByType(location: location, type: "pet_store", radius: radiusInMeters)
        async let florist = searchByType(location: location, type: "florist", radius: radiusInMeters)
        async let liquorStore = searchByType(location: location, type: "liquor_store", radius: radiusInMeters)
        
        // Health & Beauty
        async let pharmacies = searchByType(location: location, type: "pharmacy", radius: radiusInMeters)
        async let healthcare = searchByType(location: location, type: "hospital", radius: radiusInMeters)
        async let dentist = searchByType(location: location, type: "dentist", radius: radiusInMeters)
        async let doctor = searchByType(location: location, type: "doctor", radius: radiusInMeters)
        async let hairCare = searchByType(location: location, type: "hair_care", radius: radiusInMeters)
        async let beautySalon = searchByType(location: location, type: "beauty_salon", radius: radiusInMeters)
        async let spa = searchByType(location: location, type: "spa", radius: radiusInMeters)
        
        // Services
        async let laundry = searchByType(location: location, type: "laundry", radius: radiusInMeters)
        async let carWash = searchByType(location: location, type: "car_wash", radius: radiusInMeters)
        async let automotive = searchByType(location: location, type: "car_repair", radius: radiusInMeters)
        async let carDealer = searchByType(location: location, type: "car_dealer", radius: radiusInMeters)
        async let gasStations = searchByType(location: location, type: "gas_station", radius: radiusInMeters)
        async let veterinaryCare = searchByType(location: location, type: "veterinary_care", radius: radiusInMeters)
        async let locksmith = searchByType(location: location, type: "locksmith", radius: radiusInMeters)
        async let plumber = searchByType(location: location, type: "plumber", radius: radiusInMeters)
        async let electrician = searchByType(location: location, type: "electrician", radius: radiusInMeters)
        async let roofingContractor = searchByType(location: location, type: "roofing_contractor", radius: radiusInMeters)
        
        // Fitness & Recreation
        async let fitness = searchByType(location: location, type: "gym", radius: radiusInMeters)
        async let bowlingAlley = searchByType(location: location, type: "bowling_alley", radius: radiusInMeters)
        async let movieTheater = searchByType(location: location, type: "movie_theater", radius: radiusInMeters)
        
        // Hospitality
        async let hotels = searchByType(location: location, type: "lodging", radius: radiusInMeters)
        
        // Financial
        async let banks = searchByType(location: location, type: "bank", radius: radiusInMeters)
        async let atm = searchByType(location: location, type: "atm", radius: radiusInMeters)
        
        // Professional Services
        async let realEstateAgency = searchByType(location: location, type: "real_estate_agency", radius: radiusInMeters)
        async let insuranceAgency = searchByType(location: location, type: "insurance_agency", radius: radiusInMeters)
        async let lawyer = searchByType(location: location, type: "lawyer", radius: radiusInMeters)
        async let accountant = searchByType(location: location, type: "accounting", radius: radiusInMeters)
        
        // General catch-all
        async let general = searchGeneral(location: location, radius: radiusInMeters)
        async let store = searchByType(location: location, type: "store", radius: radiusInMeters)
        
        do {
            let allResults = try await [
                // Food & Dining
                restaurants, food, mealTakeaway, mealDelivery, cafe, bar, bakery,
                // Retail & Shopping
                grocery, convenienceStore, retail, clothingStore, shoeStore, jewelryStore,
                bookStore, electronicsStore, furnitureStore, hardwareStores, homeGoods,
                petStore, florist, liquorStore,
                // Health & Beauty
                pharmacies, healthcare, dentist, doctor, hairCare, beautySalon, spa,
                // Services
                laundry, carWash, automotive, carDealer, gasStations, veterinaryCare,
                locksmith, plumber, electrician, roofingContractor,
                // Fitness & Recreation
                fitness, bowlingAlley, movieTheater,
                // Hospitality
                hotels,
                // Financial
                banks, atm,
                // Professional Services
                realEstateAgency, insuranceAgency, lawyer, accountant,
                // General
                general, store
            ].flatMap { $0 }
            
            // Remove duplicates based on place_id
            let uniqueBusinesses = removeDuplicates(allResults)
            
            // Sort by distance
            let sortedBusinesses = uniqueBusinesses.sorted { $0.distance < $1.distance }
            
            print("✅ [GooglePlacesService] Found \(sortedBusinesses.count) unique businesses")
            
            // Log the closest 5 businesses for debugging
            print("🔍 [GooglePlacesService] Closest 5 businesses:")
            for (index, business) in sortedBusinesses.prefix(5).enumerated() {
                print("   \(index + 1). \(business.name) (\(business.businessType.displayName)) - \(String(format: "%.0f", business.distance))m")
            }
            
            print("📊 [GooglePlacesService] Business breakdown:")
            
            // Print breakdown by type
            let breakdown = Dictionary(grouping: sortedBusinesses, by: { $0.businessType })
            for (type, businesses) in breakdown.sorted(by: { $0.value.count > $1.value.count }) {
                print("   \(type.icon) \(type.displayName): \(businesses.count)")
            }
            
            return sortedBusinesses
            
        } catch {
            let errorMessage = "Failed to search nearby businesses: \(error.localizedDescription)"
            print("❌ [GooglePlacesService] \(errorMessage)")
            self.error = errorMessage
            throw error
        }
    }
    
    // MARK: - Search by Specific Type
    private func searchByType(
        location: CLLocation,
        type: String,
        radius: Int
    ) async throws -> [NearbyBusiness] {
        
        let urlString = "\(baseURL)/nearbysearch/json?" +
            "location=\(location.coordinate.latitude),\(location.coordinate.longitude)" +
            "&radius=\(radius)" +
            "&type=\(type)" +
            "&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
        
        guard placesResponse.status == "OK" || placesResponse.status == "ZERO_RESULTS" else {
            throw NSError(domain: "GooglePlacesError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Google Places API error: \(placesResponse.status)"
            ])
        }
        
        let businesses = placesResponse.results.map { $0.toNearbyBusiness(userLocation: location) }
        print("🔍 [GooglePlacesService] Found \(businesses.count) \(type) businesses")
        
        return businesses
    }
    
    // MARK: - General Search
    private func searchGeneral(
        location: CLLocation,
        radius: Int
    ) async throws -> [NearbyBusiness] {
        
        let urlString = "\(baseURL)/nearbysearch/json?" +
            "location=\(location.coordinate.latitude),\(location.coordinate.longitude)" +
            "&radius=\(radius)" +
            "&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
        
        guard placesResponse.status == "OK" || placesResponse.status == "ZERO_RESULTS" else {
            throw NSError(domain: "GooglePlacesError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Google Places API error: \(placesResponse.status)"
            ])
        }
        
        let businesses = placesResponse.results.map { $0.toNearbyBusiness(userLocation: location) }
        print("🔍 [GooglePlacesService] Found \(businesses.count) general businesses")
        
        return businesses
    }
    
    // MARK: - Nationwide Text Search (No Radius Restriction)
    func searchBusinessesNationwide(query: String, userLocation: CLLocation?) async throws -> [NearbyBusiness] {
        guard !query.isEmpty else {
            return []
        }
        
        // Use text search without radius restriction for nationwide search
        var urlString = "\(baseURL)/textsearch/json?" +
            "query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)" +
            "&key=\(apiKey)"
        
        // If user location is available, use it for distance calculation and sorting
        // but don't restrict results by radius
        if let location = userLocation {
            urlString += "&location=\(location.coordinate.latitude),\(location.coordinate.longitude)"
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
        
        guard placesResponse.status == "OK" || placesResponse.status == "ZERO_RESULTS" else {
            throw NSError(domain: "GooglePlacesError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Google Places API error: \(placesResponse.status)"
            ])
        }
        
        let businesses = placesResponse.results.map { $0.toNearbyBusiness(userLocation: userLocation ?? CLLocation(latitude: 0, longitude: 0)) }
        print("🌎 [GooglePlacesService] Nationwide search for '\(query)': Found \(businesses.count) businesses")
        
        return businesses
    }
    
    // MARK: - Text Search (With Radius)
    private func searchByText(
        location: CLLocation,
        query: String,
        radius: Int
    ) async throws -> [NearbyBusiness] {
        
        let urlString = "\(baseURL)/textsearch/json?" +
            "query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)" +
            "&location=\(location.coordinate.latitude),\(location.coordinate.longitude)" +
            "&radius=\(radius)" +
            "&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
        
        guard placesResponse.status == "OK" || placesResponse.status == "ZERO_RESULTS" else {
            throw NSError(domain: "GooglePlacesError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Google Places API error: \(placesResponse.status)"
            ])
        }
        
        let businesses = placesResponse.results.map { $0.toNearbyBusiness(userLocation: location) }
        print("🔍 [GooglePlacesService] Found \(businesses.count) businesses from text search: \(query)")
        
        return businesses
    }
    
    // MARK: - Remove Duplicates
    private func removeDuplicates(_ businesses: [NearbyBusiness]) -> [NearbyBusiness] {
        var seen = Set<String>()
        return businesses.filter { business in
            if seen.contains(business.id) {
                return false
            } else {
                seen.insert(business.id)
                return true
            }
        }
    }
    
    // MARK: - Get Place Details
    func getPlaceDetails(placeId: String) async throws -> GooglePlace {
        let urlString = "\(baseURL)/details/json?" +
            "place_id=\(placeId)" +
            "&fields=place_id,name,vicinity,formatted_address,geometry,types,business_status,rating,user_ratings_total,price_level,photos,opening_hours,formatted_phone_number,international_phone_number,website" +
            "&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let detailsResponse = try JSONDecoder().decode(GooglePlaceDetailsResponse.self, from: data)
        
        guard detailsResponse.status == "OK" else {
            throw NSError(domain: "GooglePlacesError", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Google Places API error: \(detailsResponse.status)"
            ])
        }
        
        return detailsResponse.result
    }
    
    // MARK: - Get Photo URL
    func getPhotoURL(photoReference: String, maxWidth: Int = 400) -> String? {
        guard !photoReference.isEmpty else { return nil }
        
        return "\(baseURL)/photo?" +
            "maxwidth=\(maxWidth)" +
            "&photo_reference=\(photoReference)" +
            "&key=\(apiKey)"
    }
    
    // MARK: - Place Details (Cached)
    func fetchPlaceDetails(placeId: String) async throws -> GooglePlace {
        // Check cache first - INSTANT RESPONSE if cached
        if let cached = GooglePlacesPersistentCache.get(placeId: placeId) {
            print("⚡ [GooglePlacesService] Using cached data for: \(cached.name)")
            return GooglePlace(
                placeId: placeId,
                name: cached.name,
                vicinity: nil,
                formattedAddress: cached.address,
                geometry: PlaceGeometry(
                    location: PlaceLocation(
                        lat: cached.latitude,
                        lng: cached.longitude
                    )
                ),
                types: [],
                businessStatus: nil,
                rating: nil,
                userRatingsTotal: nil,
                priceLevel: nil,
                photos: nil,
                openingHours: nil,
                formattedPhoneNumber: nil,
                internationalPhoneNumber: nil,
                website: nil
            )
        }
        
        print("🔍 [GooglePlacesService] Fetching place details for: \(placeId)")
        
        let urlString = "\(baseURL)/details/json?" +
            "place_id=\(placeId)" +
            "&fields=name,formatted_address,geometry,types,business_status,rating,user_ratings_total" +
            "&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GooglePlacesService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid URL for place details"
            ])
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GooglePlacesService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response"
            ])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "GooglePlacesService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"
            ])
        }
        
        let placeDetailsResponse = try JSONDecoder().decode(GooglePlaceDetailsResponse.self, from: data)
        
        guard placeDetailsResponse.status == "OK" else {
            throw NSError(domain: "GooglePlacesService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Google Places API error: \(placeDetailsResponse.status)"
            ])
        }
        
        let place = placeDetailsResponse.result
        
        // Cache the result for instant future access
        let cacheData = CachedPlaceData(
            name: place.name,
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng,
            address: place.formattedAddress ?? "",
            cachedAt: Date()
        )
        GooglePlacesPersistentCache.set(placeId: placeId, data: cacheData)
        
        print("✅ [GooglePlacesService] Successfully fetched place details: \(place.name)")
        return place
    }
    
    // MARK: - Batch Place Details (Super Fast)
    func fetchMultiplePlaceDetails(placeIds: [String]) async -> [String: GooglePlace] {
        var results: [String: GooglePlace] = [:]
        
        // Get all cached results instantly
        let cachedResults = placeIds.compactMap { placeId -> (String, GooglePlace)? in
            guard let cached = GooglePlacesPersistentCache.get(placeId: placeId) else { return nil }
            let place = GooglePlace(
                placeId: placeId,
                name: cached.name,
                vicinity: nil,
                formattedAddress: cached.address,
                geometry: PlaceGeometry(
                    location: PlaceLocation(
                        lat: cached.latitude,
                        lng: cached.longitude
                    )
                ),
                types: [],
                businessStatus: nil,
                rating: nil,
                userRatingsTotal: nil,
                priceLevel: nil,
                photos: nil,
                openingHours: nil,
                formattedPhoneNumber: nil,
                internationalPhoneNumber: nil,
                website: nil
            )
            return (placeId, place)
        }
        
        for (placeId, place) in cachedResults {
            results[placeId] = place
        }
        
        // Only fetch uncached places
        let uncachedPlaceIds = placeIds.filter { !results.keys.contains($0) }
        
        if !uncachedPlaceIds.isEmpty {
            print("🔍 [GooglePlacesService] Fetching \(uncachedPlaceIds.count) uncached places in parallel")
            
            // Fetch uncached places in parallel
            await withTaskGroup(of: (String, GooglePlace?).self) { group in
                for placeId in uncachedPlaceIds {
                    group.addTask {
                        do {
                            let place = try await self.fetchPlaceDetails(placeId: placeId)
                            return (placeId, place)
                        } catch {
                            print("❌ [GooglePlacesService] Failed to fetch \(placeId): \(error)")
                            return (placeId, nil)
                        }
                    }
                }
                
                for await (placeId, place) in group {
                    if let place = place {
                        results[placeId] = place
                    }
                }
            }
        }
        
        print("⚡ [GooglePlacesService] Batch fetch complete: \(results.count)/\(placeIds.count) places")
        return results
    }
}
