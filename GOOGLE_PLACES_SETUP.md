# Google Places API Setup for Kevin Maint

## The Issue
Your restaurant onboarding screen isn't working because:
1. ❌ Missing Google Places API key
2. ❌ Location permissions weren't configured (now fixed)
3. ❌ Text field styling issues (now fixed)

## Quick Fix - Get Google Places API Key

### Step 1: Get API Key
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the **Places API** and **Places API (New)**
4. Go to "Credentials" → "Create Credentials" → "API Key"
5. Copy your API key

### Step 2: Add API Key to Your App
1. Open your Xcode project
2. Select the main target (Kevin)
3. Go to "Info" tab
4. Add a new row:
   - **Key**: `GOOGLE_PLACES_API_KEY`
   - **Type**: String
   - **Value**: Your API key from Step 1

### Step 3: Secure Your API Key (Recommended)
1. In Google Cloud Console, click on your API key
2. Under "Application restrictions", select "iOS apps"
3. Add your bundle identifier: `com.kevinmaint.app` (or whatever yours is)
4. Under "API restrictions", select "Restrict key" and choose:
   - Places API
   - Places API (New)

## What I Fixed
✅ Added location permissions to Info.plist
✅ Fixed text field visibility (black text on white background)
✅ Added proper error handling for missing API key
✅ Added location availability checks
✅ Improved search error messages

## Test the Fix
1. Add the API key as described above
2. Run the app
3. Go through onboarding to the restaurant setup screen
4. Allow location permissions when prompted
5. Type a restaurant name (e.g., "Starbucks", "McDonald's")
6. You should see autocomplete results appear

## Alternative: Mock Data for Testing
If you want to test without setting up Google Places API right now, I can create a mock version that shows fake restaurant data for testing purposes.
