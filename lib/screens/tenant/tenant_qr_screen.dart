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
          // 🔄 loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ no data
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No QR uploaded"));
          }

          // ✅ get data
          final data = snapshot.data!.data() as Map<String, dynamic>;

          String? gcashQr = data["gcashQr"];
          String? paymayaQr = data["paymayaQr"];

          // 🔥 DEBUG (check terminal)
          print("FIRESTORE DATA: $data");

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ================= GCash =================
                buildQR("GCash", gcashQr),

                const SizedBox(height: 30),

                // ================= PayMaya =================
                buildQR("PayMaya", paymayaQr),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= QR WIDGET =================
  Widget buildQR(String title, String? qrUrl) {
    return Column(
      children: [
        Text(
          "$title QR",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // 🔥 FINAL FIX (THIS IS WHERE YOUR CODE GOES)
        qrUrl != null && qrUrl.isNotEmpty
            ? Column(
                children: [
                  Image.network(
                    qrUrl,
                    height: 200,

                    // 🔥 SHOW ERROR IF FAILS
                    errorBuilder: (context, error, stackTrace) {
                      print("IMAGE ERROR: $error");

                      return const Text(
                        "Failed to load image",
                        style: TextStyle(color: Colors.red),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // 🔥 SHOW URL FOR DEBUG
                  Text(
                    qrUrl,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              )
            : const Text("No QR uploaded"),
      ],
    );
  }
}
