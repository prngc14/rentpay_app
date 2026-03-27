import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  String? gcashUrl;
  String? mayaUrl;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadExistingQr();
  }

  Future<void> loadExistingQr() async {
    try {
      final data = await firestore.getOwnerQrData();

      if (data != null) {
        setState(() {
          gcashUrl = data['gcashQr'];
          mayaUrl = data['paymayaQr']; // ✅ FIXED HERE
        });
      }
    } catch (e) {
      debugPrint("Error loading QR: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> pickImage(String type) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        if (type == "gcash") {
          gcashImage = File(picked.path);
        } else {
          mayaImage = File(picked.path);
        }
      });
    }
  }

  Future<void> uploadQr(String type) async {
    try {
      setState(() {
        isLoading = true;
      });

      File? selectedFile = type == "gcash" ? gcashImage : mayaImage;

      if (selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select a $type QR image first")),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      await firestore.uploadOwnerQr(
        file: selectedFile,
        type: type,
      );

      await loadExistingQr();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${type.toUpperCase()} QR uploaded successfully"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Widget buildQrCard({
    required String title,
    required File? localFile,
    required String? networkUrl,
    required Color buttonColor,
    required VoidCallback onPick,
    required VoidCallback onUpload,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: localFile != null
                    ? Image.file(localFile, fit: BoxFit.contain)
                    : (networkUrl != null && networkUrl.isNotEmpty)
                        ? Image.network(
                            networkUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Text(
                                  "Failed to load QR image",
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Text(
                              "No QR uploaded yet",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 20),
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
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Upload QR",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload QR"),
        backgroundColor: Colors.deepOrange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    buildQrCard(
                      title: "GCash QR",
                      localFile: gcashImage,
                      networkUrl: gcashUrl,
                      buttonColor: Colors.green,
                      onPick: () => pickImage("gcash"),
                      onUpload: () => uploadQr("gcash"),
                    ),
                    const SizedBox(height: 20),
                    buildQrCard(
                      title: "PayMaya QR",
                      localFile: mayaImage,
                      networkUrl: mayaUrl,
                      buttonColor: Colors.blue,
                      onPick: () => pickImage("maya"),
                      onUpload: () => uploadQr("maya"),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
