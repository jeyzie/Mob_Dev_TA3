import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Request permissions for iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Request exact alarm permission for Android
    if (Platform.isAndroid) {
      await _requestExactAlarmPermission();
    }

    // Create Android notification channels
    await _createNotificationChannels();

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Get and register FCM token
    await _registerFCMToken();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
  }

  Future<void> _requestExactAlarmPermission() async {
    try {
      // Check if exact alarm permission is granted
      final status = await Permission.scheduleExactAlarm.status;
      if (!status.isGranted) {
        // Request the permission
        final result = await Permission.scheduleExactAlarm.request();
        if (result.isGranted) {
          print('Exact alarm permission granted');
        } else if (result.isPermanentlyDenied) {
          print('Exact alarm permission permanently denied');
          // Could show a dialog to guide user to settings
        } else {
          print('Exact alarm permission denied');
        }
      }
    } catch (e) {
      print('Error requesting exact alarm permission: $e');
    }
  }

  Future<bool> _canScheduleExactAlarm() async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.scheduleExactAlarm.status;
      return status.isGranted;
    } catch (e) {
      print('Error checking exact alarm permission: $e');
      return false;
    }
  }

  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel dueChannel = AndroidNotificationChannel(
      'due_notifications',
      'Due Notifications',
      description: 'Notifications for task due dates',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel pushChannel = AndroidNotificationChannel(
      'push_notifications',
      'Push Notifications',
      description: 'Push notifications from Firebase',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(dueChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(pushChannel);
  }

  Future<void> _registerFCMToken() async {
    try {
      final token = await getFCMToken();
      if (token != null) {
        print('FCM Token: $token');
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    print('FCM Token refreshed: $token');
    await _saveTokenToFirestore(token);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('FCM token saved to Firestore');
      }
    } catch (e) {
      print('Error saving FCM token to Firestore: $e');
    }
  }

  Future<void> scheduleDueNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      // Ensure the scheduled date is in the future
      final now = DateTime.now();
      if (scheduledDate.isBefore(now)) {
        print('Warning: Scheduled date is in the past, showing notification immediately instead');
        await showLocalNotification(
          title: title,
          body: '$body (Due now)',
        );
        return;
      }

      final scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'due_notifications',
        'Due Notifications',
        channelDescription: 'Notifications for task due dates',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        fullScreenIntent: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        sound: 'default.wav',
        threadIdentifier: 'due_notification_thread',
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Check if we can schedule exact alarms
      final canScheduleExact = await _canScheduleExactAlarm();

      if (canScheduleExact) {
        // Use exact scheduling
        await _localNotifications.zonedSchedule(
          id,
          title,
          body,
          scheduledTZDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
        print('Scheduled exact notification for task $id at $scheduledDate (${scheduledTZDate})');
      } else {
        // Fallback to inexact scheduling (which is more reliable when exact permissions aren't available)
        await _localNotifications.zonedSchedule(
          id,
          title,
          body,
          scheduledTZDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
        print('Scheduled inexact notification for task $id at $scheduledDate (exact alarms not permitted, falling back to inexact)');
      }
    } catch (e) {
      print('Error scheduling notification: $e');
      // If scheduling fails, try to show the notification immediately as a fallback
      try {
        await showLocalNotification(
          title: title,
          body: '$body (Scheduling failed, showing now)',
        );
      } catch (fallbackError) {
        print('Fallback notification also failed: $fallbackError');
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
      print('Cancelled notification $id');
    } catch (e) {
      print('Error cancelling notification $id: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      print('Cancelled all notifications');
    } catch (e) {
      print('Error cancelling all notifications: $e');
    }
  }

  // Reschedule all pending notifications (useful after app restart or on boot)
  Future<void> reschedulePendingNotifications(List<Map<String, dynamic>> pendingNotifications) async {
    try {
      print('Rescheduling ${pendingNotifications.length} pending notifications...');
      for (final notification in pendingNotifications) {
        try {
          await scheduleDueNotification(
            id: notification['id'] as int,
            title: notification['title'] as String,
            body: notification['body'] as String,
            scheduledDate: notification['scheduledDate'] as DateTime,
          );
        } catch (e) {
          print('Error rescheduling notification ${notification['id']}: $e');
        }
      }
    } catch (e) {
      print('Error rescheduling pending notifications: $e');
    }
  }

  // Send push notification to current user
  Future<bool> sendPushNotificationToCurrentUser({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user');
        return false;
      }

      final callable = FirebaseFunctions.instance.httpsCallable('sendPushNotification');
      final result = await callable.call({
        'title': title,
        'body': body,
        'userId': user.uid,
        'data': data,
      });

      print('Push notification sent: ${result.data}');
      return true;
    } catch (e) {
      print('Error sending push notification: $e');
      return false;
    }
  }

  // Test method to send a sample push notification
  Future<void> testPushNotification() async {
    await sendPushNotificationToCurrentUser(
      title: 'Test Notification',
      body: 'This is a test push notification from Task Manager!',
      data: {'type': 'test', 'timestamp': DateTime.now().toIso8601String()},
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to specific task
    print('Notification tapped: ${response.payload}');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    showLocalNotification(
      title: message.notification?.title ?? 'Task Manager',
      body: message.notification?.body ?? 'You have a new notification',
      payload: message.data.toString(),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // Handle when user taps notification and app opens
    print('Message opened app: ${message.data}');
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'push_notifications',
      'Push Notifications',
      channelDescription: 'Push notifications from Firebase',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title,
      body,
      details,
      payload: payload,
    );
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');

  // Initialize local notifications for background handling
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings settings = InitializationSettings(android: androidSettings);

  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  await localNotifications.initialize(settings);

  // Show notification for background message
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'push_notifications',
    'Push Notifications',
    channelDescription: 'Push notifications from Firebase',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? 'Task Manager',
    message.notification?.body ?? 'You have a new notification',
    details,
    payload: message.data.toString(),
  );
}