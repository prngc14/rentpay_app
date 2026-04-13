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

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    roomController.dispose();
    ownerCodeController.dispose();
    super.dispose();
  }

  String generateOwnerCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> registerUser() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // ✅ STEP 1: REGISTER USER
      var user = await _auth.register(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user == null) throw Exception("Registration failed");

      // ✅ STEP 2: SAVE USER DATA (ONLY ONE WRITE)
      if (role == "owner") {
        String ownerCode = generateOwnerCode();

        await _firestore.createUser(UserModel(
          uid: user.uid,
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          role: "owner",
          room: "",
          ownerCode: ownerCode,
          ownerId: "",
          approved: true,
        ));
      } else {
        if (ownerCodeController.text.isEmpty || roomController.text.isEmpty) {
          throw Exception("Enter owner code and room");
        }

        var ownerDoc =
            await _firestore.getOwnerByCode(ownerCodeController.text.trim());

        if (ownerDoc == null) {
          throw Exception("Invalid owner code");
        }

        await _firestore.createUser(UserModel(
          uid: user.uid,
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          role: "tenant",
          room: roomController.text.trim(), // ✅ FIXED
          ownerCode: ownerCodeController.text.trim(),
          ownerId: ownerDoc.id,
          approved: false,
        ));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registered Successfully")),
      );

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
                  decoration: inputStyle("Email"),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: inputStyle("Password"),
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
