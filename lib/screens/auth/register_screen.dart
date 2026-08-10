import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../widgets/app_warning_banner.dart'; // <-- IDAGDAG: ayusin ang path kung iba ang location mo

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

  /// Kinukuha ang username na na-type ng user (hal. "andrea06") at
  /// ginagawang parang email format ito sa likod-likod (hal.
  /// "andrea06@rentpay.local"), dahil kailangan talaga ng Firebase
  /// Auth ng valid email format kahit hindi ito makikita ng user.
  ///
  /// Tinatanggal natin muna ang mga karakter na hindi pwede sa email
  /// (spaces, special symbols) para laging valid ang resulta.
  String _buildFakeEmail(String username) {
    final sanitized = username
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return '$sanitized@rentpay.local';
  }

  /// Kinu-check kung valid ang password.
  /// Dapat may kahit isang letra AT isang numero, at at least 8 characters.
  /// Nire-return ang error message kung invalid, o null kung valid na.
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return "Password must be at least 8 characters long";
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);

    if (!hasLetter || !hasNumber) {
      return "Password must contain both letters and numbers (e.g. gwapo1234)";
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

    // ✅ CHECK PASSWORD STRENGTH BEFORE PROCEEDING
    final passwordError = _validatePassword(passwordController.text.trim());
    if (passwordError != null) {
      showAppWarningBanner(context, passwordError);
      return;
    }

    final username = emailController.text.trim();
    final fakeEmail = _buildFakeEmail(username);

    // I-check kung may nabuong valid na username matapos i-sanitize
    // (hal. kung puro special characters lang ang na-type, magiging
    // blangko ito).
    if (fakeEmail.startsWith('@')) {
      showAppWarningBanner(
        context,
        "Please enter a valid username (letters, numbers, ., _, or -)",
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // ✅ STEP 1: REGISTER USER
      var user = await _auth.register(
        fakeEmail,
        passwordController.text.trim(),
      );

      if (user == null) throw Exception("Registration failed");

      // ✅ STEP 2: SAVE USER DATA (ONLY ONE WRITE)
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
      labelStyle: const TextStyle(color: Colors.grey),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.deepOrange, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.home,
                          size: 70, color: Colors.deepOrange),
                      const SizedBox(height: 10),
                      const Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 26,
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
    );
  }
}