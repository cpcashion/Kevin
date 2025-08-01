# Nationwide Location Search Feature

## Problem Statement
Operators need the ability to create work orders for issues at their business locations even when they're not physically present. 

**Example Scenario:**
- Operator takes a photo of an issue during the day
- Gets busy and doesn't submit it immediately
- Goes home later that evening
- Wants to create the work order but is no longer at the location

## Solution: Google Maps-Style Search

### **Design Approach**
We implemented a **Google Maps-style search interface** with nationwide capability:

1. **Always-Visible Search Bar** - At the top of the location selection modal
2. **Nearby Businesses (Default)** - Shows detected and nearby locations when not searching
3. **Nationwide Search** - Type any business name to search across the entire country
4. **No Radius Restrictions** - Find businesses anywhere, not limited to 1-mile radius

This provides the best of both worlds:
- ✅ Fast and effortless when on-site (automatic detection + nearby list)
- ✅ Powerful search when remote (nationwide text search)
- ✅ Familiar UX pattern (just like Google Maps)
- ✅ No mode switching or hidden features

---

## User Experience Flow

### **Scenario 1: On-Site (Quick Confirm)**
1. User takes photo of issue
2. AI analyzes the photo
3. User taps "Select Location"
4. App detects GPS location and shows:
   - **Search bar at top** (always visible)
   - **"📍 You're at Maple Leaf Hardware"** (suggested business)
   - List of nearby businesses below
5. Suggested business is pre-selected
6. User taps "Confirm Location"
7. Issue created ✅

### **Scenario 2: On-Site (Different Business)**
1. User takes photo of issue
2. AI analyzes the photo
3. User taps "Select Location"
4. App detects wrong location (e.g., "📍 You're at Starbucks")
5. User scrolls through nearby businesses list
6. User taps correct business (e.g., "Maple Leaf Hardware" 50m away)
7. User taps "Confirm Location"
8. Issue created ✅

### **Scenario 3: Remote (Nationwide Search)**
1. User opens photo from library (taken earlier in the day)
2. AI analyzes the photo
3. User taps "Select Location"
4. App shows nearby businesses (current location = home)
5. **User types in search bar**: "Maple Leaf Hardware Charlotte"
6. Search executes nationwide (no radius limit)
7. Results appear:
   - Maple Leaf Hardware - Charlotte, NC (1,245 miles)
   - Maple Leaf Hardware - Portland, OR (2,890 miles)
8. User selects correct location
9. User taps "Confirm Location"
10. Issue created ✅

---

## Implementation Details

### **Files Modified**
1. **`MagicalLocationCard.swift`** - Main location selection modal with always-visible search
2. **`GooglePlacesService.swift`** - Added nationwide search capability

### **New Features**

#### **1. Always-Visible Search Bar**
Search bar is permanently displayed at the top of the location modal:
```swift
private var searchBar: some View {
  HStack(spacing: 12) {
    Image(systemName: "magnifyingglass")
    TextField("Search any business nationwide...", text: $searchText)
      .onChange(of: searchText) { newValue in
        performSearch(query: newValue)
      }
    // Loading indicator or clear button
  }
  .padding(12)
  .background(KMTheme.cardBackground)
  .cornerRadius(12)
}
```

#### **2. Nationwide Search Function**
New Google Places API function without radius restrictions:
```swift
func searchBusinessesNationwide(query: String, userLocation: CLLocation?) async throws -> [NearbyBusiness] {
  // Text search WITHOUT radius parameter
  var urlString = "\(baseURL)/textsearch/json?" +
    "query=\(query)&key=\(apiKey)"
  
  // Location used for distance calculation only, not filtering
  if let location = userLocation {
    urlString += "&location=\(location.coordinate.latitude),\(location.coordinate.longitude)"
  }
  // Returns businesses from anywhere in the country
}
```

#### **3. Smart Result Switching**
Automatically switches between nearby and search results:
```swift
let businessesToShow = searchText.isEmpty 
  ? locationContext.nearbyBusinesses.sorted { $0.distance < $1.distance }
  : searchResults

// Show "Detected" badge only when not searching
isDetected: searchText.isEmpty && business.id == locationContext.suggestedBusiness?.id
```

#### **4. Debounced Search**
500ms delay prevents excessive API calls:
```swift
private func performSearch(query: String) {
  Task {
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
    guard query == searchText else { return } // Check if changed
    
    let results = try await googlePlacesService.searchBusinessesNationwide(
      query: query,
      userLocation: userLocation
    )
    self.searchResults = results
  }
}
```

---

## Key Features

