import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';
import '../screens/tenant/tenant_dashboard.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Firebase handles notification display in the background.
  // The tap action is handled by onMessageOpenedApp or getInitialMessage().
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _listenersRegistered = false;
  static String? _pendingNotificationPayload;

  static const String _contractReminderPayload = 'contract_due_reminder';

  // INITIALIZE NOTIFICATIONS
  static Future<void> initialize() async {
    if (_initialized) {
      await _saveTokenToFirestore();
      return;
    }

    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // CHECK LOCAL NOTIFICATION WHEN APP WAS CLOSED
    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();

    final launchResponse = launchDetails?.notificationResponse;

    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse?.payload != null) {
      _pendingNotificationPayload = launchResponse!.payload;
    }

    // CHECK FCM NOTIFICATION WHEN APP WAS FULLY CLOSED
    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _pendingNotificationPayload = _getNotificationPayload(initialMessage);
    }

    // CREATE ANDROID NOTIFICATION CHANNEL
    const androidChannel = AndroidNotificationChannel(
      'rentpay_reminders',
      'RentPay Reminders',
      description: 'Payment due date reminders',
      importance: Importance.high,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);

    // SAVE FCM TOKEN
    await _saveTokenToFirestore();

    // REGISTER LISTENERS
    if (!_listenersRegistered) {
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(token: newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          final payload = _getNotificationPayload(message);

          if (payload != null) {
            _openContractsIfNeeded(payload);
          }
        },
      );

      _listenersRegistered = true;
    }

    _initialized = true;

    // OPEN PENDING NOTIFICATION AFTER INITIALIZATION
    final pendingPayload = _pendingNotificationPayload;
    _pendingNotificationPayload = null;

    if (pendingPayload != null) {
      _openContractsIfNeeded(pendingPayload);
    }
  }

  // IDENTIFY CONTRACT NOTIFICATIONS
  static String? _getNotificationPayload(
    RemoteMessage message,
  ) {
    final type = message.data['type']?.toString().toLowerCase();

    if (type == null ||
        type.isEmpty ||
        type == 'contract_due_reminder' ||
        type == 'contract' ||
        type.contains('contract')) {
      return _contractReminderPayload;
    }

    return null;
  }

  // SAVE FCM TOKEN TO FIRESTORE
  static Future<void> _saveTokenToFirestore({
    String? token,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final fcmToken = token ?? await _messaging.getToken();

    if (fcmToken == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': fcmToken,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Unable to save notification token: $e');
    }
  }

  // SHOW FIREBASE MESSAGE AS LOCAL NOTIFICATION
  static Future<void> _showLocalNotification(
    RemoteMessage message,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'rentpay_reminders',
      'RentPay Reminders',
      channelDescription: 'Payment due date reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _localNotifications.show(
        id: message.hashCode,
        title: message.notification?.title ?? 'RentPay',
        body: message.notification?.body ?? '',
        notificationDetails: details,
        payload: _contractReminderPayload,
      );
    } catch (error) {
      debugPrint('Local notification error: $error');
    }
  }

  // SHOW CUSTOM LOCAL NOTIFICATION
  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'rentpay_reminders',
      'RentPay Reminders',
      channelDescription: 'Payment due date reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: title,
      body: body,
      notificationDetails: details,
      payload: _contractReminderPayload,
    );
  }

  // NOTIFICATION TAP HANDLER
  static void _onNotificationTapped(
    NotificationResponse response,
  ) {
    _openContractsIfNeeded(response.payload);
  }

  // OPEN CONTRACTS TAB
  // TenantDashboard tab indexes:
  // 0 = Home
  // 1 = Payments
  // 2 = Messages
  // 3 = Contracts
  // 4 = Valid IDs
  static void _openContractsIfNeeded(
    String? payload,
  ) {
    if (payload != _contractReminderPayload) {
      return;
    }

    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      _pendingNotificationPayload = payload;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentNavigator = navigatorKey.currentState;

      if (currentNavigator == null) {
        _pendingNotificationPayload = payload;
        return;
      }

      currentNavigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const TenantDashboard(
            initialTabIndex: 3,
          ),
        ),
        (route) => false,
      );
    });
  }

  // CLEAR TOKEN WHEN USER LOGS OUT
  static Future<void> clearTokenOnLogout() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Unable to clear notification token: $e');
    }
  }
}
