# Firebase Firestore Indexes Setup

## Critical Issue: Missing Database Indexes

Your app is failing to load data because Firebase requires composite indexes for complex queries. Here are the exact links to create them:

### 1. Issues Collection Index
**Click this link to create:**
https://console.firebase.google.com/v1/r/project/kevin-ios-app/firestore/indexes?create_composite=Ckxwcm9qZWN0cy9rZXZpbi1pb3MtYXBwL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9pc3N1ZXMvaW5kZXhlcy9fEAEaEAoMcmVzdGF1cmFudElkEAEaDQoJY3JlYXRlZEF0EAIaDAoIX19uYW1lX18QAg

**Fields:**
- restaurantId (Ascending)
- createdAt (Descending) 
- __name__ (Descending)

### 2. Locations Collection Index
**Click this link to create:**
https://console.firebase.google.com/v1/r/project/kevin-ios-app/firestore/indexes?create_composite=Ck9wcm9qZWN0cy9rZXZpbi1pb3MtYXBwL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9sb2NhdGlvbnMvaW5kZXhlcy9fEAEaEAoMcmVzdGF1cmFudElkEAEaCAoEbmFtZRABGgwKCF9fbmFtZV9fEAE

**Fields:**
- restaurantId (Ascending)
- name (Ascending)
- __name__ (Ascending)

## Quick Fix Steps:
1. Click the links above
2. Click "Create Index" for each
3. Wait 2-5 minutes for indexes to build
4. Restart your app

**After creating these indexes, your app will be able to load issues and locations properly.**
