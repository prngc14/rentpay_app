import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/tenant/tenant_dashboard.dart';
import 'screens/owner/boarding_screen.dart';
import 'theme/splash_screen.dart';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global dark mode controller
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// Theme storage key prefix — per-user, not global
const String _kIsDarkKeyPrefix = 'theme_is_dark_';

// Track whose theme is currently loaded into themeNotifier,
// so we know when we need to reload (i.e. user switched accounts)
String? _themeLoadedForUid;

// Build the per-user key. Falls back to a "guest" bucket
// when there's no logged-in user yet (e.g. login screen).
String _themeKeyForUid(String? uid) => '$_kIsDarkKeyPrefix${uid ?? "guest"}';

// Load the saved theme for a specific user
Future<void> _loadThemeForUid(String? uid) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final isDark = prefs.getBool(_themeKeyForUid(uid)) ?? false;

    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    _themeLoadedForUid = uid;
  } catch (e) {
    debugPrint('Theme load error: $e');
  }
}

// Save theme changes under the CURRENT user's key
void _saveThemeWhenChanged() {
  themeNotifier.addListener(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseAuth.instance.currentUser?.uid;

      await prefs.setBool(
        _themeKeyForUid(uid),
        themeNotifier.value == ThemeMode.dark,
      );
    } catch (e) {
      debugPrint('Theme save error: $e');
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Display Flutter errors on screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'ERROR:\n${details.exception}',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  };

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Load theme for whoever is currently signed in (or "guest"
  // if nobody is signed in yet — e.g. app just opened to login screen)
  await _loadThemeForUid(FirebaseAuth.instance.currentUser?.uid);
  _saveThemeWhenChanged();

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (_themeLoadedForUid != user?.uid) {
      _loadThemeForUid(user?.uid);
    }
  });

  runApp(const MyApp());
}

// =====================================================
// MY APP
// =====================================================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _currentMode = ThemeMode.light;

  static const Color _darkBlack = Color(0xFF000000);
  static const Color _darkCard = Color(0xFF1B2124);
  static const Color _darkSheet = Color(0xFF121618);
  static const Color _darkTextMuted = Color(0xFFB8C2C7);

  @override
  void initState() {
    super.initState();

    _currentMode = themeNotifier.value;
    themeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (!mounted) return;

    setState(() {
      _currentMode = themeNotifier.value;
    });
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'RentPay',

      themeMode: _currentMode,

      // =====================================================
      // LIGHT THEME
      // =====================================================

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
            borderRadius: const BorderRadius.all(
              Radius.circular(20),
            ),
            side: const BorderSide(
              color: Color(0x2BFFFFFF),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xE6FFFFFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0x1A6E8992),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0x1A6E8992),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF111518),
              width: 2,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF111518),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),

      // =====================================================
      // DARK THEME
      // =====================================================

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF172126),
          brightness: Brightness.dark,
        ).copyWith(
          surface: _darkBlack,
          surfaceContainerLowest: _darkBlack,
          surfaceContainerLow: const Color(0xFF0A0D0F),
          surfaceContainer: const Color(0xFF111517),
          surfaceContainerHigh: _darkCard,
          surfaceContainerHighest: const Color(0xFF232B2F),
          primary: const Color(0xFFDDE3E6),
          onPrimary: const Color(0xFF111518),
          secondary: const Color(0xFFE76F3C),
          onSurface: Colors.white,
          onSurfaceVariant: _darkTextMuted,
          outline: const Color(0xFF5A6A72),
          outlineVariant: const Color(0xFF2A3439),
        ),

        scaffoldBackgroundColor: _darkBlack,
        canvasColor: _darkBlack,

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),

        dividerTheme: DividerThemeData(
          color: Colors.white.withAlpha(30),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),

        cardTheme: CardThemeData(
          color: _darkCard,
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(20),
            ),
            side: BorderSide(
              color: Colors.white.withAlpha(20),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _darkCard,
          hintStyle: const TextStyle(
            color: _darkTextMuted,
          ),
          labelStyle: const TextStyle(
            color: _darkTextMuted,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.white.withAlpha(26),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.white.withAlpha(26),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFDDE3E6),
              width: 2,
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDDE3E6),
            foregroundColor: const Color(0xFF111518),
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),

        // Bottom navigation
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _darkBlack,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFF1E2A30),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) {
              final selected = states.contains(WidgetState.selected);

              return IconThemeData(
                color: selected ? Colors.white : _darkTextMuted,
              );
            },
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) {
              final selected = states.contains(WidgetState.selected);

              return TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : _darkTextMuted,
              );
            },
          ),
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _darkBlack,
          selectedItemColor: Colors.white,
          unselectedItemColor: _darkTextMuted,
          type: BottomNavigationBarType.fixed,
        ),

        // Dialogs
        dialogTheme: const DialogThemeData(
          backgroundColor: _darkSheet,
          surfaceTintColor: Colors.transparent,
        ),

        // Bottom sheets
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: _darkSheet,
          surfaceTintColor: Colors.transparent,
        ),

        // Popup menus
        popupMenuTheme: const PopupMenuThemeData(
          color: _darkSheet,
          surfaceTintColor: Colors.transparent,
        ),
      ),

      // =====================================================
      // ROUTES
      // =====================================================

      routes: {
        '/login': (context) => const LoginScreen(),
        '/owner': (context) => const OwnerDashboard(),
        '/tenant': (context) => const TenantDashboard(),
        '/boarding': (context) => const BoardingScreen(),
      },

      home: const SplashScreen(),
    );
  }
}

// =====================================================
// AUTH GATE
// =====================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        final user = authSnapshot.data;

        // No logged-in user — make sure theme resets to the
        // "guest" bucket so the next login starts clean
        if (user == null) {
          if (_themeLoadedForUid != null) {
            _loadThemeForUid(null);
          }

          return const LoginScreen();
        }

        // A user is logged in — if it's a DIFFERENT user than
        // whoever's theme is currently loaded, reload the theme
        // for THIS user before showing their dashboard
        if (_themeLoadedForUid != user.uid) {
          return FutureBuilder<void>(
            future: _loadThemeForUid(user.uid),
            builder: (context, themeSnapshot) {
              if (themeSnapshot.connectionState != ConnectionState.done) {
                return const _AuthLoadingScreen();
              }
              return _RoleRouter(uid: user.uid);
            },
          );
        }

        return _RoleRouter(uid: user.uid);
      },
    );
  }
}

// =====================================================
// ROLE ROUTER — decides Owner vs Tenant dashboard
// =====================================================

class _RoleRouter extends StatelessWidget {
  final String uid;

  const _RoleRouter({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        final data = roleSnapshot.data?.data();

        final String role = (data?['role'] ?? '').toString().toLowerCase();

        if (role == 'owner') {
          return const OwnerDashboard();
        }

        if (role == 'tenant') {
          return const TenantDashboard();
        }

        // User has no selected role yet
        return const RoleSelectionScreen();
      },
    );
  }
}

// =====================================================
// AUTH LOADING SCREEN
// =====================================================

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
