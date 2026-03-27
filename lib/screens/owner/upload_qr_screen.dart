import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../services/firestore_service.dart';

class UploadQrScreen extends StatefulWidget {
  const UploadQrScreen({super.key});

  @override
  State<UploadQrScreen> createState() => _UploadQrScreenState();
}

class _UploadQrScreenState extends State<UploadQrScreen> {
  final FirestoreService firestore = FirestoreService();

  File? gcashImage;
  File? mayaImage;

  bool isLoading = false;

  String? gcashUrl;
  String? mayaUrl;

  @override
  void initState() {
    super.initState();
    loadExistingQr();
  }

  Future<void> loadExistingQr() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = await firestore.getOwnerQR(user.uid);

    if (data != null) {
      setState(() {
        gcashUrl = data["gcashQr"];
        mayaUrl = data["paymayaQr"];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload QR"),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildQrCard(
              title: "GCash QR",
              localImage: gcashImage,
              networkUrl: gcashUrl,
              buttonColor: Colors.green,
              onPick: () => _pickImage("gcash"),
              onUpload: () => _uploadQr("gcash"),
            ),
            const SizedBox(height: 24),
            _buildQrCard(
              title: "PayMaya QR",
              localImage: mayaImage,
              networkUrl: mayaUrl,
              buttonColor: Colors.blue,
              onPick: () => _pickImage("maya"),
              onUpload: () => _uploadQr("maya"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard({
    required String title,
    required File? localImage,
    required String? networkUrl,
    required Color buttonColor,
    required VoidCallback onPick,
    required VoidCallback onUpload,
  }) {
    Widget imageWidget;

    if (localImage != null) {
      imageWidget = Image.file(
        localImage,
        height: 250,
        fit: BoxFit.contain,
      );
    } else if (networkUrl != null && networkUrl!.isNotEmpty) {
      imageWidget = Image.network(
        networkUrl!,
        height: 250,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Text(
              "Broken image / QR not found",
              style: TextStyle(color: Colors.red),
            ),
          );
        },
      );
    } else {
      imageWidget = const Center(
        child: Text(
          "No image selected",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black12,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: imageWidget),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPick,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              "Select Image",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : onUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "Upload QR",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    setState(() {
      if (type == "gcash") {
        gcashImage = File(picked.path);
      } else {
        mayaImage = File(picked.path);
      }
    });
  }

  Future<void> _uploadQr(String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    File? selectedFile = type == "gcash" ? gcashImage : mayaImage;

    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a $type QR image first")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("owner_qr")
          .child(user.uid)
          .child("$type.jpg");

      await storageRef.putFile(selectedFile);

      final downloadUrl = await storageRef.getDownloadURL();

      if (type == "gcash") {
        gcashUrl = downloadUrl;
      } else {
        mayaUrl = downloadUrl;
      }

      await firestore.saveOwnerQR(
        user.uid,
        type == "gcash" ? gcashUrl : null,
        type == "maya" ? mayaUrl : null,
      );

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("${type.toUpperCase()} QR uploaded successfully")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}
