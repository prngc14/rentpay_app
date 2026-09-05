import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';
import '../screens/tenant/tenant_contracts_screen.dart';

/// Nag-aasikaso ng push notification setup: humihingi ng permission,
/// kumukuha at nagse-save ng FCM device token sa Firestore (para
/// malaman ng Cloud Function kung saan magpapadala ng notification),
/// at nagpapakita ng notification kahit bukas ang app (foreground).
/// Kapag tinapik ang notification, dinadala ang tenant sa Contracts
/// screen, dahil doon nakabase ang RentPay Reminder notification.
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Payload na ilalagay sa lahat ng RentPay Reminder notification,
  /// para malaman ng tap handler kung saan dapat mag-navigate.
  static const String _contractReminderPayload = "contract_due_reminder";

  /// Tawagin ito pagkatapos ng successful login (email/password man o
  /// Google). Ligtas itong tawagin nang paulit-ulit - may guard na
  /// para hindi ito mag-initialize ng dalawang beses sa parehong
  /// session.
  static Future<void> initialize() async {
    if (_initialized) {
      await _saveTokenToFirestore();
      return;
    }

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidSettings =
        AndroidInitializationSettings("@mipmap/ic_launcher");
    final initSettings = InitializationSettings(android: androidSettings);

    // ✅ ADDED: onDidReceiveNotificationResponse -- ito ang tumatawag
    // pag tinapik ng user ang isang notification (foreground o
    // background, habang bukas pa rin ang app process).
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _saveTokenToFirestore();

    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(token: newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    _initialized = true;
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
      // Hindi natin ito ginagawang blocker sa login flow kung
      // sakaling mabigo ka pag move on nlang uwu
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

    _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? "RentPay",
      message.notification?.body ?? "",
      details,
      payload: _contractReminderPayload,
    );
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
      // ✅ ADDED: payload para malaman ng tap handler na ito ay
      // contract due reminder, at doon dapat mag-navigate.
      payload: _contractReminderPayload,
    );
  }

  /// Tinatawag kapag tinapik ng user ang notification. Dinadala ang
  /// user sa Contracts screen sa STANDALONE mode (may sariling
  /// AppBar), dahil direktang naka-push ito gamit ang global navigatorKey
  /// (static context, walang sariling BuildContext mula sa kasalukuyang
  /// open screen) -- kaya wala itong Dashboard shell (AppBar/BottomNav)
  /// sa paligid.
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != _contractReminderPayload) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => const TenantContractsScreen(standalone: true),
      ),
    );
  }

  /// Tawagin ito sa logout, para hindi na makatanggap ng notification
  /// ang device na ito para sa lumang account.
  static Future<void> clearTokenOnLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({"fcmToken": FieldValue.delete()});
    } catch (e) {
      // ok lang i-ignore kung mabigo
    }
  }
}