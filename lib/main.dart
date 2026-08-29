import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/auth/login_screen.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/tenant/tenant_dashboard.dart';
import 'screens/owner/boarding_screen.dart'; // ✅ ADD THIS

// ✅ ADDED: global navigator key para makapag-navigate mula sa
// NotificationService (static class na walang sariling
// BuildContext) tuwing tinapik ng user ang isang notification.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ipakita ang error sa screen sa halip na black/blank screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'ERROR:\n${details.exception}',
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ),
      ),
    );
  };

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ ADDED
      debugShowCheckedModeBanner: false,
      title: 'RentPay',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),

      //ROUTES (FIXED)
      routes: {
        '/login': (context) => const LoginScreen(),
        '/owner': (context) => const OwnerDashboard(),
        '/tenant': (context) => const TenantDashboard(),
        '/boarding': (context) => const BoardingScreen(),
      },

      // START SCREEN
      home: const LoginScreen(),
    );
  }
}