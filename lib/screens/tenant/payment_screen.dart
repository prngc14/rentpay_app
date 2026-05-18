import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
  double waterBill = 0;
  double electricBill = 0;
  double totalBill = 0;

  String? gcashQR;
  String? mayaQR;

  bool loading = true;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    loadTenantData();
  }

  // ======================================
  // LOAD TENANT + ROOM + OWNER QR
  // ======================================
  Future<void> loadTenantData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => loading = false);
        return;
      }

      // ==========================
      // GET TENANT DATA
      // ==========================
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => loading = false);
        return;
      }

      final userData = userDoc.data();

      ownerId = userData?["ownerId"] ?? "";
      room = userData?["room"] ?? "";

      // ==========================
      // CHECK CONNECTION
      // ==========================
      if (ownerId.isEmpty || room.isEmpty) {
        setState(() => loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Connect to owner and select a room first",
            ),
          ),
        );

        return;
      }

      // ==========================
      // GET ROOM DATA
      // ==========================
      final roomQuery = await FirebaseFirestore.instance
          .collection("rooms")
          .where("roomNumber", isEqualTo: room)
          .where("ownerId", isEqualTo: ownerId)
          .limit(1)
          .get();

      if (roomQuery.docs.isNotEmpty) {
        final roomData = roomQuery.docs.first.data();

        rent = (roomData["monthlyRent"] ?? 0).toDouble();

        waterBill = (roomData["waterBill"] ?? 0).toDouble();

        electricBill = (roomData["electricBill"] ?? 0).toDouble();

        totalBill = (roomData["totalBill"] ?? 0).toDouble();

        // AUTO FIX IF TENANT NOT SAVED
        if (roomData["tenantId"] == null ||
            roomData["tenantId"].toString().isEmpty) {
          await roomQuery.docs.first.reference.update({
            "tenantId": user.uid,
          });
        }
      }

      // ==========================
      // GET OWNER QR
      // ==========================
      final ownerDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(ownerId)
          .get();

      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data();

        gcashQR = ownerData?["gcashQr"];
        mayaQR = ownerData?["paymayaQr"];
      }

      setState(() => loading = false);
    } catch (e) {
      print("LOAD PAYMENT ERROR: $e");

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    }
  }

  // ======================================
  // CHECK IF IMAGE IS POSSIBLY BLURRED
  // ======================================
  Future<bool> isImageBlurred(File file) async {
    try {
      Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 1,
      );

      if (compressed == null) {
        return true;
      }

      // CHECK FILE SIZE
      int originalSize = await file.length();

      // TOO SMALL = POSSIBLY BLURRY
      if (originalSize < 80000) {
        return true;
      }

      return false;
    } catch (e) {
      return true;
    }
  }

  // ======================================
  // SHOW FULL IMAGE
  // ======================================
  void showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  // ======================================
  // UPLOAD PAYMENT
  // ======================================
  Future<void> uploadAndSubmitPayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (picked == null) return;

      setState(() => uploading = true);

      File file = File(picked.path);

      // ======================================
      // CHECK BLUR
      // ======================================
      bool blurred = await isImageBlurred(file);

      if (blurred) {
        setState(() => uploading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Blurred or low quality receipt detected",
            ),
          ),
        );

        return;
      }

      // ======================================
      // UPLOAD IMAGE
      // ======================================
      String? url = await uploadToCloudinary(file);

      if (url == null) {
        throw Exception("Cloudinary upload failed");
      }

      // ======================================
      // SAVE PAYMENT
      // ======================================
      await firestore.submitPayment(
        user.uid,
        ownerId,
        room,
        totalBill,
        url,
      );

      setState(() => uploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Payment submitted successfully",
          ),
        ),
      );
    } catch (e) {
      print("UPLOAD ERROR: $e");

      setState(() => uploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload failed: $e"),
        ),
      );
    }
  }

  // ======================================
  // CONFIRM PAYMENT
  // ======================================
  void confirmPayment() {
    if (totalBill <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No bill found"),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: Text(
          "Upload proof of payment for ₱$totalBill ?",
        ),
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

  // ======================================
  // UI
  // ======================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Rent"),
        backgroundColor: Colors.deepOrange,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ROOM CARD
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            "Room: $room",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Room Rent: ₱$rent",
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Water Bill: ₱$waterBill",
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Electric Bill: ₱$electricBill",
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          const Divider(
                            height: 30,
                            thickness: 1,
                          ),
                          Text(
                            "Total: ₱$totalBill",
                            style: const TextStyle(
                              fontSize: 28,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // GCASH QR
                  if (gcashQR != null && gcashQR!.isNotEmpty)
                    Column(
                      children: [
                        const Text(
                          "GCash QR",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => showFullImage(gcashQR!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              gcashQR!,
                              height: 220,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),

                  // MAYA QR
                  if (mayaQR != null && mayaQR!.isNotEmpty)
                    Column(
                      children: [
                        const Text(
                          "Maya QR",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => showFullImage(mayaQR!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              mayaQR!,
                              height: 220,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),

                  // UPLOAD BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: uploading ? null : confirmPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                      child: uploading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Upload Payment Screenshot",
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
