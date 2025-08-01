const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function to send push notifications when notification triggers are created
 */
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

        console.log(`Processing notification for ${userIds.length} users`);

        for (const userId of userIds) {
          try {
            console.log(`Checking user: ${userId}`);
            const userDoc = await admin.firestore()
                .collection('users')
                .doc(userId)
                .get();

            if (userDoc.exists) {
              const userData = userDoc.data();
              console.log(`User data for ${userId}:`, JSON.stringify(userData, null, 2));

              const fcmToken = userData.fcmToken;
              if (fcmToken) {
                tokens.push(fcmToken);
                console.log(`✅ Found FCM token for user ${userId}: ${fcmToken.substring(0, 20)}...`);
              } else {
                console.log(`❌ No FCM token for user: ${userId}`);
                console.log('Available fields:', Object.keys(userData));
              }
            } else {
              console.log(`❌ User document not found: ${userId}`);
            }
          } catch (error) {
            console.error(`Error fetching user ${userId}:`, error);
          }
        }

        if (tokens.length === 0) {
          console.log('No FCM tokens found for users');
          await snap.ref.update({
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            error: 'No FCM tokens found',
          });
          return null;
        }

        // Prepare notification message with COMPLETE data for deep linking
        const notificationData = data.data || {};
        const message = {
          notification: {
            title: data.title || 'New Message',
            body: data.body || 'You have a new message',
          },
          // Include ALL data fields for proper deep linking
          data: {
            type: notificationData.type || 'message',
            issueId: notificationData.issueId || '',
            conversationId: notificationData.conversationId || '',
            senderId: notificationData.senderId || '',
            restaurantName: notificationData.restaurantName || '',
            issueTitle: notificationData.issueTitle || '',
            updateType: notificationData.updateType || '',
            updatedBy: notificationData.updatedBy || '',
            priority: notificationData.priority || '',
            status: notificationData.status || '',
            timestamp: notificationData.timestamp ? notificationData.timestamp.toString() : Date.now().toString(),
          },
          // CRITICAL: Add badge increment for iOS
          apns: {
            headers: {
              // Required by Apple for iOS 13+ to ensure alert-type delivery
              'apns-push-type': 'alert',
              // High priority delivery for user-visible notifications
              'apns-priority': '10',
            },
            payload: {
              aps: {
                badge: 1, // This tells iOS to increment the badge
                sound: 'default',
              },
            },
          },
          tokens: tokens,
        };

        console.log(`Sending notification to ${tokens.length} devices`);
        console.log('Notification payload:', JSON.stringify(message, null, 2));

        // Send notification with better error handling
        console.log('About to call admin.messaging().sendMulticast()...');

        let response;
        try {
          response = await admin.messaging().sendMulticast(message);
          console.log(`Successfully sent ${response.successCount} notifications`);
          console.log(`Failed to send ${response.failureCount} notifications`);
        } catch (messagingError) {
          console.error('FCM sendMulticast error:', messagingError);
          console.error('Error code:', messagingError.code);
          console.error('Error message:', messagingError.message);

          // Try sending individual messages as fallback
          console.log('Attempting individual message sending as fallback...');
          let successCount = 0;
          let failureCount = 0;

          for (let i = 0; i < tokens.length; i++) {
            try {
              const individualMessage = {
                notification: message.notification,
                data: message.data,
                apns: message.apns,
                token: tokens[i],
              };

              await admin.messaging().send(individualMessage);
              successCount++;
              console.log(`Individual message ${i + 1} sent successfully`);
            } catch (individualError) {
              failureCount++;
              console.error(`Individual message ${i + 1} failed:`, individualError.message);
            }
          }

          response = {successCount, failureCount};
        }

        // Log any failures
        if (response.failureCount > 0 && response.responses) {
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              console.error(`Failed to send to token ${idx}:`, resp.error);
            }
          });
        }

        // Mark as processed with results
        await snap.ref.update({
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          successCount: response.successCount,
          failureCount: response.failureCount,
          totalTokens: tokens.length,
        });

        return null;
      } catch (error) {
        console.error('Error sending notifications:', error);

        // Mark as processed with error
        await snap.ref.update({
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          error: error.message,
        });

        throw error;
      }
    });

/**
 * Cloud Function to clean up old notification triggers (optional)
 */
exports.cleanupNotificationTriggers = functions.pubsub
    .schedule('every 24 hours')
    .onRun(async (context) => {
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - 7); // Delete triggers older than 7 days

      const query = admin.firestore()
          .collection('notificationTriggers')
          .where('createdAt', '<', cutoff)
          .where('processed', '==', true);

      const snapshot = await query.get();

      if (snapshot.empty) {
        console.log('No old notification triggers to clean up');
        return null;
      }

      const batch = admin.firestore().batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Cleaned up ${snapshot.size} old notification triggers`);

      return null;
    });
