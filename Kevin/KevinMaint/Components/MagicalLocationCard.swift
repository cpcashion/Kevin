import SwiftUI
import CoreLocation

struct MagicalLocationCard: View {
  let locationContext: LocationContext
  @Binding var selectedRestaurant: NearbyBusiness?
  let onConfirm: (NearbyBusiness) -> Void
  let onDismiss: () -> Void
  
  @State private var isVisible = false
  @State private var selectedBusinessId: String? = nil
  @State private var showingAllBusinessTypes = false
  @State private var searchText = ""
  @State private var searchResults: [NearbyBusiness] = []
  @State private var isSearching = false
  
  @EnvironmentObject var appState: AppState
  
  private let googlePlacesService = GooglePlacesService.shared
  
  var body: some View {
    ZStack {
      // Full-screen modal with proper safe area handling
      ZStack {
        // Background
        KMTheme.background
          .ignoresSafeArea()
        
        VStack(spacing: 0) {
          modalHeader
          searchBar
          businessList
        }
        
        // Fixed confirm button at bottom
        VStack {
          Spacer()
          confirmButton
        }
      }
      .opacity(isVisible ? 1.0 : 0.0)
      .animation(.easeOut(duration: 0.3), value: isVisible)
      .onAppear {
        // Auto-select suggested business
        if let suggested = locationContext.suggestedBusiness {
          selectedBusinessId = suggested.id
          selectedRestaurant = suggested
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
          isVisible = true
        }
      }
    }
  }
  
  private var modalHeader: some View {
    VStack(spacing: 0) {
      // Reduced safe area top padding
      Color.clear
        .frame(height: 20) // Minimal top spacing
      
      // Header with detected business context
      VStack(alignment: .leading, spacing: 6) {
        if let suggested = locationContext.suggestedBusiness {
          Text("📍 You're at \(suggested.name)")
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(KMTheme.primaryText)
          
          Text("Tap to confirm or search for a different business")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(KMTheme.secondaryText)
        } else {
          Text("📍 Select Your Business")
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(KMTheme.primaryText)
          
          Text("Search or choose from nearby businesses")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(KMTheme.secondaryText)
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 12)
    }
  }
  
  private var searchBar: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(KMTheme.secondaryText)
        
        TextField("Search any business nationwide...", text: $searchText)
          .font(.system(size: 16))
          .foregroundColor(KMTheme.primaryText)
          .autocapitalization(.words)
          .disableAutocorrection(true)
          .onChange(of: searchText) { newValue in
            performSearch(query: newValue)
          }
        
        if isSearching {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: KMTheme.accent))
            .scaleEffect(0.8)
        } else if !searchText.isEmpty {
          Button(action: { 
            searchText = ""
            searchResults = []
          }) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 16))
              .foregroundColor(KMTheme.tertiaryText)
          }
        }
      }
      .padding(12)
      .background(KMTheme.cardBackground)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(searchText.isEmpty ? KMTheme.border : KMTheme.accent.opacity(0.5), lineWidth: searchText.isEmpty ? 1 : 2)
      )
      .padding(.horizontal, 24)
      .padding(.bottom, 16)
    }
  }
  
  private func performSearch(query: String) {
    guard !query.isEmpty else {
      searchResults = []
      return
    }
    
    // Debounce search
    Task {
      try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
      
      guard query == searchText else { return } // Check if search text changed
      
      await MainActor.run {
        isSearching = true
      }
      
      do {
        let results = try await googlePlacesService.searchBusinessesNationwide(
          query: query,
          userLocation: CLLocation(
            latitude: locationContext.latitude,
            longitude: locationContext.longitude
          )
        )
        
        await MainActor.run {
          self.searchResults = results
          self.isSearching = false
          print("🔍 [MagicalLocationCard] Search '\(query)' returned \(results.count) results")
        }
      } catch {
        await MainActor.run {
          self.isSearching = false
          print("❌ [MagicalLocationCard] Search error: \(error)")
        }
      }
    }
  }
  
  private var businessList: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        // Show search results if searching, otherwise show nearby businesses
        let businessesToShow = searchText.isEmpty 
          ? locationContext.nearbyBusinesses.sorted { $0.distance < $1.distance }
          : searchResults
        
        if businessesToShow.isEmpty && !searchText.isEmpty && !isSearching {
          // Empty search state
          VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 48))
              .foregroundColor(KMTheme.tertiaryText)
            
            Text("No businesses found")
              .font(.headline)
              .foregroundColor(KMTheme.primaryText)
            
            Text("Try a different search term")
              .font(.subheadline)
              .foregroundColor(KMTheme.secondaryText)
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 60)
        } else {
          ForEach(businessesToShow, id: \.id) { business in
            BusinessCard(
              business: business,
              isSelected: selectedBusinessId == business.id,
              isDetected: searchText.isEmpty && business.id == locationContext.suggestedBusiness?.id
            ) {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedBusinessId = business.id
                selectedRestaurant = business
                
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
              }
            }
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 4)
      .padding(.bottom, 140) // Space for fixed confirm button
    }
  }
  
  private var confirmButton: some View {
    VStack(spacing: 0) {
      // Gradient overlay to show button is always visible
      LinearGradient(
        colors: [KMTheme.background.opacity(0), KMTheme.background],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 20)
      
      VStack(spacing: 16) {
        Button(action: {
          guard let selected = selectedRestaurant else { return }
          
          // Success haptic
          let success = UINotificationFeedbackGenerator()
          success.notificationOccurred(.success)
          
          // Confirm location for all users
          onConfirm(selected)
        }) {
          HStack {
            Spacer()
            
            if let selected = selectedRestaurant {
              HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18, weight: .semibold))
                
                Text("Confirm Location")
                  .font(.system(size: 18, weight: .semibold))
              }
              .foregroundColor(.white)
            } else {
              Text("Select a Business")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(KMTheme.tertiaryText)
            }
            
            Spacer()
          }
          .frame(height: 56)
          .background(
            selectedRestaurant != nil ? 
              Color.blue : 
              KMTheme.cardBackground
          )
          .cornerRadius(16)
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                selectedRestaurant != nil ? 
                  Color.blue.opacity(0.3) : 
                  KMTheme.border, 
                lineWidth: 1
              )
          )
        }
        .disabled(selectedRestaurant == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedRestaurant)
        
        if selectedRestaurant == nil {
          HStack(spacing: 8) {
            Image(systemName: "info.circle")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(Color.blue)
            
            Text("Select your business to continue")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(KMTheme.secondaryText)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(12)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 100) // Extra padding for tab bar (49pt bar + 34pt safe area + 17pt spacing)
      .background(KMTheme.background)
    }
  }
}

