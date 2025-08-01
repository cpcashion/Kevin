#!/bin/bash

# Firebase Project ID
PROJECT_ID="kevin-ios-app"

echo "🗑️  Deleting all issues and work orders from Firebase..."
echo "Project: $PROJECT_ID"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Login to Firebase (if not already logged in)
echo "🔐 Checking Firebase authentication..."
firebase login --reauth

# Delete collections using Firestore
echo ""
echo "📋 Deleting maintenance_requests collection..."
firebase firestore:delete maintenance_requests --project $PROJECT_ID --recursive --yes

echo ""
echo "🔧 Deleting work_orders collection..."
firebase firestore:delete work_orders --project $PROJECT_ID --recursive --yes

echo ""
echo "📸 Deleting issuePhotos collection..."
firebase firestore:delete issuePhotos --project $PROJECT_ID --recursive --yes

echo ""
echo "✅ All data deleted successfully!"
echo ""
echo "🎉 Your Firebase database is now clean and ready for App Store launch!"
