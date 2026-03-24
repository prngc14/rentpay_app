import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';

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
  final FirestoreService firestore = FirestoreService();

  String? gcashUrl;
  String? paymayaUrl;

  // ================= LOAD EXISTING QR =================
  Future<void> loadExistingQR() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var data = await firestore.getOwnerQR(user.uid);

    if (data != null) {
      setState(() {
        gcashUrl = data["gcashQR"];
        paymayaUrl = data["mayaQR"];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadExistingQR();
  }

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

  // ================= SAVE TO USER (FIXED) =================
  Future uploadBothQR() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (gcashImage == null && paymayaImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one QR")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      String? newGcashUrl;
      String? newPaymayaUrl;

      if (gcashImage != null) {
        newGcashUrl = await uploadToCloudinary(gcashImage!);
      }

      if (paymayaImage != null) {
        newPaymayaUrl = await uploadToCloudinary(paymayaImage!);
      }

      // ✅ SAVE TO USER DOCUMENT (IMPORTANT FIX)
      await firestore.saveOwnerQR(
        user.uid,
        newGcashUrl ?? gcashUrl,
        newPaymayaUrl ?? paymayaUrl,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("QR Saved Successfully")),
      );

      setState(() {
        gcashImage = null;
        paymayaImage = null;
        gcashUrl = newGcashUrl ?? gcashUrl;
        paymayaUrl = newPaymayaUrl ?? paymayaUrl;
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

  // ================= UI CARD =================
  Widget qrCard({
    required String title,
    required File? localImage,
    required String? url,
    required VoidCallback onPick,
    required Color buttonColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 260,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: localImage != null
              ? Image.file(localImage, fit: BoxFit.contain)
              : (url != null && url.isNotEmpty
                  ? GestureDetector(
                      onTap: () => showFullImage(url),
                      child: Image.network(url, fit: BoxFit.contain),
                    )
                  : const Center(child: Text("No QR uploaded"))),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: onPick,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            minimumSize: const Size(double.infinity, 45),
          ),
          child: const Text("Select Image"),
        ),
      ],
    );
  }

  // ================= MAIN UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload QR"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            qrCard(
              title: "GCash QR",
              localImage: gcashImage,
              url: gcashUrl,
              onPick: pickGcash,
              buttonColor: Colors.green,
            ),
            const SizedBox(height: 20),
            qrCard(
              title: "PayMaya QR",
              localImage: paymayaImage,
              url: paymayaUrl,
              onPick: pickPaymaya,
              buttonColor: Colors.blue,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : uploadBothQR,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.all(16),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save QR"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