// MARK: - Business Card Component
struct BusinessCard: View {
  let business: NearbyBusiness
  let isSelected: Bool
  let isDetected: Bool
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 16) {
        // Selection indicator
        ZStack {
          Circle()
            .stroke(isSelected ? Color.blue : KMTheme.border, lineWidth: 2)
            .frame(width: 24, height: 24)
          
          if isSelected {
            Circle()
              .fill(Color.blue)
              .frame(width: 24, height: 24)
              .overlay(
                Image(systemName: "checkmark")
                  .font(.system(size: 12, weight: .bold))
                  .foregroundColor(.white)
              )
              .scaleEffect(0.8)
          }
        }
        
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(business.name)
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(KMTheme.primaryText)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
            
            Spacer()
            
            if isDetected {
              HStack(spacing: 4) {
                Image(systemName: "location.fill")
                  .font(.system(size: 10, weight: .medium))
                Text("📍 Detected")
                  .font(.system(size: 11, weight: .semibold))
              }
              .foregroundColor(.white)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(Color.blue)
              .cornerRadius(12)
            }
          }
          
          // Business type and rating
          HStack(spacing: 8) {
            Text(business.businessType.displayName)
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(Color(hex: business.typeColor) ?? Color.gray)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color(hex: business.typeColor)?.opacity(0.2) ?? Color.gray.opacity(0.2))
              .cornerRadius(6)
            
            if let rating = business.rating {
              HStack(spacing: 2) {
                Image(systemName: "star.fill")
                  .font(.system(size: 10))
                  .foregroundColor(.yellow)
                Text(String(format: "%.1f", rating))
                  .font(.system(size: 12, weight: .medium))
                  .foregroundColor(KMTheme.secondaryText)
              }
            }
            
            if let isOpen = business.isOpen {
              Text(isOpen ? "Open" : "Closed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isOpen ? .green : .red)
            }
          }
          
          if let address = business.address {
            Text(address)
              .font(.system(size: 14, weight: .regular))
              .foregroundColor(KMTheme.secondaryText)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }
          
          Text(business.distanceText)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.blue)
        }
        
        Spacer()
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(isSelected ? Color.blue.opacity(0.1) : KMTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(isSelected ? Color.blue.opacity(0.5) : KMTheme.border, lineWidth: isSelected ? 2 : 1)
          )
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// MARK: - Business Type Section Component
struct BusinessTypeSection: View {
  let businessType: BusinessType
  let businesses: [NearbyBusiness]
  @Binding var selectedBusinessId: String?
  @Binding var selectedBusiness: NearbyBusiness?
  let suggestedBusinessId: String?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Section header
      HStack(spacing: 8) {
        Text(businessType.icon)
          .font(.system(size: 18))
        
        Text(businessType.displayName)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(KMTheme.primaryText)
        
        Text("(\(businesses.count))")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(KMTheme.secondaryText)
        
        Spacer()
      }
      .padding(.horizontal, 4)
      
      // Business cards
      ForEach(businesses.sorted { $0.distance < $1.distance }, id: \.id) { business in
        BusinessCard(
          business: business,
          isSelected: selectedBusinessId == business.id,
          isDetected: business.id == suggestedBusinessId
        ) {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedBusinessId = business.id
            selectedBusiness = business
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
          }
        }
      }
    }
  }
}

// MARK: - Preview
struct MagicalLocationCard_Previews: PreviewProvider {
  static var previews: some View {
    let sampleBusinesses = [
      NearbyBusiness(
        id: "1",
        name: "Kindred Restaurant",
        address: "431 N Davidson St, Charlotte, NC 28202",
        distance: 25,
        latitude: 35.2271,
        longitude: -80.8431,
        businessType: .restaurant,
        rating: 4.8,
        priceLevel: 3,
        isOpen: true,
        photoReference: nil
      ),
      NearbyBusiness(
        id: "2", 
        name: "Shell Gas Station",
        address: "128 Main St, Davidson, NC 28036",
        distance: 150,
        latitude: 35.4993,
        longitude: -80.8481,
        businessType: .gasStation,
        rating: 4.2,
        priceLevel: nil,
        isOpen: true,
        photoReference: nil
      )
    ]
    
    let context = LocationContext(
      latitude: 35.2271,
      longitude: -80.8431,
      accuracy: 5.0,
      timestamp: Date(),
      wifiFingerprint: nil,
      nearbyBusinesses: sampleBusinesses,
      suggestedBusiness: sampleBusinesses.first
    )
    
    MagicalLocationCard(
      locationContext: context,
      selectedRestaurant: .constant(nil),
      onConfirm: { _ in },
      onDismiss: { }
    )
    .preferredColorScheme(.dark)
  }
}
