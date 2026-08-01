import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Nag-aasikaso ng push notification setup: humihingi ng permission,
/// kumukuha at nagse-save ng FCM device token sa Firestore (para
/// malaman ng Cloud Function kung saan magpapadala ng notification),
/// at nagpapakita ng notification kahit bukas ang app (foreground).
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Tawagin ito pagkatapos ng successful login (email/password man o
  /// Google). Ligtas itong tawagin nang paulit-ulit -- may guard na
  /// para hindi ito mag-initialize ng dalawang beses sa parehong
  /// session.
  static Future<void> initialize() async {
    if (_initialized) {
      // Kahit initialized na, siguraduhin lang na updated ang token
      // (baka nag-login ng ibang account sa parehong device).
      await _saveTokenToFirestore();
      return;
    }

    // Humingi ng permission (required sa Android 13+ at iOS)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // I-setup ang local notifications para sa foreground display
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // I-save ang device token sa Firestore
    await _saveTokenToFirestore();

    // Kada mag-refresh ang token (nangyayari paminsan-minsan),
    // i-update din natin sa Firestore
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(token: newToken);
    });

    // Ipakita ang notification kahit bukas ang app (foreground) --
    // kapag naka-background o nakasara ang app, awtomatiko na itong
    // ipinapakita ng OS mismo, hindi na natin kailangang asikasuhin.
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
      // sakaling mabigo ang pag-save ng token
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    const androidDetails = AndroidNotificationDetails(
      'rentpay_reminders',
      'RentPay Reminders',
      channelDescription: 'Payment due date reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'RentPay',
      message.notification?.body ?? '',
      details,
    );
  }

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
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
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