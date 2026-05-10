import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TenantQRScreen extends StatelessWidget {
  const TenantQRScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment QR"),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("settings")
            .doc("payment_qr")
            .snapshots(),
        builder: (context, snapshot) {
          // 🔄 LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ❌ NO DATA
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("No QR uploaded"),
            );
          }

          // ✅ GET DATA
          final data = snapshot.data!.data() as Map<String, dynamic>;

          String? gcashQr = data["gcashQr"];
          String? paymayaQr = data["paymayaQr"];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ================= GCash =================
                buildQR(
                  context,
                  "GCash",
                  gcashQr,
                ),

                const SizedBox(height: 30),

                // ================= PayMaya =================
                buildQR(
                  context,
                  "PayMaya",
                  paymayaQr,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= QR WIDGET =================
  Widget buildQR(
    BuildContext context,
    String title,
    String? qrUrl,
  ) {
    return Column(
      children: [
        Text(
          "$title QR",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        qrUrl != null && qrUrl.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  // 🔥 ENLARGE IMAGE WHEN CLICKED
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.black,
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            qrUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  "Failed to load image",
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    qrUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Text(
                            "Failed to load image",
                            style: TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            : const Text(
                "No QR uploaded",
                style: TextStyle(fontSize: 16),
              ),
        const SizedBox(height: 12),
        const Text(
          "Tap image to enlarge",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
