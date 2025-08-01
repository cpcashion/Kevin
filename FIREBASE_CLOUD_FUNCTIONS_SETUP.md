# Firebase Cloud Functions Setup for Push Notifications

This document explains how to set up Firebase Cloud Functions to handle push notifications for the Kevin Maint messaging system.

## Overview

The app uses a trigger-based notification system:
1. When messages are sent, the app creates documents in the `notificationTriggers` collection
2. A Cloud Function monitors this collection and sends FCM notifications
3. Users receive push notifications on their devices

## Required Setup

### 1. Install Firebase CLI and Initialize Functions

```bash
npm install -g firebase-tools
firebase login
firebase init functions
```

### 2. Install Dependencies

```bash
cd functions
npm install firebase-admin firebase-functions
```

### 3. Create the Cloud Function

Create `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendNotifications = functions.firestore
  .document('notificationTriggers/{triggerId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    if (data.processed) {
      console.log('Notification already processed');
      return null;
    }
    
    try {
      // Get FCM tokens for target users
      const userIds = data.userIds || [];
      const tokens = [];
      
      for (const userId of userIds) {
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(userId)
          .get();
          
        if (userDoc.exists) {
          const fcmToken = userDoc.data().fcmToken;
          if (fcmToken) {
            tokens.push(fcmToken);
          }
        }
      }
      
      if (tokens.length === 0) {
        console.log('No FCM tokens found for users');
        return null;
      }
      
      // Send notification
      const message = {
        notification: {
          title: data.title,
          body: data.body
        },
        data: {
          type: data.data.type || 'message',
          conversationId: data.data.conversationId || '',
          senderId: data.data.senderId || '',
          restaurantName: data.data.restaurantName || '',
          timestamp: data.data.timestamp?.toString() || ''
        },
        tokens: tokens
      };
      
      const response = await admin.messaging().sendMulticast(message);
      
      console.log(`Sent ${response.successCount} notifications successfully`);
      console.log(`Failed to send ${response.failureCount} notifications`);
      
      // Mark as processed
      await snap.ref.update({ processed: true, processedAt: admin.firestore.FieldValue.serverTimestamp() });
      
      return null;
    } catch (error) {
      console.error('Error sending notifications:', error);
      throw error;
    }
  });
```

### 4. Deploy the Function

```bash
firebase deploy --only functions
```

## Security Rules Update

Add to `firestore.rules`:

```javascript
// Notification triggers - only authenticated users can create
match /notificationTriggers/{triggerId} {
  allow create: if request.auth != null;
  allow read, update: if false; // Only Cloud Functions should read/update
}

// Users collection - allow FCM token updates
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
  allow update: if request.auth != null && 
    request.writeFields.hasOnly(['fcmToken', 'tokenUpdatedAt']);
}
```

## Testing

1. Send a message in the app
2. Check Firebase Console > Functions for execution logs
3. Verify notifications appear on recipient devices

## Troubleshooting

### No notifications received:
- Check FCM tokens are being saved to user documents
- Verify Cloud Function is executing (check logs)
- Ensure APNs certificates are uploaded in Firebase Console
- Test on physical device (notifications don't work in simulator)

### Function errors:
- Check Firebase Console > Functions > Logs
- Verify Firestore security rules allow function access
- Ensure all required fields are present in notification triggers

## Production Considerations

1. **Rate Limiting**: Add rate limiting to prevent spam
2. **Batch Processing**: Handle large user lists efficiently  
3. **Error Handling**: Implement retry logic for failed sends
4. **Analytics**: Track notification delivery rates
5. **Personalization**: Customize notifications based on user preferences

## Cost Optimization

- FCM notifications are free up to reasonable limits
- Cloud Function executions are billed per invocation
- Consider batching multiple notifications into single function calls
- Clean up old notification trigger documents to save storage costs
