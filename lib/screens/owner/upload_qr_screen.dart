import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ ADD THIS
import '../../services/cloudinary_service.dart';

class UploadQRScreen extends StatefulWidget {
  const UploadQRScreen({super.key});

  @override
  State<UploadQRScreen> createState() => _UploadQRScreenState();
}

class _UploadQRScreenState extends State<UploadQRScreen> {
  File? gcashImage;
  File? paymayaImage;

  bool isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final user = FirebaseAuth.instance.currentUser; // ✅ CURRENT USER

  // ================= PICK =================

  Future pickGcash() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => gcashImage = File(picked.path));
    }
  }

  Future pickPaymaya() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => paymayaImage = File(picked.path));
    }
  }

  // ================= UPLOAD =================

  Future uploadBothQR() async {
    if (gcashImage == null && paymayaImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one QR")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      String? gcashUrl;
      String? paymayaUrl;

      if (gcashImage != null) {
        gcashUrl = await uploadToCloudinary(gcashImage!);
      }

      if (paymayaImage != null) {
        paymayaUrl = await uploadToCloudinary(paymayaImage!);
      }

      final docRef = FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid); // ✅ SAVE PER OWNER

      final doc = await docRef.get();

      Map<String, dynamic> oldData = {};
      if (doc.exists && doc.data() != null) {
        oldData = doc.data()!;
      }

      await docRef.set({
        "gcashQR": gcashUrl ?? oldData["gcashQR"],
        "mayaQR": paymayaUrl ?? oldData["mayaQR"],
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("QR Uploaded Successfully")),
      );

      setState(() {
        gcashImage = null;
        paymayaImage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  // ================= ZOOM =================

  void showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }

  // ================= CARD =================

  Widget qrCard({
    required String title,
    required File? localImage,
    required String? url,
    required VoidCallback onPick,
    required Color buttonColor,
    required String buttonText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 260,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: localImage != null
              ? Image.file(localImage, fit: BoxFit.contain)
              : (url != null && url.isNotEmpty
                  ? GestureDetector(
                      onTap: () => showFullImage(url),
                      child: Image.network(url, fit: BoxFit.contain),
                    )
                  : const Center(
                      child: Text("No QR uploaded"), // ✅ EMPTY FOR NEW OWNER
                    )),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: onPick,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            minimumSize: const Size(double.infinity, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(buttonText),
        ),
      ],
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload QR"),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user!.uid) // ✅ LISTEN TO OWNER ONLY
            .snapshots(),
        builder: (context, snapshot) {
          String? gcashUrl;
          String? paymayaUrl;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            gcashUrl = data["gcashQR"];
            paymayaUrl = data["mayaQR"];
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  qrCard(
                    title: "GCash QR",
                    localImage: gcashImage,
                    url: gcashUrl,
                    onPick: pickGcash,
                    buttonColor: Colors.green,
                    buttonText: "Select GCash",
                  ),
                  const SizedBox(height: 25),
                  qrCard(
                    title: "PayMaya QR",
                    localImage: paymayaImage,
                    url: paymayaUrl,
                    onPick: pickPaymaya,
                    buttonColor: Colors.blue,
                    buttonText: "Select PayMaya",
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : uploadBothQR,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Upload QR",
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
