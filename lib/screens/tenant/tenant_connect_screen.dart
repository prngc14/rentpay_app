import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TenantConnectScreen extends StatefulWidget {
  const TenantConnectScreen({super.key});

  @override
  State<TenantConnectScreen> createState() => _TenantConnectScreenState();
}

class _TenantConnectScreenState extends State<TenantConnectScreen> {
  final TextEditingController codeController = TextEditingController();
  bool loading = false;

  Future<void> connectToOwner() async {
    String code = codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter owner code")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // 🔍 hanapin owner gamit 6-digit code
      final query = await FirebaseFirestore.instance
          .collection("users")
          .where("ownerCode", isEqualTo: code)
          .where("role", isEqualTo: "owner")
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw "Owner not found";
      }

      final ownerDoc = query.docs.first;
      final ownerUID = ownerDoc.id; // 🔥 ito ang UID

      final user = FirebaseAuth.instance.currentUser!;
      final userRef =
          FirebaseFirestore.instance.collection("users").doc(user.uid);

      // ✅ save connection
      await userRef.update({
        "ownerId": ownerUID,
        "ownerCode": code,
        "approved": true, // optional
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connected successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      print("CONNECT ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connect to Owner"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Enter Owner Code",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "6-digit code",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : connectToOwner,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Connect"),
            ),
          ],
        ),
      ),
    );
  }
}
