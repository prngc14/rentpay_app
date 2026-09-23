import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../widgets/app_warning_banner.dart';

import '../owner/owner_dashboard.dart';
import '../tenant/tenant_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();

  bool isLoading = false;
  String role = "tenant";
  bool _obscurePassword = true;

  static const Color accentColor = Colors.black;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String generateOwnerCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _buildFakeEmail(String username) {
    final sanitized =
        username.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return '$sanitized@rentpay.local';
  }

  String? _validatePassword(String password) {
    if (password.length < 8) {
      return "Password must be at least 8 characters long";
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);

    if (!hasLetter || !hasNumber) {
      return "Password must contain both letters and numbers";
    }
    return null;
  }

  // ============================================================
  // REGISTER USER
  // ============================================================

  Future<void> registerUser() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      showAppWarningBanner(context, "Please fill all required fields");
      return;
    }

    final passwordError = _validatePassword(passwordController.text.trim());
    if (passwordError != null) {
      showAppWarningBanner(context, passwordError);
      return;
    }

    final username = emailController.text.trim();
    final fakeEmail = _buildFakeEmail(username);

    if (fakeEmail.startsWith('@')) {
      showAppWarningBanner(
        context,
        "Please enter a valid username (letters, numbers, ., _, or -)",
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      var user = await _auth.register(
        fakeEmail,
        passwordController.text.trim(),
      );

      if (user == null) {
        throw Exception("Registration failed");
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      debugPrint(
        'REGISTERED USER UID: ${currentUser?.uid}',
      );

      debugPrint(
        'REGISTERED USER EMAIL: ${currentUser?.email}',
      );

      if (currentUser == null) {
        throw Exception(
          "Firebase authentication session is missing.",
        );
      }

      if (role == "owner") {
        String ownerCode = generateOwnerCode();

        await _firestore.createUser(UserModel(
          uid: user.uid,
          name: nameController.text.trim(),
          email: fakeEmail,
          role: "owner",
          room: "",
          ownerCode: ownerCode,
          ownerId: "",
          approved: true,
        ));
      } else {
        await _firestore.createUser(UserModel(
          uid: user.uid,
          name: nameController.text.trim(),
          email: fakeEmail,
          role: "tenant",
          room: "",
          ownerCode: "",
          ownerId: "",
          approved: false,
        ));
      }

      if (!mounted) return;

      showAppSuccessBanner(
        context,
        "Account created successfully!",
      );

      if (role == "owner") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OwnerDashboard(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TenantDashboard(),
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

  // ============================================================
  // INPUT STYLE
  // ============================================================

  InputDecoration inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF4B5358),
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: accentColor,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB8B8BE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB8B8BE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentColor, width: 2),
      ),
    );
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
                    // TITLE
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // NAME
                    TextField(
                      controller: nameController,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      cursorColor: Colors.black,
                      decoration: inputStyle("Name"),
                    ),

                    const SizedBox(height: 10),

                    // USERNAME
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      cursorColor: Colors.black,
                      decoration: inputStyle("Username"),
                    ),

                    const SizedBox(height: 10),

                    // PASSWORD
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      cursorColor: Colors.black,
                      decoration: inputStyle("Password").copyWith(
                        helperText:
                            "Must be 8+ characters with letters and numbers",
                        helperMaxLines: 2,
                        helperStyle: const TextStyle(fontSize: 11),
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

                    const SizedBox(height: 14),

                    // ROLE
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: inputStyle("Role"),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "tenant",
                          child: Text("Tenant"),
                        ),
                        DropdownMenuItem(
                          value: "owner",
                          child: Text("Owner"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => role = v);
                        }
                      },
                    ),

                    const SizedBox(height: 18),

                    // REGISTER BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          disabledBackgroundColor:
                              accentColor.withOpacity(0.55),
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
                                  "Register",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // BACK TO LOGIN
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: accentColor,
                        ),
                        child: const Text(
                          "Already have an account? Login",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
