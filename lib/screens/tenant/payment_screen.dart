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
  final ImagePicker picker = ImagePicker();

  bool loading = true;
  bool uploading = false;

  String room = "";
  String ownerId = "";
  String roomId = "";

  double rent = 0;
  double waterBill = 0;
  double electricBill = 0;
  double totalBill = 0;

  String? gcashQR;
  String? mayaQR;

  @override
  void initState() {
    super.initState();
    loadTenantData();
  }

  // =====================================================
  // LOAD TENANT + ROOM + QR
  // =====================================================
  Future<void> loadTenantData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          loading = false;
        });
        return;
      }

      // =========================
      // GET USER DATA
      // =========================
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          loading = false;
        });
        return;
      }

      final userData = userDoc.data()!;

      ownerId = userData["ownerId"] ?? "";
      room = userData["room"] ?? "";

      // =========================
      // VALIDATION
      // =========================
      if (ownerId.isEmpty || room.isEmpty) {
        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No connected room yet",
            ),
          ),
        );

        return;
      }

      // =========================
      // GET ROOM
      // =========================
      final roomQuery = await FirebaseFirestore.instance
          .collection("rooms")
          .where("ownerId", isEqualTo: ownerId)
          .where("roomNumber", isEqualTo: room)
          .limit(1)
          .get();

      if (roomQuery.docs.isNotEmpty) {
        final roomDoc = roomQuery.docs.first;

        roomId = roomDoc.id;

        final roomData = roomDoc.data();

        rent = (roomData["monthlyRent"] ?? 0).toDouble();

        waterBill = (roomData["waterBill"] ?? 0).toDouble();

        electricBill = (roomData["electricBill"] ?? 0).toDouble();

        totalBill = (roomData["totalBill"] ?? 0).toDouble();

        // AUTO SAVE TENANT ID
        if (roomData["tenantId"] == null ||
            roomData["tenantId"].toString().isEmpty) {
          await roomDoc.reference.update({
            "tenantId": user.uid,
          });
        }
      }

      // =========================
      // GET OWNER QR
      // =========================
      final ownerDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(ownerId)
          .get();

      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data()!;

        gcashQR = ownerData["gcashQr"];
        mayaQR = ownerData["paymayaQr"];
      }

      setState(() {
        loading = false;
      });
    } catch (e) {
      print("LOAD PAYMENT ERROR: $e");

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error: $e",
          ),
        ),
      );
    }
  }

  // =====================================================
  // CHECK IMAGE QUALITY
  // =====================================================
  Future<bool> isImageBlurred(File file) async {
    try {
      Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 1,
      );

      if (compressed == null) {
        return true;
      }

      int size = await file.length();

      if (size < 80000) {
        return true;
      }

      return false;
    } catch (e) {
      return true;
    }
  }

  // =====================================================
  // SHOW FULL IMAGE
  // =====================================================
  void showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // UPLOAD PAYMENT
  // =====================================================
  Future<void> uploadPayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (picked == null) return;

      setState(() {
        uploading = true;
      });

      File file = File(picked.path);

      // =========================
      // CHECK BLUR
      // =========================
      bool blurred = await isImageBlurred(file);

      if (blurred) {
        setState(() {
          uploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Blurred or low quality screenshot",
            ),
          ),
        );

        return;
      }

      // =========================
      // UPLOAD TO CLOUDINARY
      // =========================
      String? imageUrl = await uploadToCloudinary(file);

      if (imageUrl == null) {
        throw Exception("Cloudinary upload failed");
      }

      // =========================
      // SAVE PAYMENT
      // =========================
      await firestore.submitPayment(
        user.uid,
        ownerId,
        room,
        totalBill,
        imageUrl,
      );

      // =========================
      // UPDATE ROOM STATUS
      // =========================
      if (roomId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection("rooms")
            .doc(roomId)
            .update({
          "paymentStatus": "pending",
        });
      }

      setState(() {
        uploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Payment submitted successfully",
          ),
        ),
      );
    } catch (e) {
      print("UPLOAD ERROR: $e");

      setState(() {
        uploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Upload failed: $e",
          ),
        ),
      );
    }
  }

  // =====================================================
  // CONFIRM PAYMENT
  // =====================================================
  void confirmPayment() {
    if (totalBill <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No bill found",
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            "Confirm Payment",
          ),
          content: Text(
            "Upload proof of payment for ₱${totalBill.toStringAsFixed(2)} ?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                uploadPayment();
              },
              child: const Text(
                "Upload",
              ),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // UI
  // =====================================================
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
                  // =========================
                  // BILL CARD
                  // =========================
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            "Room $room",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Monthly Rent",
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                "₱${rent.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Water Bill",
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                "₱${waterBill.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Electric Bill",
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                "₱${electricBill.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                            height: 35,
                            thickness: 1,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "TOTAL",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "₱${totalBill.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 26,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // =========================
                  // GCASH QR
                  // =========================
                  if (gcashQR != null && gcashQR!.isNotEmpty)
                    Column(
                      children: [
                        const Text(
                          "GCash QR",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            showFullImage(gcashQR!);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              gcashQR!,
                              height: 250,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),

                  // =========================
                  // MAYA QR
                  // =========================
                  if (mayaQR != null && mayaQR!.isNotEmpty)
                    Column(
                      children: [
                        const Text(
                          "Maya QR",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            showFullImage(mayaQR!);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              mayaQR!,
                              height: 250,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),

                  // =========================
                  // UPLOAD BUTTON
                  // =========================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: uploading ? null : confirmPayment,
                      icon: const Icon(
                        Icons.upload,
                      ),
                      label: uploading
                          ? const Padding(
                              padding: EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Upload Payment Screenshot",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
