import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/auth/login_screen.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/tenant/tenant_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      debugShowCheckedModeBanner: false,
      title: 'RentPay',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),

      // ✅ IMPORTANT ROUTES
      routes: {
        '/login': (context) => const LoginScreen(),
        '/owner': (context) => const OwnerDashboard(),
        '/tenant': (context) => const TenantDashboard(),
      },

      home: const LoginScreen(),
    );
  }
}