### **1. Seamless Transition**
- Smooth animation between automatic and manual modes
- State preserved when switching back and forth
- No data loss

### **2. Smart Search**
- **Real-time filtering** - Results update as you type
- **Case-insensitive** - Works with any capitalization
- **Multi-field search** - Searches both name and address
- **Distance sorting** - Closest businesses shown first

### **3. Visual Feedback**
- **"Detected" badge** - Shows which business was auto-detected (only in automatic mode)
- **Selection indicator** - Clear checkmark on selected business
- **Empty state** - Helpful message when no results found
- **Haptic feedback** - Tactile confirmation on selection

### **4. Accessibility**
- **Clear labels** - "Not at location? Search manually"
- **Back button** - Easy return to automatic detection
- **Search placeholder** - "Search for your business..."
- **Clear button** - Quick way to reset search (X icon)

---

## User Benefits

### **For Operators**
✅ **Flexibility** - Can create work orders from anywhere  
✅ **No location required** - Don't need to be on-site  
✅ **Fast search** - Find business quickly by typing name  
✅ **No mistakes** - See address to confirm correct location  

### **For Business Owners**
✅ **Better coverage** - Issues get reported even when staff is off-site  
✅ **Faster response** - No delay waiting to be on-site  
✅ **Complete records** - All issues documented regardless of when discovered  

### **For Kevin (Admin)**
✅ **More data** - Higher issue reporting rate  
✅ **Better insights** - Complete picture of all locations  
✅ **Reduced friction** - Easier for operators to use the app  

---

## Technical Considerations

### **State Management**
```swift
@State private var showingManualSearch = false
@State private var searchText = ""
```

### **Conditional Rendering**
```swift
if showingManualSearch {
  manualSearchView
} else {
  businessList
}
```

### **Animation**
```swift
withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
  showingManualSearch = true
}
```

---

## Future Enhancements

### **Phase 2: Recent Locations**
Add a "Recent" section showing:
- Last 5 locations where user created issues
- Quick access without searching
- Sorted by most recent first

### **Phase 3: Assigned Locations**
For non-admin users:
- Show their assigned locations at top
- Filter to only show locations they manage
- "All Locations" option to search beyond assigned

### **Phase 4: Favorites**
- Star/favorite frequently used locations
- Quick access to favorites
- Sync across devices

### **Phase 5: Offline Support**
- Cache location data locally
- Allow issue creation offline
- Sync when connection restored

---

## Testing Scenarios

### **Test Case 1: On-Site Happy Path**
1. Be physically at a business location
2. Take photo of issue
3. Tap "Select Location"
4. Verify suggested business is correct
5. Tap "Confirm Location"
6. ✅ Issue created with correct location

### **Test Case 2: Remote Search**
1. Be at home (not at business)
2. Take photo or use existing photo
3. Tap "Select Location"
4. Tap "Not at location? Search manually"
5. Search for business name
6. Select correct business
7. Tap "Confirm Location"
8. ✅ Issue created with correct location

### **Test Case 3: Search No Results**
1. Enter manual search mode
2. Type gibberish in search bar
3. ✅ Verify "No businesses found" message appears
4. Clear search
5. ✅ Verify all businesses reappear

### **Test Case 4: Back Navigation**
1. Enter manual search mode
2. Tap "Back" button
3. ✅ Verify returns to automatic detection view
4. ✅ Verify search text is cleared

### **Test Case 5: Search Filtering**
1. Enter manual search mode
2. Type partial business name (e.g., "Maple")
3. ✅ Verify only matching businesses shown
4. Type more characters
5. ✅ Verify results filter further
6. Clear search
7. ✅ Verify all businesses reappear

---

## Success Metrics

### **Adoption**
- % of issues created using manual search
- % of issues created remotely (not on-site)
- Time saved by not requiring on-site presence

### **Accuracy**
- % of correct location selections
- % of issues with wrong location (error rate)
- User corrections/changes after initial selection

### **Efficiency**
- Average time to select location (automatic vs manual)
- Number of searches before finding correct business
- Abandonment rate in location selection flow

---

## Summary

The manual location selection feature solves a critical UX problem by allowing operators to create work orders from anywhere, not just when physically on-site. The hybrid approach maintains the speed and convenience of automatic detection while providing the flexibility of manual search when needed.

**Key Innovation:** The "Not at location? Search manually" button provides a clear escape hatch without cluttering the primary automatic detection flow.

**Result:** Operators can now document issues immediately when discovered, even if they're reviewing photos later from home, leading to faster issue resolution and better maintenance records.
