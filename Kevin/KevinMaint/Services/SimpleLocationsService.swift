import Foundation
import Combine

// MARK: - Simplified Locations Service
// Replaces complex LocationsView logic with clean, reliable data management

@MainActor
class SimpleLocationsService: ObservableObject {
    @Published var locations: [SimpleLocation] = []
    @Published var locationStats: [String: LocationStats] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Store all issues for location detail access
    private var allIssues: [Issue] = []
    
    private let firebaseClient: FirebaseClient
    private var cancellables = Set<AnyCancellable>()
    private var loadingTask: Task<Void, Never>?
    private weak var appState: AppState?
    
    init(firebaseClient: FirebaseClient = FirebaseClient.shared, appState: AppState? = nil) {
        self.firebaseClient = firebaseClient
        self.appState = appState
        print("🏗️ [SimpleLocationsService] New instance created")
    }
    
    // MARK: - Public Methods
    
    func setAppState(_ appState: AppState) {
        // Only clear cache if the user context actually changed
        let shouldClearCache = self.appState?.currentAppUser?.id != appState.currentAppUser?.id
        
        self.appState = appState
        
        if shouldClearCache {
            print("🧹 [SimpleLocationsService] User context changed, clearing cached data")
            clearCache()
        }
    }
    
    func clearCache() {
        print("🧹 [SimpleLocationsService] Clearing cached data")
        locations = []
        locationStats = [String: LocationStats]()
        googlePlacesCache = [:]
    }
    func forceRefresh() {
        print("🔄 [SimpleLocationsService] Force refresh requested - clearing cache and reloading")
        locations = []
        locationStats = [String: LocationStats]()
        
        // Trigger immediate reload
        Task {
            await loadLocations()
        }
    }
    
    func clearHardcodedDataCache() {
        print("🧹 [SimpleLocationsService] Clearing all cached data to remove hardcoded coordinates")
        googlePlacesCache.removeAll()
        locations.removeAll()
        locationStats = [String: LocationStats]()
    }
    
    // MARK: - User Context Filtering
    
    private func getUserFilters() -> (businessId: String?, reporterId: String?) {
        guard let state = appState else { 
            print("⚠️ [SimpleLocationsService] No AppState - returning empty filter")
            return (nil, "NO_USER") // Return impossible reporter ID to show nothing
        }
        
        guard let currentUser = state.currentAppUser else {
            print("⚠️ [SimpleLocationsService] No authenticated user - returning empty filter")
            return (nil, "NO_USER") // Return impossible reporter ID to show nothing
        }
        
        print("🔍 [SimpleLocationsService] User role: \(currentUser.role)")
        print("🔍 [SimpleLocationsService] User ID: \(currentUser.id)")
        
        // Admin users see all locations (no filter)
        if currentUser.role == .admin {
            print("🔑 [SimpleLocationsService] Admin user - showing all locations")
            return (nil, nil)
        }
        
        // CRITICAL FIX: Always filter by reporter ID for non-admin users
        // This works with both restaurant ownership AND location detection systems
        print("👤 [SimpleLocationsService] Filtering by reporter: \(currentUser.id)")
        if let businessId = state.currentRestaurant?.id {
            print("🏢 [SimpleLocationsService] User has restaurant: \(businessId) (informational only)")
        }
        return (nil, currentUser.id)
    }
    
    // MARK: - Google Places API Integration
    
    private func fetchBusinessNameFromGooglePlaces(placeId: String) async -> String? {
        print("🔍 [SimpleLocationsService] Fetching business name from Google Places API for: \(placeId)")
        
        do {
            // Use the existing GooglePlacesService to fetch place details
            let placeDetails = try await GooglePlacesService.shared.fetchPlaceDetails(placeId: placeId)
            
            let businessName = placeDetails.name
            let coordinates = (placeDetails.geometry.location.lat, placeDetails.geometry.location.lng)
            let address = placeDetails.formattedAddress ?? placeDetails.vicinity ?? "Address not available"
            
            print("✅ [SimpleLocationsService] Fetched from Google Places API:")
            print("   - Name: \(businessName)")
            print("   - Coordinates: (\(coordinates.0), \(coordinates.1))")
            print("   - Address: \(address)")
            
            // Cache this information for future use by storing it in a temporary cache
            cacheGooglePlaceDetails(placeId: placeId, name: businessName, coordinates: coordinates, address: address)
            
            return businessName
        } catch {
            print("❌ [SimpleLocationsService] Failed to fetch place details for \(placeId): \(error)")
            return nil
        }
    }
    
