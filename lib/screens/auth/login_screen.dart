import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_warning_banner.dart';

import '../owner/owner_dashboard.dart';
import '../tenant/tenant_dashboard.dart';

import 'register_screen.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService _auth = AuthService();

  bool isLoading = false;
  bool _obscurePassword = true;

  static const Color darkBlue = Color(0xFF173F59);

  String _buildFakeEmail(String username) {
    final sanitized =
        username.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');

    return '$sanitized@rentpay.local';
  }

  // ============================================================
  // EMAIL LOGIN
  // ============================================================

  Future<void> loginUser() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      showAppWarningBanner(
        context,
        "Please enter your username and password",
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final fakeEmail = _buildFakeEmail(
        emailController.text.trim(),
      );

      final user = await _auth.login(
        fakeEmail,
        passwordController.text.trim(),
      );

      if (user == null) {
        throw Exception("Login failed");
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      debugPrint('Firebase UID: ${currentUser?.uid}');
      debugPrint('Firebase Email: ${currentUser?.email}');

      await NotificationService.initialize();

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final data = doc.data();

      String role = data?["role"] ?? "";

      if (role.isEmpty &&
          (data?["ownerId"]?.toString().isNotEmpty == true ||
              data?["room"]?.toString().isNotEmpty == true ||
              data?["connected"] == true)) {
        role = "tenant";

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .update({
          "role": role,
        });
      }

      if (!mounted) return;

      if (role == "owner") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OwnerDashboard(),
          ),
        );
      } else if (role == "tenant") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TenantDashboard(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RoleSelectionScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      showAppWarningBanner(
        context,
        friendlyAuthError(e),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<void> googleLogin() async {
    setState(() => isLoading = true);

    try {
      final user = await _auth.signInWithGoogle();

      if (user == null) {
        throw Exception("Google login cancelled");
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      debugPrint('Google Firebase UID: ${currentUser?.uid}');
      debugPrint('Google Firebase Email: ${currentUser?.email}');

      await NotificationService.initialize();

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final data = doc.data();

      String role = data?["role"] ?? "";

      if (role.isEmpty &&
          (data?["ownerId"]?.toString().isNotEmpty == true ||
              data?["room"]?.toString().isNotEmpty == true ||
              data?["connected"] == true)) {
        role = "tenant";

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .update({
          "role": role,
        });
      }

      if (!mounted) return;

      if (role == "owner") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OwnerDashboard(),
          ),
        );
      } else if (role == "tenant") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TenantDashboard(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RoleSelectionScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      showAppWarningBanner(
        context,
        friendlyAuthError(e),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // ============================================================
  // INPUT STYLE
  // ============================================================

  InputDecoration inputStyle(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF4B5358),
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: darkBlue,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF4B5358),
        size: 20,
      ),
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFB8B8BE),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFB8B8BE),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: darkBlue,
          width: 2,
        ),
      ),
    );
  }

  // ============================================================
  // FRIENDLY AUTH ERROR
  // ============================================================

  String friendlyAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case "user-not-found":
          return "No account found for that username.";

        case "wrong-password":
          return "Incorrect password.";

        case "invalid-email":
          return "Invalid username.";

        case "invalid-credential":
          return "Invalid login credentials.";

        case "user-disabled":
          return "This account has been disabled.";

        case "too-many-requests":
          return "Too many attempts. Please try again later.";

        case "network-request-failed":
          return "Please check your internet connection.";

        default:
          return e.message ?? "Login failed. Please try again.";
      }
    }

    return e.toString().replaceFirst(
          "Exception: ",
          "",
        );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 320,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // RENTPAY LOGIN TITLE
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "Rentpay",
                            style: GoogleFonts.lobster(
                              fontSize: 80,
                              color: const Color.fromARGB(255, 7, 7, 7),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // USERNAME
                    TextField(
                      controller: emailController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      cursorColor: Colors.black,
                      decoration: inputStyle(
                        "Username",
                        Icons.person,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // PASSWORD
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      cursorColor: Colors.black,
                      onSubmitted: (_) {
                        if (!isLoading) {
                          loginUser();
                        }
                      },
                      decoration: inputStyle(
                        "Password",
                        Icons.lock,
                      ).copyWith(
                        suffixIcon: IconButton(
                          splashRadius: 20,
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF4B5358),
                            size: 19,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // LOGIN BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : loginUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 7, 7, 7),
                          disabledBackgroundColor: darkBlue.withOpacity(0.55),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Center(
                                child: Text(
                                  "Login",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // GOOGLE LOGIN
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: isLoading ? null : googleLogin,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          side: const BorderSide(
                            color: Color(0xFF858585),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google_logo.png',
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  color: Color(0xFF202124),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // "or" DIVIDER between Google button and Create Account
                    const Text(
                      "or",
                      style: TextStyle(
                        color: Color(0xFF858585),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // CREATE ACCOUNT
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: darkBlue,
                      ),
                      child: const Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
