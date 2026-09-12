import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_warning_banner.dart'; // <-- GIDUNGAG: Ge ayus ang path kung lahi ang location dere

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


  String _buildFakeEmail(String username) {
    final sanitized = username
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return '$sanitized@rentpay.local';
  }

  
  // EMAIL LOGIN
  
  Future<void> resendVerificationEmail() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      showAppWarningBanner(context, "Please enter your username and password");
      return;
    }

    setState(() => isLoading = true);

    try {
      final fakeEmail = _buildFakeEmail(emailController.text.trim());

      await _auth.resendVerificationEmail(
        fakeEmail,
        passwordController.text.trim(),
      );

      if (!mounted) return;

      showAppSuccessBanner(context, "Verification email sent. Please check your inbox.");
    } catch (e) {
      if (!mounted) return;

      showAppWarningBanner(context, friendlyAuthError(e));
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void loginUser() async {
    setState(() => isLoading = true);

    try {
      final fakeEmail = _buildFakeEmail(emailController.text.trim());

      var user = await _auth.login(
        fakeEmail,
        passwordController.text.trim(),
      );

      if (user == null) {
        throw Exception("Login failed");
      }

    
      await NotificationService.initialize();

      // GET USER DATA
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
          .update({"role": role});
        }

      
      // OWNER
      
      if (role == "owner") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OwnerDashboard(),
          ),
        );
      }

      
      // TENANT
      
      else if (role == "tenant") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TenantDashboard(),
          ),
        );
      }

     
      // NO ROLE YET
     
      else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RoleSelectionScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      showAppWarningBanner(context, friendlyAuthError(e));
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  
  // GOOGLE LOGIN

  // login users.
  void googleLogin() async {
    setState(() => isLoading = true);

    try {
      var user = await _auth.signInWithGoogle();

      if (user == null) {
        throw Exception(
          "Google login cancelled",
        );
      }

    
      await NotificationService.initialize();

      // GET USER DATA
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
          .update({"role": role});
        }

      
      // OWNER
      
      if (role == "owner") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OwnerDashboard(),
          ),
        );
      }

      
      // TENANT
      
      else if (role == "tenant") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TenantDashboard(),
          ),
        );
      }

      
      // NO ROLE YET
      
      else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RoleSelectionScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      showAppWarningBanner(context, friendlyAuthError(e));
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  
  // INPUT STYLE
  
  InputDecoration inputStyle(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFFFFBF8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB8B8BE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB8B8BE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6A1A),
                    Color(0xFFFFC5A4),
                    Color(0xFFFFF8F3),
                  ],
                  stops: [0, 0.28, 0.8],
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -80,
            child: Icon(
              Icons.home_work_outlined,
              size: 330,
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    "assets/rentpay_logo.png",
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  "RentPay Login",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                // USERNAME
                TextField(
                  controller: emailController,
                  decoration: inputStyle(
                    "Username",
                    Icons.person,
                  ),
                ),

                const SizedBox(height: 20),

                // PASSWORD
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: inputStyle(
                    "Password",
                    Icons.lock,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            "Login",
                          ),
                  ),
                ),

                const SizedBox(height: 15),

                TextButton(
                  onPressed: isLoading ? null : resendVerificationEmail,
                  child: const Text("Resend Verification Email"),
                ),

                const SizedBox(height: 10),

                // GOOGLE LOGIN
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : googleLogin,
                    icon: const Icon(
                      Icons.login,
                    ),
                    label: const Text(
                      "Continue with Google",
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // REGISTER
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Create Account",
                  ),
                ),
              ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}