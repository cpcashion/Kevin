# Service Availability System - Implementation Guide

## Overview

The Kevin app now includes a comprehensive service availability system that informs users when Kevin's maintenance services are not yet available in their area. This prepares the app for App Store launch while we're only servicing the Charlotte, NC metro area.

## Service Area Definition

**Current Service Area:** Greater Charlotte, NC Metro Area
- **Center Point:** Charlotte, NC (35.2271°N, -80.8431°W)
- **Service Radius:** 50 miles from center
- **Coverage Includes:** Charlotte, Concord, Gastonia, Rock Hill, Huntersville, Matthews, Mint Hill, and surrounding areas

## User Experience Flow

### 1. **Location Detection** (Primary Check)
When a user takes a photo and confirms their location:
- System automatically checks if the selected business is within the service area
- Shows availability status immediately after location confirmation
- Users see one of two messages:

#### Available Area:
```
✅ Kevin is Available! 🎉
Great news! Kevin provides maintenance services in your area.
You're 15.3 miles from Charlotte, NC.
[Continue]
```

#### Unavailable Area:
```
⚠️ Coming Soon to Your Area
Kevin isn't available in your location yet, but we're expanding!
You're 150 miles from our nearest service area in Charlotte, NC.

⚠️ Limited Functionality
You can still create maintenance requests, but Kevin's team won't be able 
to service them until we expand to your area.

[Join Waitlist]  [Continue Anyway]
```

### 2. **Waitlist System**
For users outside the service area:
- **Join Waitlist Button** → Opens waitlist form
- Collects: Business name, email, phone (optional), location
- Stores in Firebase `waitlist` collection
- Users can still continue to use the app after joining waitlist

### 3. **Continue Anyway Option**
Users outside service area can still:
- Create maintenance requests
- Use all app features
- Explore the interface
- Be ready when service expands to their area

## Technical Implementation

### Files Created

1. **`ServiceAvailabilityService.swift`**
   - Calculates distance from Charlotte center
   - Determines if location is within 50-mile service radius
   - Provides user-friendly availability messages

2. **`ServiceAvailabilityCard.swift`**
   - Beautiful modal UI for showing availability status
   - Integrated waitlist form
   - Handles both available and unavailable scenarios

3. **Firebase Integration**
   - Added `submitWaitlistEntry()` method to FirebaseClient
   - Creates `waitlist` collection entries with:
     - Business name, email, phone, location
     - User ID (if authenticated)
     - Status tracking (pending/notified)
     - Timestamp for follow-up

### Integration Points

**MagicalLocationCard.swift** - Modified to check availability:
```swift
// When user confirms location
let availability = ServiceAvailabilityService.shared.isServiceAvailable(for: selectedBusiness)
// Show availability card
showingAvailabilityCheck = true
```

## Firebase Schema

### Waitlist Collection
```
waitlist/
  {waitlistId}/
    - id: String
    - businessName: String
    - email: String
    - phoneNumber: String? (optional)
    - location: String (description like "150 miles from Charlotte, NC")
    - userId: String? (if authenticated)
    - status: String ("pending" | "notified" | "contacted")
    - createdAt: Timestamp
    - notified: Boolean
```

## Admin Dashboard Recommendations

To manage waitlist entries, you can:

1. **View Waitlist in Firebase Console:**
   - Go to Firestore Database
   - Navigate to `waitlist` collection
   - Sort by `createdAt` to see newest entries

2. **Export Waitlist Data:**
   ```javascript
   // Firebase Console > Firestore > Export
   // Or use Firebase Admin SDK to export to CSV
   ```

3. **Notify Users When Expanding:**
   - Query waitlist by location
   - Send expansion notification emails
   - Update `status` to "notified"

## Customization Options

### Adjust Service Radius
In `ServiceAvailabilityService.swift`:
```swift
private let serviceRadiusMeters: Double = 80_467 // 50 miles
// Change to expand/contract service area
```

### Add Multiple Service Areas
Extend the service to support multiple cities:
```swift
private let serviceAreas = [
    ServiceArea(name: "Charlotte, NC", center: CLLocationCoordinate2D(...), radius: 80_467),
    ServiceArea(name: "Atlanta, GA", center: CLLocationCoordinate2D(...), radius: 80_467)
]
```

### Customize Messaging
In `ServiceAvailabilityService.swift`, modify `getAvailabilityMessage()`:
- Change titles, messages, button text
- Add promotional messaging
- Include estimated expansion dates

## Testing

### Test Available Area (Charlotte):
- Use simulator location: Charlotte, NC
- Create issue at any Charlotte business
- Should see "Kevin is Available!" message

### Test Unavailable Area:
- Use simulator location: New York, NY or Los Angeles, CA
- Create issue at business in that area
- Should see "Coming Soon" message with waitlist option

### Test Waitlist Submission:
1. Be in unavailable area
2. Tap "Join Waitlist"
3. Fill out form
4. Check Firebase Console → waitlist collection
5. Verify entry was created

## Future Enhancements

1. **Email Notifications:**
   - Send confirmation email when user joins waitlist
   - Notify users when service expands to their area

2. **Expansion Tracking:**
   - Dashboard showing waitlist demand by region
   - Heatmap of waitlist entries
   - Prioritize expansion based on demand

3. **Estimated Availability:**
   - Show "Coming Q2 2025" based on expansion plans
   - Update messaging as expansion approaches

4. **Referral Program:**
   - "Refer 5 businesses in your area to move up the waitlist"
   - Incentivize early adoption in new markets

## Benefits

✅ **App Store Ready:** Can launch nationally without service limitations blocking users
✅ **Market Research:** Collect demand data for expansion planning
✅ **User Retention:** Users can explore app even if service unavailable
✅ **Professional UX:** Clear communication about service limitations
✅ **Growth Pipeline:** Build waitlist for future expansion
✅ **Transparent:** Users know exactly what to expect

## Support

For questions or issues with the service availability system:
- Check Firebase Console for waitlist entries
- Review logs for availability checks
- Test with different simulator locations
- Adjust service radius as needed for soft launch

---

**Implementation Status:** ✅ Complete and ready for testing
**App Store Readiness:** ✅ Ready for national launch with Charlotte service area
