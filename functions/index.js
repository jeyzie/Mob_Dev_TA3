const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Send push notification to a specific user
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { title, body, userId, data: notificationData } = data;

  if (!title || !body || !userId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    // Get user's FCM token from Firestore (you'll need to store tokens)
    const userDoc = await admin.firestore().collection('users').doc(userId).get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      throw new functions.https.HttpsError('failed-precondition', 'User has no FCM token');
    }

    // Send notification
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: notificationData || {},
    };

    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);

    return { success: true, messageId: response };
  } catch (error) {
    console.error('Error sending notification:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

// Send notification to all users (for broadcasts)
exports.sendBroadcastNotification = functions.https.onCall(async (data, context) => {
  // Only allow admin users to send broadcasts
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { title, body, data: notificationData } = data;

  if (!title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    // Get all users with FCM tokens
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('fcmToken', '!=', null)
      .get();

    const tokens = [];
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    });

    if (tokens.length === 0) {
      return { success: true, message: 'No users with FCM tokens found' };
    }

    // Send multicast message
    const message = {
      tokens: tokens,
      notification: {
        title: title,
        body: body,
      },
      data: notificationData || {},
    };

    const response = await admin.messaging().sendMulticast(message);
    console.log('Successfully sent broadcast:', response);

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount
    };
  } catch (error) {
    console.error('Error sending broadcast:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send broadcast');
  }
});