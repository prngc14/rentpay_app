import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';

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

  // ===============================
  // EMAIL LOGIN
  // ===============================
  void loginUser() async {
    setState(() => isLoading = true);

    try {
      var user = await _auth.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user == null) {
        throw Exception("Login failed");
      }

      // CHECK USER DOCUMENT
      await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      // GO TO ROLE SELECTION
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    }

    setState(() => isLoading = false);
  }

  // ===============================
  // GOOGLE LOGIN
  // ===============================
  void googleLogin() async {
    setState(() => isLoading = true);

    try {
      var user = await _auth.signInWithGoogle();

      if (user == null) {
        throw Exception(
          "Google login cancelled",
        );
      }

      // CHECK USER DOCUMENT
      await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      // GO TO ROLE SELECTION
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    }

    setState(() => isLoading = false);
  }

  // ===============================
  // INPUT STYLE
  // ===============================
  InputDecoration inputStyle(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
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
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.home,
                  size: 70,
                  color: Colors.deepOrange,
                ),

                const SizedBox(height: 10),

                const Text(
                  "RentPay Login",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                // EMAIL
                TextField(
                  controller: emailController,
                  decoration: inputStyle(
                    "Email",
                    Icons.email,
                  ),
                ),

                const SizedBox(height: 20),

                // PASSWORD
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: inputStyle(
                    "Password",
                    Icons.lock,
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          15,
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          15,
                        ),
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
    );
  }
}
