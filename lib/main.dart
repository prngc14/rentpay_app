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

// ✅ ADDED: global dark mode controller. Kahit saang screen, pwedeng
// i-toggle ang dark mode gamit ang: themeNotifier.value = ThemeMode.dark;
// Awtomatikong mag-a-apply sa buong app dahil naka-listen dito ang
// MaterialApp sa ibaba (ValueListenableBuilder).
final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier(ThemeMode.light);

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'RentPay',
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF172126),
              brightness: Brightness.light,
            ).copyWith(
              surface: const Color(0xFFF6FBFC),
              surfaceContainerLowest: Colors.white,
              primary: const Color(0xFF111518),
              onPrimary: Colors.white,
              secondary: const Color(0xFFE76F3C),
            ),
            scaffoldBackgroundColor: const Color(0xFFF1F8FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFF111518),
              elevation: 0,
              centerTitle: false,
              surfaceTintColor: Colors.transparent,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              margin: EdgeInsets.zero,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                side: BorderSide(color: Color(0x2BFFFFFF)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Color(0xE6FFFFFF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0x1A6E8992)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0x1A6E8992)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF111518), width: 2),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111518),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),

          // ✅ ADDED: dark theme counterpart -- kaparehang color identity
          // (parehong seed/orange accent) pero naka-adjust na para sa
          // madilim na background.
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF172126),
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xFF15191B),
              primary: const Color(0xFFDDE3E6),
              onPrimary: const Color(0xFF111518),
              secondary: const Color(0xFFE76F3C),
            ),
            scaffoldBackgroundColor: const Color(0xFF101416),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFFECF1F3),
              elevation: 0,
              centerTitle: false,
              surfaceTintColor: Colors.transparent,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1B2124),
              elevation: 0,
              margin: EdgeInsets.zero,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1B2124),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFDDE3E6), width: 2),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDDE3E6),
                foregroundColor: const Color(0xFF111518),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
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
      },
    );
  }
}