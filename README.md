# Kevin - Restaurant Maintenance Management App

Kevin is an iOS app designed to streamline maintenance management for restaurants and hospitality businesses. It provides a comprehensive platform for reporting issues, managing work orders, tracking progress, and handling invoicing.

## Features

### 🔧 Issue Management
- Photo-based issue reporting with AI-powered descriptions
- Real-time status tracking
- Location-based issue assignment
- Priority management

### 💬 Communication
- Threaded messaging system
- Real-time notifications
- @mentions and user tagging
- Read receipts

### 📄 Invoicing System
- Professional PDF invoice generation
- Receipt photo attachments
- Email integration
- Automated billing workflows

### 🏢 Business Management
- Multi-location support
- User role management (Admin/Staff)
- Business verification system
- Service availability tracking

### 🤖 AI Integration
- Automated issue descriptions from photos
- Cost prediction for maintenance tasks
- Timeline analysis and insights

## Tech Stack

- **Platform**: iOS (SwiftUI)
- **Backend**: Firebase (Firestore, Storage, Auth, Functions)
- **Notifications**: Firebase Cloud Messaging + APNs
- **Maps**: Google Places API
- **Architecture**: MVVM with Combine

## Getting Started

### Prerequisites
- Xcode 15.0+
- iOS 16.0+
- Firebase project setup
- Google Places API key

### Installation

1. Clone the repository
```bash
git clone https://github.com/cpcashion/Kevin.git
cd Kevin
```

2. Open `Kevin.xcodeproj` in Xcode

3. Configure Firebase:
   - Add your `GoogleService-Info.plist` to the project
   - Update Firebase configuration in `FirebaseBootstrap.swift`

4. Configure Google Places:
   - Add your Google Places API key to the project configuration

5. Build and run the project

## Project Structure

```
Kevin/
├── Kevin/                          # Main app target
│   ├── KevinMaint/                # Core app code
│   │   ├── Features/              # Feature modules
│   │   │   ├── Invoices/         # Invoice management
│   │   │   ├── IssueDetail/      # Issue tracking
│   │   │   ├── Profile/          # User management
│   │   │   └── ...
│   │   ├── Services/             # Business logic services
│   │   ├── Models/               # Data models
│   │   └── Components/           # Reusable UI components
│   └── Assets.xcassets/          # App assets
├── functions/                     # Firebase Cloud Functions
└── tools/                        # Utility scripts
```

## Key Services

- **FirebaseClient**: Core Firebase integration
- **ThreadService**: Messaging and communication
- **NotificationService**: Push notifications
- **InvoicePDFGenerator**: PDF generation for invoices
- **AIAssistantService**: AI-powered features

## Contributing

This is a private project. For questions or support, contact the development team.

## License

Private - All rights reserved.
