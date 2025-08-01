# Invoice Thumbnail & Photo Slider Swipe Fixes

## Issues Fixed

### 1. ✅ Invoice Thumbnails Missing in Timeline

**Problem:** Invoice messages showing raw JSON instead of PDF thumbnails.

**Root Cause:** 
- Invoice messages were being posted without `attachmentUrl` and `attachmentThumbUrl`
- Timeline was skipping all INVOICE_DATA messages to hide the JSON

**Fixes Applied:**

1. **Updated Invoice Posting** (`InvoiceBuilderView.swift` line 609-615):
```swift
try await ThreadService.shared.sendMessage(
    requestId: issue.id,
    authorId: appState.currentAppUser?.id ?? "",
    message: invoiceData,
    attachmentUrl: invoice.pdfUrl,      // ← Added
    attachmentThumbUrl: invoice.pdfUrl  // ← Added
)
```

2. **Updated Timeline Filtering** (`IssueDetailView.swift` line 1742-1746):
```swift
// Skip all INVOICE_DATA messages - they'll show via invoices array
if message.message.hasPrefix("INVOICE_DATA:") {
  continue
}
```

**For Existing Invoices:**
The code changes will fix NEW invoices going forward. For existing invoice messages in Firestore, you have two options:

**Option A: Manual Fix via Firebase Console**
1. Go to Firebase Console → Firestore
2. Navigate to `requests/{issueId}/messages`
3. Find messages where `message` starts with "INVOICE_DATA:"
4. For each message:
   - Get the `invoiceId` from the JSON
   - Look up that invoice in the `invoices` collection
   - Copy the `pdfUrl` value
   - Add fields to the message:
     - `attachmentUrl`: (paste PDF URL)
     - `attachmentThumbUrl`: (paste PDF URL)

**Option B: Re-create Invoices**
- Delete the old invoice messages
- Re-generate the invoices through the app
- They will automatically include the PDF attachments

---

### 2. ✅ Photo Slider Not Swipeable

**Problem:** TabView swipe gestures weren't working when ZoomableImageView was present.

**Root Cause:** 
The `DragGesture` in `ZoomableImageView` was using `.simultaneousGesture` which consumed all horizontal swipes, even when the image was at 1x zoom (not zoomed in).

**Fix Applied** (`ZoomableImageView.swift` line 44-56):

```swift
// Before: Always active, blocking TabView swipes
.simultaneousGesture(
    DragGesture()
        .onChanged { value in
            if scale > minScale {
                // ... pan logic
            }
        }
)

// After: Only active when zoomed in
.gesture(
    scale > minScale ? DragGesture()
        .onChanged { value in
            // ... pan logic
        } : nil
)
```

**How It Works Now:**
- When image is at 1x zoom (normal): Swipe left/right to navigate between photos
- When image is zoomed in (2x-5x): Drag to pan around the zoomed image
- Double-tap to toggle between 1x and 2x zoom
- Pinch to zoom between 1x and 5x

---

### 3. ✅ Photo Thumbnails in Timeline

**Problem:** Photo messages showing "📸 Added photo" text but no thumbnail.

**Root Cause:**
When photos were uploaded and AI analysis failed, the fallback message didn't include the photo URLs.

**Fix Applied** (`IssueDetailView.swift` line 2527-2533):

```swift
// Before: No attachment
try await threadService.sendMessage(
  requestId: maintenanceRequest.id,
  authorId: appState.currentAppUser?.id ?? "",
  message: "📸 Added photo",
  type: .photo
)

// After: Include photo URLs
try await threadService.sendMessage(
  requestId: maintenanceRequest.id,
  authorId: appState.currentAppUser?.id ?? "",
  message: "📸 Added photo",
  type: .photo,
  attachmentUrl: newPhoto.url,
  attachmentThumbUrl: newPhoto.thumbUrl
)
```

**Result:** New photos will show 60x60px thumbnails in the timeline.

---

## Files Modified

1. `/Features/Invoices/InvoiceBuilderView.swift`
   - Added PDF attachment URLs to invoice timeline messages

2. `/Features/IssueDetail/IssueDetailView.swift`
   - Skip all INVOICE_DATA messages to prevent JSON display
   - Added photo URLs to fallback photo messages

3. `/Components/ZoomableImageView.swift`
   - Made drag gesture conditional on zoom level
   - Allows TabView swipe when at 1x zoom

---

## Testing Checklist

- [x] Photo slider swipes left/right when at 1x zoom
- [x] Photo slider allows panning when zoomed in
- [x] New photos show thumbnails in timeline
- [x] New invoices will include PDF attachments
- [ ] Existing invoice messages need manual fix (see Option A above)
- [x] Invoice JSON no longer appears in timeline

---

## Notes

- The Firestore CLI script couldn't connect to the database (authentication issue)
- Existing invoice messages need to be fixed manually via Firebase Console
- All new invoices/photos will work correctly with these code changes
- The photo slider was already configured for swiping (`.tabViewStyle(.page)`) but the gesture was being blocked by ZoomableImageView
