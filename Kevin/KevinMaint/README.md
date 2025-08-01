# Kevin Maint - Restaurant Maintenance App

A SwiftUI-based iOS app for restaurant maintenance issue tracking and management, built with Firebase backend.

## Features

- **Report Issues**: Submit maintenance issues with photos, categorization, and priority levels
- **Issue Tracking**: View and search through all reported issues with status indicators
- **Location Management**: Manage multiple restaurant locations
- **Firebase Integration**: Real-time data sync with Firestore and photo storage

## Project Structure

```
KevinMaint/
├── App/                    # Main app configuration
│   ├── KevinMaintApp.swift # App entry point
│   ├── AppState.swift      # Global app state
│   ├── FirebaseBootstrap.swift # Firebase initialization
│   └── RootView.swift      # Root navigation logic
├── Models/                 # Data models
│   ├── Entities.swift      # Core data structures
│   └── Mock.swift          # Sample data for development
├── Design/                 # UI components and theming
│   ├── Theme.swift         # App color scheme
│   └── Components/
│       └── StatusPill.swift # Status indicator component
├── Features/               # Feature modules
│   ├── Auth/
│   │   └── AuthView.swift  # Authentication screen
│   ├── ReportIssue/
│   │   ├── ReportIssueView.swift # Issue reporting form
│   │   └── PhotoPickerView.swift # Photo selection component
│   ├── IssuesList/
│   │   └── IssuesListView.swift  # Issues list with search
│   └── Locations/
│       └── LocationsView.swift   # Locations management
├── Services/               # External service integrations
│   └── FirebaseClient.swift # Firebase API client
├── firestore.rules        # Firestore security rules
└── storage.rules          # Firebase Storage security rules
```

## Setup Instructions

### 1. Xcode Project Setup
1. Create a new iOS project in Xcode named "KevinMaint"
2. Set deployment target to iOS 16.0 or later
3. Copy all the Swift files into your Xcode project following the directory structure above

### 2. Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Add an iOS app to your Firebase project
4. Download `GoogleService-Info.plist` and add it to your Xcode project root
5. Enable Firestore Database and Firebase Storage in the Firebase console

### 3. Dependencies
Add the following Swift Package Manager dependencies in Xcode:
- Firebase iOS SDK: `https://github.com/firebase/firebase-ios-sdk`
  - Select: FirebaseAuth, FirebaseFirestore, FirebaseStorage

### 4. Firebase Rules Deployment
Deploy the security rules to your Firebase project:

```bash
# Install Firebase CLI if you haven't already
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project directory
firebase init

# Deploy rules
firebase deploy --only firestore:rules,storage
```

### 5. Configuration
- In `AppState.swift`, set `isAuthed = false` to enable the auth flow
- Update demo location IDs in `ReportIssueView.swift` with real location IDs from your database

## Key Components

### Data Models
- **Issue**: Core maintenance issue with status tracking
- **Location**: Restaurant location information
- **AppUser**: User roles and permissions
- **WorkOrder**: Scheduled maintenance work

### Views
- **ReportIssueView**: Form for submitting new maintenance issues
- **IssuesListView**: Searchable list of all issues with status pills
- **LocationsView**: Management of restaurant locations
- **AuthView**: Placeholder for Firebase Authentication

### Firebase Integration
- **FirebaseClient**: Handles all Firebase operations
- **Issue Creation**: Stores issue data and uploads photos
- **Real-time Sync**: Uses Firestore for live data updates

## Development Notes

- Mock data is provided for development and testing
- Authentication is currently bypassed (set `isAuthed = true`)
- Firebase rules are permissive for development - tighten for production
- Photo uploads are compressed to 80% JPEG quality

## Next Steps

1. Implement Firebase Authentication
2. Add role-based permissions
3. Implement work order management
4. Add push notifications for issue updates
5. Enhance UI with more detailed issue views
