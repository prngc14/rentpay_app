import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import 'register_screen.dart';
import '../owner/owner_dashboard.dart';
import '../tenant/tenant_dashboard.dart';

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
  bool rememberMe = false;

  void loginUser() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email & password")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      var user = await _auth.login(email, password);

      if (!mounted) return;

      if (user != null) {
        var doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (!mounted) return;

        String role = doc["role"];

        if (role == "owner") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OwnerDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TenantDashboard()),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$e")),
      );
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  void forgotPassword() async {
    if (emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your email first")),
      );
      return;
    }

    await FirebaseAuth.instance
        .sendPasswordResetEmail(email: emailController.text.trim());

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Password reset email sent")),
    );
  }

  InputDecoration inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const UnderlineInputBorder(),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                )
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.home, size: 70, color: Colors.deepOrange),
                const SizedBox(height: 10),
                const Text(
                  "RentPay",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: emailController,
                  decoration: inputStyle("Email", Icons.email),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: inputStyle("Password", Icons.lock),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      activeColor: Colors.deepOrange,
                      onChanged: (v) {
                        setState(() {
                          rememberMe = v ?? false;
                        });
                      },
                    ),
                    const Text("Remember Me"),
                    const Spacer(),
                    TextButton(
                      onPressed: forgotPassword,
                      child: const Text("Forgot Password?"),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Login",
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text("Create Account"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