    // Temporary cache for Google Places data within this session
    private var googlePlacesCache: [String: (name: String, coordinates: (lat: Double, lng: Double), address: String)] = [:]
    
    private func cacheGooglePlaceDetails(placeId: String, name: String, coordinates: (lat: Double, lng: Double), address: String) {
        googlePlacesCache[placeId] = (name: name, coordinates: coordinates, address: address)
        print("💾 [SimpleLocationsService] Cached Google Places data for: \(name)")
    }
    
    private func getCachedGooglePlaceDetails(placeId: String) -> (name: String, coordinates: (lat: Double, lng: Double), address: String)? {
        return googlePlacesCache[placeId]
    }
    
    // Convert MaintenanceRequest to Issue for compatibility
    private func convertToIssue(_ request: MaintenanceRequest) -> Issue {
        return Issue(
            id: request.id,
            restaurantId: request.businessId,
            locationId: request.locationId ?? "",
            reporterId: request.reporterId,
            title: request.title,
            description: request.description,
            type: request.category.displayName,
            priority: IssuePriority(rawValue: request.priority.rawValue) ?? .medium,
            status: IssueStatus(rawValue: request.status.rawValue) ?? .reported,
            photoUrls: request.photoUrls,
            aiAnalysis: request.aiAnalysis,
            voiceNotes: nil, // MaintenanceRequest doesn't have voiceNotes
            createdAt: request.createdAt,
            updatedAt: request.updatedAt
        )
    }
    
    func loadLocations() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🚨 [SimpleLocationsService] loadLocations() called")
        LaunchTimeProfiler.shared.checkpoint("SimpleLocationsService.loadLocations() started")
        
        // If already loading, wait for the existing task instead of starting a new one
        if isLoading {
            print("🔄 [SimpleLocationsService] Already loading, waiting for existing task - waited \(CFAbsoluteTimeGetCurrent() - startTime)s")
            await loadingTask?.value
            return
        }
        
        // Cancel any existing loading task only if we're not currently loading
        loadingTask?.cancel()
        
        // Check if we already have data and it's recent
        // But always reload if user context has changed
        if !locations.isEmpty {
            let (currentBusinessFilter, currentReporterFilter) = getUserFilters()
            // For now, always reload to ensure proper filtering
            // TODO: Add smarter caching that considers user context
            print("🔄 [SimpleLocationsService] Have \(locations.count) locations but reloading for user context - took \(CFAbsoluteTimeGetCurrent() - startTime)s")
        }
        
        loadingTask = Task {
            await performLoadLocations()
        }
        
