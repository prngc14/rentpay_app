import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';
import '../screens/tenant/tenant_dashboard.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _listenersRegistered = false;
  static String? _pendingNotificationPayload;

  static const String _contractReminderPayload = "contract_due_reminder";

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

    const androidSettings =
        AndroidInitializationSettings("@mipmap/ic_launcher");
    final initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse?.payload != null) {
      _pendingNotificationPayload = launchResponse!.payload;
    }

    await _saveTokenToFirestore();

    if (!_listenersRegistered) {
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(token: newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _openContractsIfNeeded(message.data["type"] ??
            (message.notification != null ? _contractReminderPayload : null));
      });

      _listenersRegistered = true;
    }

    _initialized = true;

    final pendingPayload = _pendingNotificationPayload;
    _pendingNotificationPayload = null;
    if (pendingPayload != null) {
      _openContractsIfNeeded(pendingPayload);
    }
  }

  static Future<void> _saveTokenToFirestore({String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fcmToken = token ?? await _messaging.getToken();
    if (fcmToken == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({"fcmToken": fcmToken});
    } catch (e) {
      debugPrint("Unable to save notification token: $e");
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    const androidDetails = AndroidNotificationDetails(
      "rentpay_reminders",
      "RentPay Reminders",
      channelDescription: "Payment due date reminders",
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    _localNotifications
        .show(
      message.hashCode,
      message.notification?.title ?? "RentPay",
      message.notification?.body ?? "",
      details,
      payload: _contractReminderPayload,
    )
        .catchError((error) {
      debugPrint("Local notification error: $error");
    });
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      "rentpay_reminders",
      "RentPay Reminders",
      channelDescription: "Payment due date reminders",
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: _contractReminderPayload,
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    _openContractsIfNeeded(response.payload);
  }

  static void _openContractsIfNeeded(String? payload) {
    if (payload != _contractReminderPayload) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      _pendingNotificationPayload = payload;
      return;
    }

    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const TenantDashboard(initialTabIndex: 2),
      ),
      (route) => false,
    );
  }

  static Future<void> clearTokenOnLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({"fcmToken": FieldValue.delete()});
    } catch (e) {
      // ok lang i-ignore kung mabigo ahh sad
    }
  }
}
