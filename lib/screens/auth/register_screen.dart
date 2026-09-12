import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../widgets/app_warning_banner.dart'; 

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
    final sanitized = username
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');
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

  Future<void> registerUser() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      showAppWarningBanner(context, "Please fill all required fields");
      return;
    }

    // CHECK PASSWORD STRENGTH BEFORE PROCEEDING
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
      // STEP 1: REGISTER USER
      var user = await _auth.register(
        fakeEmail,
        passwordController.text.trim(),
      );

      if (user == null) throw Exception("Registration failed");

    
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

      showAppSuccessBanner(context, "Registered Successfully. You can now log in.");

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;

      showAppWarningBanner(context, friendlyAuthError(e));
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  InputDecoration inputStyle(String label) {
    return InputDecoration(
      labelText: label,
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6A1A), Color(0xFFFFC5A4), Color(0xFFFFF8F3)],
            stops: [0, 0.28, 0.8],
          ),
        ),
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.97),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
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
                        "Create Account",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: nameController,
                  decoration: inputStyle("Name"),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.text,
                  decoration: inputStyle("Username"),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: inputStyle("Password").copyWith(
                    helperText:
                        "Must be 8+ characters with letters and numbers",
                    helperMaxLines: 2,
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
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: inputStyle("Role"),
                  items: const [
                    DropdownMenuItem(value: "tenant", child: Text("Tenant")),
                    DropdownMenuItem(value: "owner", child: Text("Owner")),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => role = v);
                    }
                  },
                ),
                const SizedBox(height: 35),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Register"),
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Already have an account? Login"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}