        await loadingTask?.value
        print("⏱️ [SimpleLocationsService] Total loadLocations() time: \(CFAbsoluteTimeGetCurrent() - startTime)s")
        LaunchTimeProfiler.shared.checkpoint("SimpleLocationsService.loadLocations() completed")
    }
    
    private func performLoadLocations() async {
        let performStartTime = CFAbsoluteTimeGetCurrent()
        print("🔧 [SimpleLocationsService] performLoadLocations() started at \(performStartTime)")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        print("🏢 [SimpleLocationsService] Loading simplified locations...")
        
        do {
            // Load issues with proper filtering based on user role using V2 system
            let issuesStartTime = CFAbsoluteTimeGetCurrent()
            let (businessFilter, reporterFilter) = getUserFilters()
            
            // TESTING MODE: Only show issues created after Oct 28, 2025 at 6:00 PM
            let testingCutoffDate = Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 29, hour: 1, minute: 0))!
            print("🧪 [TESTING MODE] Filtering locations from issues created after \(testingCutoffDate)")
            
            let allRequests = try await MaintenanceServiceV2.shared.listRequests(
                businessId: businessFilter,
                reporterId: reporterFilter,
                createdAfter: testingCutoffDate
            )
            let issuesEndTime = CFAbsoluteTimeGetCurrent()
            print("🔍 [SimpleLocationsService] Loaded \(allRequests.count) requests in \(issuesEndTime - issuesStartTime)s")
            if let businessId = businessFilter {
                print("🏢 [SimpleLocationsService] Filtered by business: \(businessId)")
            } else if let reporterId = reporterFilter {
                print("👤 [SimpleLocationsService] Filtered by reporter: \(reporterId)")
            } else {
                print("🌍 [SimpleLocationsService] No filter (admin mode)")
            }
            
            // Convert MaintenanceRequests to Issues for compatibility
            let allIssues = allRequests.map { convertToIssue($0) }
            
            // Extract unique locations from real issues
            let extractStartTime = CFAbsoluteTimeGetCurrent()
            let extractedLocations = await extractLocationsFromIssues(allIssues)
            let extractEndTime = CFAbsoluteTimeGetCurrent()
            print("🏗️ [SimpleLocationsService] Extracted \(extractedLocations.count) locations in \(extractEndTime - extractStartTime)s")
            
            // Sort locations alphabetically
            let sortStartTime = CFAbsoluteTimeGetCurrent()
            let sortedLocations = extractedLocations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let sortEndTime = CFAbsoluteTimeGetCurrent()
            print("📊 [SimpleLocationsService] Sorted locations in \(sortEndTime - sortStartTime)s")
            
            // Load stats for each location using the SAME issues data (no additional Firebase call)
            let statsStartTime = CFAbsoluteTimeGetCurrent()
            let calculatedStats = await loadLocationStatsAndReturn(for: sortedLocations, using: allIssues)
            let statsEndTime = CFAbsoluteTimeGetCurrent()
            print("📈 [SimpleLocationsService] Calculated stats in \(statsEndTime - statsStartTime)s")
            
            // Update UI on main thread
            await MainActor.run {
                self.locations = sortedLocations
                self.locationStats = calculatedStats
                self.allIssues = allIssues // Store for location detail access
                print("🔄 [SimpleLocationsService] Updated UI with \(sortedLocations.count) locations")
            }
            
            let totalTime = CFAbsoluteTimeGetCurrent() - performStartTime
            print("✅ [SimpleLocationsService] Loaded \(locations.count) locations successfully in \(totalTime)s")
            
        } catch {
            print("❌ [SimpleLocationsService] Error loading issues: \(error)")
            // Fallback to empty locations on main thread
            await MainActor.run {
                self.locations = []
                self.errorMessage = "Failed to load locations: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
        loadingTask = nil
        
        let totalPerformTime = CFAbsoluteTimeGetCurrent() - performStartTime
        print("🏁 [SimpleLocationsService] performLoadLocations() completed in \(totalPerformTime)s")
    }
    
    func findLocation(by id: String) -> SimpleLocation? {
        return locations.first { $0.id == id }
    }
    
    func findLocationByName(_ name: String) -> SimpleLocation? {
        // Only search in real locations loaded from Firebase, not hardcoded data
        return locations.first { $0.name.lowercased() == name.lowercased() }
    }
    
    func getLocationStats(for locationId: String) -> LocationStats? {
        return locationStats[locationId]
    }
    
    // Get all issues for a specific location
    func getIssuesForLocation(_ location: SimpleLocation) -> [Issue] {
        return findIssuesForLocation(location, in: allIssues)
    }
    
    func locationsNear(latitude: Double, longitude: Double, radiusKm: Double = 50.0) -> [SimpleLocation] {
        // Only search in real locations loaded from Firebase, not hardcoded data
        return locations.filter { location in
            guard let lat = location.latitude, let lng = location.longitude else { return false }
            let distance = calculateDistance(lat1: latitude, lng1: longitude, lat2: lat, lng2: lng)
            return distance <= radiusKm
        }
    }
    
    private func calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let earthRadius = 6371.0 // Earth's radius in kilometers
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLng = (lng2 - lng1) * .pi / 180.0
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) * sin(dLng/2) * sin(dLng/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return earthRadius * c
    }
    
    // MARK: - Private Methods
    
    private func isUUID(_ string: String) -> Bool {
        // Check if string matches UUID pattern (8-4-4-4-12 characters)
        let uuidPattern = "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"
        let regex = try? NSRegularExpression(pattern: uuidPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: string.count)
        return regex?.firstMatch(in: string, options: [], range: range) != nil
    }
    
    private func resolveRestaurantName(for restaurantId: String) async -> String? {
        do {
            // Try to fetch restaurant from Firebase
            let restaurant = try await firebaseClient.fetchRestaurant(id: restaurantId)
            return restaurant?.name
        } catch {
            print("⚠️ [SimpleLocationsService] Could not resolve restaurant name for ID: \(restaurantId)")
            return nil
        }
    }
    
    private func extractLocationsFromIssues(_ issues: [Issue]) async -> [SimpleLocation] {
        let extractStartTime = CFAbsoluteTimeGetCurrent()
        print("🔍 [SimpleLocationsService] Extracting unique locations from \(issues.count) issues...")
        
        // STEP 1: Collect all unique place IDs for batch processing
        let batchStartTime = CFAbsoluteTimeGetCurrent()
        
        var allPlaceIds: Set<String> = []
        var allUuidIds: Set<String> = []
        var uniqueLocationIds: Set<String> = []
        
        for issue in issues {
            if !issue.restaurantId.isEmpty {
                if issue.restaurantId.starts(with: "ChIJ") {
                    allPlaceIds.insert(issue.restaurantId)
                } else if isUUID(issue.restaurantId) {
                    allUuidIds.insert(issue.restaurantId)
                }
                uniqueLocationIds.insert(issue.restaurantId)
            }
            if !issue.locationId.isEmpty && issue.locationId != issue.restaurantId {
                if issue.locationId.starts(with: "ChIJ") {
                    allPlaceIds.insert(issue.locationId)
                }
                uniqueLocationIds.insert(issue.locationId)
            }
        }
        
        print("🚀 [SimpleLocationsService] Found \(allPlaceIds.count) Google Place IDs, \(allUuidIds.count) UUID IDs")
        
        // STEP 2: Batch fetch ALL Google Places data in parallel (SUPER FAST)
        let placesLookup = await GooglePlacesService.shared.fetchMultiplePlaceDetails(placeIds: Array(allPlaceIds))
        
        // STEP 3: Batch fetch all restaurant data
        var restaurantLookup: [String: String] = [:]
        if !allUuidIds.isEmpty {
            do {
                let restaurants = try await firebaseClient.fetchRestaurants(ids: Array(allUuidIds))
                for restaurant in restaurants {
                    restaurantLookup[restaurant.id] = restaurant.name
                }
                print("✅ [SimpleLocationsService] Batch loaded \(restaurants.count) restaurants")
            } catch {
                print("⚠️ [SimpleLocationsService] Failed to batch load restaurants: \(error)")
            }
        }
        
        let batchTime = CFAbsoluteTimeGetCurrent() - batchStartTime
        print("⚡ [SimpleLocationsService] Batch processing completed in \(batchTime)s")
        
        // STEP 4: Process all issues with instant lookups (NO API CALLS)
        var uniqueLocations: [String: SimpleLocation] = [:]
        var processedNames: Set<String> = []
        
        for issue in issues {
            var locationName: String?
            var locationId: String?
            var coordinates: (lat: Double, lng: Double)?
            var address: String = ""
            var businessType: BusinessType = .other
            
            // Strategy 1: Extract from restaurantId with instant lookup
            if !issue.restaurantId.isEmpty {
                if issue.restaurantId.starts(with: "ChIJ") {
                    // Google Place ID - instant lookup from batch
                    if let place = placesLookup[issue.restaurantId] {
                        locationName = place.name
                        coordinates = (place.geometry.location.lat, place.geometry.location.lng)
                        address = place.formattedAddress ?? ""
                        businessType = BusinessType.fromGooglePlaceTypes(place.types)
                    }
                    locationId = issue.restaurantId
                } else if isUUID(issue.restaurantId) {
                    // UUID restaurant ID - instant lookup from batch
                    locationName = restaurantLookup[issue.restaurantId]
                    locationId = issue.restaurantId
                } else {
                    // Direct business name
                    locationName = issue.restaurantId
                    locationId = issue.restaurantId
                }
            }
            
            // Strategy 2: Extract from locationId if restaurantId failed
            if locationName == nil && !issue.locationId.isEmpty {
                if issue.locationId.starts(with: "ChIJ") {
                    if let place = placesLookup[issue.locationId] {
                        locationName = place.name
                        coordinates = (place.geometry.location.lat, place.geometry.location.lng)
                        address = place.formattedAddress ?? ""
                        businessType = BusinessType.fromGooglePlaceTypes(place.types)
                    }
                    locationId = issue.locationId
                } else {
                    locationName = issue.locationId
                    locationId = issue.locationId
                }
            }
            
            // Strategy 3: Fallback for legacy issues
            if locationName == nil {
                locationName = "Legacy Location"
                locationId = "legacy_location"
            }
            
            guard let finalLocationName = locationName,
                  let finalLocationId = locationId,
                  !processedNames.contains(finalLocationName) else {
                continue
            }
            
            processedNames.insert(finalLocationName)
            
            // Use fallback coordinates if not from Google Places
            if coordinates == nil {
                coordinates = getCoordinatesForBusiness(finalLocationName)
                address = generateAddressForBusiness(finalLocationName)
            }
            
            // Use Google Places business type if available, otherwise fallback to name-based detection
            if businessType == .other {
                businessType = determineBusinessType(finalLocationName)
            }
            
            let location = SimpleLocation(
                id: finalLocationId,
                name: finalLocationName,
                address: address,
                latitude: coordinates?.lat, // Use real coordinates only
                longitude: coordinates?.lng, // Use real coordinates only
                businessType: businessType,
                phone: nil,
                email: nil
            )
            
            uniqueLocations[finalLocationName] = location
        }
        
        let extractedLocations = Array(uniqueLocations.values)
        let totalExtractTime = CFAbsoluteTimeGetCurrent() - extractStartTime
        print("✅ [SimpleLocationsService] Extracted \(extractedLocations.count) unique locations in \(totalExtractTime)s")
        
        // Log all extracted business names for debugging
        let businessNamesList = extractedLocations.map { $0.name }.sorted()
        print("🏪 [SimpleLocationsService] Businesses found: \(businessNamesList.joined(separator: ", "))")
        
        return extractedLocations
    }
    
    private func extractBusinessNameFromLocationId(_ locationId: String) async -> String? {
        // Handle various locationId formats
        if locationId.starts(with: "ChIJ") {
            // Google Place ID - fetch real name from Google Places API
            return await fetchBusinessNameFromGooglePlaces(placeId: locationId)
        } else if locationId.contains("_") {
            // Format like "business_name_address"
            let components = locationId.components(separatedBy: "_")
            for component in components {
                if component.count > 3 && component.rangeOfCharacter(from: .letters) != nil {
                    return component.replacingOccurrences(of: "_", with: " ").capitalized
                }
            }
        } else if !locationId.isEmpty {
            // Direct business name
            return locationId.replacingOccurrences(of: "_", with: " ").capitalized
        }
        
        return nil
    }
    
    private func getCoordinatesForBusiness(_ businessName: String) -> (lat: Double, lng: Double)? {
        // First check Google Places cache for dynamically fetched coordinates
        for (_, cachedData) in googlePlacesCache {
            if cachedData.name.lowercased() == businessName.lowercased() {
                print("📍 [SimpleLocationsService] Using cached Google Places coordinates for: \(businessName)")
                return cachedData.coordinates
            }
        }
        
        // No hardcoded coordinates from MasterLocationData - only use real Google Places API data
        
        // No hardcoded coordinates - only use real Google Places API data
        
        return nil
    }
    
    private func generateAddressForBusiness(_ businessName: String) -> String {
        // First check Google Places cache for dynamically fetched address (case-insensitive)
        for (placeId, cachedData) in googlePlacesCache {
            if cachedData.name.lowercased() == businessName.lowercased() {
                print("📍 [SimpleLocationsService] Using cached Google Places address for: \(businessName)")
                return cachedData.address
            }
        }
        
        // No hardcoded mappings - will fetch from Google Places API if needed
        
        // No hardcoded addresses from MasterLocationData - only use real Google Places API data
        
        // If no address found, return empty string - address will be fetched from Google Places API
        print("⚠️ [SimpleLocationsService] No cached address for: \(businessName), will be fetched from Google Places API")
        return ""
    }
    
    private func determineBusinessType(_ businessName: String) -> BusinessType {
        let name = businessName.lowercased()
        print("🏢 [BusinessType] Classifying: '\(businessName)' (lowercase: '\(name)')")
        
        // Financial
        if name.contains("bank") || name.contains("citi") || name.contains("wells fargo") || name.contains("chase") || name.contains("atm") {
            print("🏢 [BusinessType] → Financial")
            return .financial
        }
        // Pharmacy (check before retail since CVS/Walgreens are pharmacies first)
        else if name.contains("pharmacy") || name.contains("cvs") || name.contains("walgreens") || name.contains("rite aid") || name.contains("drug") {
            print("🏢 [BusinessType] → Pharmacy")
            return .pharmacy
        }
        // Convenience/Retail
        else if name.contains("7-eleven") || name.contains("convenience") {
            return .retail
        }
        // Automotive
        else if name.contains("auto") || name.contains("repair") || name.contains("car") || name.contains("tire") {
            return .automotive
        }
        // Gas Station
        else if name.contains("gas") || name.contains("shell") || name.contains("chevron") || name.contains("exxon") {
            return .gasStation
        }
        // Lodging
        else if name.contains("hotel") || name.contains("inn") || name.contains("motel") {
            return .hotel
        }
        // Cafe
        else if name.contains("cafe") || name.contains("coffee") || name.contains("starbucks") {
            return .cafe
        }
        // Bar
        else if name.contains("bar") || name.contains("pub") || name.contains("tavern") {
            return .bar
        }
        // Gym/Fitness
        else if name.contains("gym") || name.contains("fitness") || name.contains("equinox") {
            print("🏢 [BusinessType] → Fitness")
            return .fitness
        }
        // Grocery
        else if name.contains("trader joe") || name.contains("whole foods") || name.contains("safeway") || name.contains("kroger") {
            print("🏢 [BusinessType] → Grocery")
            return .grocery
        }
        // Default to restaurant for food-related businesses
        else if name.contains("restaurant") || name.contains("grill") || name.contains("pizza") || name.contains("kitchen") || name.contains("diner") {
            print("🏢 [BusinessType] → Restaurant")
            return .restaurant
        }
        // Otherwise, mark as other
        else {
            print("🏢 [BusinessType] → Other (no match found)")
            return .other
        }
    }
    
    private func loadLocationStats(using allIssues: [Issue]) async {
        print("📊 [SimpleLocationsService] Loading location stats using existing issues data...")
        
        // Calculate stats for each location using the provided issues data
        for location in locations {
            let locationIssues = findIssuesForLocation(location, in: allIssues)
            let stats = calculateStats(for: location, issues: locationIssues)
            await MainActor.run {
                self.locationStats[location.id] = stats
            }
        }
        
        print("✅ [SimpleLocationsService] Loaded stats for \(locationStats.count) locations")
    }
    
    private func loadLocationStatsAndReturn(for locations: [SimpleLocation], using allIssues: [Issue]) async -> [String: LocationStats] {
        print("📊 [SimpleLocationsService] Loading location stats using existing issues data...")
        
        var stats: [String: LocationStats] = [:]
        
        // Calculate stats for each location using the provided issues data
        for location in locations {
            let locationIssues = findIssuesForLocation(location, in: allIssues)
            let locationStats = calculateStats(for: location, issues: locationIssues)
            stats[location.id] = locationStats
        }
        
        print("✅ [SimpleLocationsService] Loaded stats for \(stats.count) locations")
        return stats
    }
    
    private func findIssuesForLocation(_ location: SimpleLocation, in allIssues: [Issue]) -> [Issue] {
        let matchedIssues = allIssues.filter { issue in
            // PRIMARY MATCH: Direct Google Place ID match
            if issue.restaurantId == location.id {
                print("🎯 [SimpleLocationsService] Issue \(issue.id) matched location \(location.name) by direct Place ID")
                return true
            }
            
            // SECONDARY MATCH: Location ID match
            if issue.locationId == location.id {
                print("🎯 [SimpleLocationsService] Issue \(issue.id) matched location \(location.name) by locationId")
                return true
            }
            
            // TERTIARY MATCH: Google Place ID name resolution
            if issue.restaurantId.starts(with: "ChIJ") {
                let matched = matchByGooglePlaceId(issue.restaurantId, location: location)
                if matched {
                    print("🎯 [SimpleLocationsService] Issue \(issue.id) matched location \(location.name) by Google Place ID name")
                    return true
                }
            }
            
            // QUATERNARY MATCH: Business name extraction
            if let businessName = extractBusinessName(from: issue.locationId) {
                if location.name.lowercased().contains(businessName.lowercased()) || 
                   businessName.lowercased().contains(location.name.lowercased()) {
                    print("🎯 [SimpleLocationsService] Issue \(issue.id) matched location \(location.name) by business name")
                    return true
                }
            }
            
            return false
        }
        
        print("🔍 [SimpleLocationsService] Found \(matchedIssues.count) issues for location: \(location.name)")
        if matchedIssues.isEmpty {
            print("⚠️ [SimpleLocationsService] No issues matched for \(location.name) (ID: \(location.id))")
        } else {
            for issue in matchedIssues {
                print("   - Issue: \(issue.title) (restaurantId: \(issue.restaurantId))")
            }
        }
        
        return matchedIssues
    }
    
    private func extractBusinessName(from locationId: String) -> String? {
        // Simple extraction for meaningful location IDs
        if locationId.contains("_") && !locationId.starts(with: "ChIJ") {
            let components = locationId.components(separatedBy: "_")
            for component in components {
                if component.count > 3 && component.rangeOfCharacter(from: .letters) != nil {
                    return component.capitalized
                }
            }
        }
        return nil
    }
    
    private func matchByGooglePlaceId(_ placeId: String, location: SimpleLocation) -> Bool {
        // Check if location ID matches the Google Place ID directly
        if location.id == placeId {
            print("🎯 [SimpleLocationsService] Direct Place ID match: \(placeId)")
            return true
        }
        
        // Check Google Places cache for name matching
        if let cachedData = googlePlacesCache[placeId] {
            let nameMatch = location.name.lowercased().contains(cachedData.name.lowercased()) || 
                           cachedData.name.lowercased().contains(location.name.lowercased())
            if nameMatch {
                print("🎯 [SimpleLocationsService] Name match: '\(location.name)' <-> '\(cachedData.name)'")
            }
            return nameMatch
        }
        
        print("🔍 [SimpleLocationsService] No match for Place ID \(placeId) with location \(location.name)")
        return false
    }
    
    private func calculateStats(for location: SimpleLocation, issues: [Issue]) -> LocationStats {
        let openIssues = issues.filter { $0.status == .reported }
        let inProgressIssues = issues.filter { $0.status == .in_progress }
        let completedIssues = issues.filter { $0.status == .completed }
        
        // Calculate average response time
        let responseTimes = completedIssues.compactMap { issue -> TimeInterval? in
            return issue.createdAt.timeIntervalSince(issue.updatedAt)
        }
        
        let avgResponseTime: String
        if !responseTimes.isEmpty {
            let avgSeconds = responseTimes.reduce(0, +) / Double(responseTimes.count)
            let avgHours = avgSeconds / 3600
            if avgHours < 1 {
                avgResponseTime = "\(Int(avgSeconds / 60))m"
            } else if avgHours < 24 {
                avgResponseTime = String(format: "%.1fh", avgHours)
            } else {
                avgResponseTime = "\(Int(avgHours / 24))d"
            }
        } else {
            avgResponseTime = "N/A"
        }
        
        // Calculate health score with more reasonable algorithm
        let healthScore: Int
        if issues.isEmpty {
            healthScore = 95 // Default healthy score for locations with no issues
        } else {
            // More balanced health score calculation
            let totalIssues = issues.count
            let completedCount = completedIssues.count
            let inProgressCount = inProgressIssues.count
            let reportedCount = openIssues.count
            
            // Base score starts at 85 (good)
            var score = 85
            
            // Completed issues are positive (up to +15 points)
            if totalIssues > 0 {
                let completionBonus = min(Int(Double(completedCount) / Double(totalIssues) * 15), 15)
                score += completionBonus
            }
            
            // Too many open issues are negative (but not too harsh)
            let openPenalty = min(reportedCount * 5, 25) // Max 25 point penalty, 5 per open issue
            score -= openPenalty
            
            // In-progress issues are neutral (slight positive for activity)
            if inProgressCount > 0 {
                score += min(inProgressCount * 2, 5) // Small bonus for active work
            }
            
            // Keep score in reasonable range (30-100)
            healthScore = max(min(score, 100), 30)
            
            // Debug logging to understand health score calculation
            print("🏥 [HealthScore] Location: \(location.name)")
            print("🏥 [HealthScore] Total: \(totalIssues), Completed: \(completedCount), In Progress: \(inProgressCount), Reported: \(reportedCount)")
            print("🏥 [HealthScore] Base: 85, Completion bonus: +\(min(Int(Double(completedCount) / Double(totalIssues) * 15), 15)), Open penalty: -\(openPenalty)")
            print("🏥 [HealthScore] Final score: \(healthScore)")
        }
        
        return LocationStats(
            locationId: location.id,
            openIssuesCount: openIssues.count,
            completedIssuesCount: completedIssues.count,
            averageResponseTime: avgResponseTime,
            aiHealthScore: healthScore,
            isOnline: true,
            lastSync: "Just now"
        )
    }
}

