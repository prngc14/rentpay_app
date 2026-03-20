import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TenantQrScreen extends StatelessWidget {
  const TenantQrScreen({super.key});

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
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No QR yet"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("GCash: ${data["gcashQr"] ?? "none"}"),
              Text("PayMaya: ${data["paymayaQr"] ?? "none"}"),
            ],
          );
        },
      ),
    );
  }
}
