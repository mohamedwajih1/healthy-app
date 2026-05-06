import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

// Handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  debugPrint(
    '🔔 Background message received: ${message.messageId}',
  );
  debugPrint(
    'Title: ${message.notification?.title}',
  );
  debugPrint(
    'Body: ${message.notification?.body}',
  );
  debugPrint('Data: ${message.data}');
}

class FCMService {
  static final FCMService _instance =
      FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin
  _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> _saveTokenToFirestore(
    String token,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
          'fcmToken': token,
          'fcmTokenUpdatedAt':
              FieldValue.serverTimestamp(),
        });
  }

  Future<void> initialize() async {
    try {
      // Request permission for iOS
      NotificationSettings settings =
          await _firebaseMessaging
              .requestPermission(
                alert: true,
                announcement: false,
                badge: true,
                carPlay: false,
                criticalAlert: false,
                provisional: false,
                sound: true,
              );

      debugPrint(
        '🔔 Notification permission status: ${settings.authorizationStatus}',
      );

      // Get FCM token
      _fcmToken = await _firebaseMessaging
          .getToken();
      debugPrint('🔑 FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _saveTokenToFirestore(_fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((
        token,
      ) {
        _fcmToken = token;
        debugPrint(
          '🔄 FCM Token refreshed: $token',
        );
        _saveTokenToFirestore(token);
      });

      // Initialize local notifications for foreground messages
      const AndroidInitializationSettings
      initializationSettingsAndroid =
          AndroidInitializationSettings(
            '@mipmap/ic_launcher',
          );

      const DarwinInitializationSettings
      initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings
      initializationSettings =
          InitializationSettings(
            android:
                initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:
            _onNotificationTapped,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      // Handle message when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(
        _handleMessageOpenedApp,
      );

      // Handle message when app is terminated and opened from notification
      final initialMessage =
          await _firebaseMessaging
              .getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      debugPrint(
        '✅ FCM Service initialized successfully',
      );
    } catch (e) {
      debugPrint(
        '❌ Error initializing FCM Service: $e',
      );
      rethrow;
    }
  }

  void _handleForegroundMessage(
    RemoteMessage message,
  ) {
    debugPrint(
      '🔔 Foreground message received: ${message.messageId}',
    );

    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  void _handleMessageOpenedApp(
    RemoteMessage message,
  ) {
    debugPrint(
      '📱 Message opened app: ${message.messageId}',
    );

    // Navigate based on message data
    _navigateToScreen(message.data);
  }

  Future<void> _showLocalNotification(
    RemoteMessage message,
  ) async {
    const AndroidNotificationDetails
    androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'healthy_app_notifications',
          'Healthy App Notifications',
          channelDescription:
              'Notifications from Healthy App',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF6366F1),
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails
    iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails
    platformChannelSpecifics =
        NotificationDetails(
          android:
              androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics,
        );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ??
          'Healthy App',
      message.notification?.body ??
          'You have a new notification',
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  void _onNotificationTapped(
    NotificationResponse response,
  ) {
    debugPrint(
      '📱 Local notification tapped: ${response.payload}',
    );

    if (response.payload != null) {
      try {
        final decoded = jsonDecode(
          response.payload!,
        );
        if (decoded is Map<String, dynamic>) {
          _navigateToScreen(decoded);
        }
      } catch (e) {
        debugPrint(
          '❌ Error parsing notification payload: $e',
        );
      }
    }
  }

  void _navigateToScreen(
    Map<String, dynamic> data,
  ) {
    final screen = data['screen']?.toString();

    if (screen != null &&
        navigatorKey.currentContext != null) {
      switch (screen) {
        case 'habits':
          navigatorKey.currentState?.pushNamed(
            '/habits',
          );
          break;
        case 'stats':
          navigatorKey.currentState?.pushNamed(
            '/stats',
          );
          break;
        case 'ai_insights':
          navigatorKey.currentState?.pushNamed(
            '/ai_insights',
          );
          break;
        case 'chat':
          navigatorKey.currentState?.pushNamed(
            '/chat',
          );
          break;
        default:
          // Navigate to home if no specific screen
          navigatorKey.currentState?.pushNamed(
            '/home',
          );
          break;
      }
    }
  }

  // Subscribe to topic for targeted notifications
  Future<void> subscribeToTopic(
    String topic,
  ) async {
    try {
      await _firebaseMessaging.subscribeToTopic(
        topic,
      );
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint(
        '❌ Error subscribing to topic $topic: $e',
      );
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(
    String topic,
  ) async {
    try {
      await _firebaseMessaging
          .unsubscribeFromTopic(topic);
      debugPrint(
        '✅ Unsubscribed from topic: $topic',
      );
    } catch (e) {
      debugPrint(
        '❌ Error unsubscribing from topic $topic: $e',
      );
    }
  }

  // Test notification (for development)
  Future<void> sendTestNotification() async {
    if (kDebugMode) {
      debugPrint(
        '🧪 Sending test notification...',
      );

      // Simulate a test notification
      const AndroidNotificationDetails
      androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'test_channel',
            'Test Notifications',
            channelDescription:
                'Channel for test notifications',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          );

      const DarwinNotificationDetails
      iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails
      platformChannelSpecifics =
          NotificationDetails(
            android:
                androidPlatformChannelSpecifics,
            iOS: iOSPlatformChannelSpecifics,
          );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch %
            100000,
        '🧪 Test Notification',
        'This is a test notification from Healthy App',
        platformChannelSpecifics,
      );
    }
  }
}
