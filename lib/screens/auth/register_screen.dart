import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final roomController = TextEditingController();
  final ownerCodeController = TextEditingController();

  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();

  bool isLoading = false;
  String role = "tenant";

  String generateOwnerCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> registerUser() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) return;

    setState(() => isLoading = true);

    try {
      var user = await _auth.register(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      String ownerCode = "";
      String ownerId = "";

      if (role == "owner") {
        ownerCode = generateOwnerCode();
      } else {
        var ownerDoc =
            await _firestore.getOwnerByCode(ownerCodeController.text.trim());
        ownerId = ownerDoc!.id;
      }

      await _firestore.createUser(UserModel(
        uid: user!.uid,
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        role: role,
        room: role == "tenant" ? roomController.text.trim() : "",
        ownerCode:
            role == "owner" ? ownerCode : ownerCodeController.text.trim(),
        ownerId: ownerId,
        approved: role == "tenant" ? false : true,
      ));

      Navigator.pop(context);
    } catch (e) {}

    setState(() => isLoading = false);
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
                // 🏠 LOGO + TITLE
                Center(
                  child: Column(
                    children: const [
                      Icon(Icons.home, size: 70, color: Colors.deepOrange),
                      SizedBox(height: 10),
                      Text(
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

                // 📝 INPUTS
                TextField(
                  controller: nameController,
                  decoration: inputStyle("Name"),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: emailController,
                  decoration: inputStyle("Email"),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: inputStyle("Password"),
                ),

                const SizedBox(height: 25),

                // 🔽 DROPDOWN (IMPROVED)
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: inputStyle("Role"),
                  style: const TextStyle(color: Colors.black),
                  items: const [
                    DropdownMenuItem(value: "tenant", child: Text("Tenant")),
                    DropdownMenuItem(value: "owner", child: Text("Owner")),
                  ],
                  onChanged: (v) => setState(() => role = v!),
                ),

                if (role == "tenant") ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: ownerCodeController,
                    decoration: inputStyle("Owner Code"),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: roomController,
                    decoration: inputStyle("Room"),
                  ),
                ],

                const SizedBox(height: 35),

                // 🔥 BUTTON (UPGRADED)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 6,
                      shadowColor: Colors.deepOrange.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Register",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 15),

                // 🔙 BACK TO LOGIN
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
