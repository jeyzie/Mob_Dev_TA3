# Push Notifications Setup Guide

## 🚀 Complete Setup for Push Notifications

### Prerequisites
1. **Firebase Project**: Make sure you have a Firebase project set up
2. **Firebase CLI**: Install Firebase CLI (`npm install -g firebase-tools`)
3. **Flutter App**: Your app should be configured with Firebase

### Step 1: Deploy Firebase Configuration

```bash
# Login to Firebase
firebase login

# Initialize/Configure your project (if not done already)
firebase use --add
# Select your Firebase project

# Deploy Firestore rules and Cloud Functions
firebase deploy
```

### Step 2: Test Push Notifications

#### Option A: Firebase Console (Easiest)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → Cloud Messaging
3. Click "Send your first message"
4. Fill in:
   - **Notification title**: "Test Notification"
   - **Notification text**: "Hello from Firebase!"
   - **Target**: Select "User segment" → "All users" or specific users
5. Click "Send test message"

#### Option B: Using the App (Programmatic)
```dart
// In your Flutter app, call this method:
await NotificationService().testPushNotification();
```

### Step 3: Verify Setup

1. **Check FCM Token**: Look in your app logs for "FCM Token:" messages
2. **Check Firestore**: Verify tokens are saved in `/users/{userId}` documents
3. **Test Notifications**: Send a test notification and verify it appears

## 📱 Notification Types

### 1. Local Notifications (Due Date Reminders)
- Scheduled automatically when tasks have due dates
- Work offline
- Appear at exact due times

### 2. Push Notifications (Server-sent)
- Sent from Firebase Console or Cloud Functions
- Work even when app is closed
- Can include custom data

## 🔧 Cloud Functions

The included Cloud Functions allow you to:

### Send to Specific User
```javascript
// Call from client app
const result = await functions().httpsCallable('sendPushNotification')({
  title: 'Task Reminder',
  body: 'Don\'t forget your important task!',
  userId: 'user-uid-here',
  data: { taskId: '123' }
});
```

### Send Broadcast (Admin)
```javascript
// Call from client app (admin users only)
const result = await functions().httpsCallable('sendBroadcastNotification')({
  title: 'App Update',
  body: 'New features available!',
  data: { type: 'update' }
});
```

## 🐛 Troubleshooting

### Common Issues:

1. **"FCM Token: null"**
   - Check Firebase configuration
   - Ensure Google Services files are correct

2. **Notifications not appearing**
   - Check device notification permissions
   - Verify FCM token is saved in Firestore
   - Check Firebase Console for delivery status

3. **Cloud Functions not working**
   - Ensure functions are deployed: `firebase deploy --only functions`
   - Check Firebase Console → Functions for errors

### Debug Steps:

1. **Check Logs**: Look for FCM token messages in console
2. **Verify Permissions**: Ensure notification permissions are granted
3. **Test Locally**: Use Firebase emulators for testing
4. **Check Firebase Console**: Monitor message delivery

## 📋 Required Permissions

### Android (android/app/src/main/AndroidManifest.xml)
- ✅ INTERNET
- ✅ RECEIVE_BOOT_COMPLETED
- ✅ VIBRATE
- ✅ WAKE_LOCK
- ✅ POST_NOTIFICATIONS (Android 13+)

### iOS (ios/Runner/Info.plist)
- ✅ Background fetch
- ✅ Remote notifications
- ✅ Firebase App Delegate Proxy

## 🎯 Next Steps

1. **Customize Notifications**: Modify notification content and styling
2. **Add Actions**: Implement notification tap handling for deep linking
3. **Analytics**: Track notification engagement
4. **Advanced Targeting**: Use Firebase Cloud Messaging topics for user groups

## 📞 Support

If push notifications still don't work:

1. Check all prerequisites are met
2. Verify Firebase project configuration
3. Test with Firebase Console first
4. Check device/emulator notification settings
5. Review console logs for error messages