// MARK: - Location Matching Helper
// Helps match issues to locations using various strategies

struct LocationMatcher {
    static func findBestMatch(for issue: Issue, in locations: [SimpleLocation]) -> SimpleLocation? {
        // Strategy 1: Direct ID match
        if let location = locations.first(where: { $0.id == issue.locationId }) {
            return location
        }
        
        // Strategy 2: Name-based matching (only use real locations, not hardcoded data)
        if let businessName = extractBusinessName(from: issue.locationId) {
            if let location = locations.first(where: { $0.name.lowercased() == businessName.lowercased() }) {
                return location
            }
        }
        
        // Strategy 3: Google Place ID mapping
        if issue.restaurantId.starts(with: "ChIJ") {
            return findLocationByGooglePlaceId(issue.restaurantId, in: locations)
        }
        
        // Strategy 4: Fallback to nearest location (if coordinates available)
        // This could be implemented if issue has coordinates
        
        return nil
    }
    
    private static func extractBusinessName(from locationId: String) -> String? {
        if locationId.contains("_") && !locationId.starts(with: "ChIJ") {
            let components = locationId.components(separatedBy: "_")
            for component in components {
                if component.count > 3 && component.rangeOfCharacter(from: .letters) != nil {
                    return component.capitalized
                }
            }
        }
        return nil
    }
    
    private static func findLocationByGooglePlaceId(_ placeId: String, in locations: [SimpleLocation]) -> SimpleLocation? {
        // Find location by matching the Google Place ID directly
        return locations.first { $0.id == placeId }
    }
    
}
