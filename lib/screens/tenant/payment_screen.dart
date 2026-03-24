import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirestoreService firestore = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  String room = "";
  String ownerId = "";
  double rent = 0;

  String? gcashQR;
  String? mayaQR;

  bool loading = true;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    loadTenantData();
  }

  // ===============================
  // LOAD TENANT DATA
  // ===============================
  Future<void> loadTenantData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      var userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      ownerId = userDoc["ownerId"] ?? "";
      room = userDoc["room"] ?? "";

      if (ownerId.isEmpty || room.isEmpty) {
        setState(() => loading = false);
        return;
      }

      // 🔥 Get Room Rent
      var roomQuery = await FirebaseFirestore.instance
          .collection("rooms")
          .where("roomNumber", isEqualTo: room)
          .limit(1)
          .get();

      if (roomQuery.docs.isNotEmpty) {
        rent = (roomQuery.docs.first["monthlyRent"] ?? 0).toDouble();
      }

      // 🔥 Get Owner QR (FROM SETTINGS OR YOUR SERVICE)
      var ownerDoc = await firestore.getOwnerQR(ownerId);

      if (ownerDoc != null) {
        gcashQR = ownerDoc["gcashQr"];
        mayaQR = ownerDoc["paymayaQr"];
      }

      setState(() => loading = false);
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ===============================
  // UPLOAD + SUBMIT PAYMENT (FIXED)
  // ===============================
  Future<void> uploadAndSubmitPayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (ownerId.isEmpty || room.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Missing room or owner")),
        );
        return;
      }

      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => uploading = true);

      File file = File(picked.path);

      // ✅ UPLOAD TO CLOUDINARY
      String? url = await uploadToCloudinary(file);

      if (url == null) {
        throw Exception("Cloudinary upload failed");
      }

      // ✅ SAVE PAYMENT
      await firestore.submitPayment(
        user.uid,
        ownerId,
        room,
        rent,
        url,
      );

      setState(() => uploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Payment submitted")),
      );
    } catch (e) {
      setState(() => uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Upload failed: $e")),
      );
    }
  }

  // ===============================
  // IMAGE ZOOM
  // ===============================
  void showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  // ===============================
  // CONFIRM DIALOG
  // ===============================
  void confirmPayment() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: Text("Upload proof for ₱$rent?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              uploadAndSubmitPayment();
            },
            child: const Text("Upload"),
          ),
        ],
      ),
    );
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Rent"),
        backgroundColor: Colors.deepOrange,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // RENT CARD
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text("Room: $room"),
                          const SizedBox(height: 10),
                          Text(
                            "Rent: ₱$rent",
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // GCASH
                  if (gcashQR != null && gcashQR!.isNotEmpty)
                    Column(
                      children: [
                        const Text("GCash", style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => showFullImage(gcashQR!),
                          child: Image.network(gcashQR!, height: 200),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),

                  // MAYA
                  if (mayaQR != null && mayaQR!.isNotEmpty)
                    Column(
                      children: [
                        const Text("Maya", style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => showFullImage(mayaQR!),
                          child: Image.network(mayaQR!, height: 200),
                        ),
                      ],
                    ),

                  const SizedBox(height: 30),

                  // BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: uploading ? null : confirmPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: uploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Upload Payment Screenshot"),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
