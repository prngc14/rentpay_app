import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';

class PaymentRequestsScreen extends StatelessWidget {
  const PaymentRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestore = FirestoreService();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Requests"),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getOwnerPayments(user.uid),
        builder: (context, snapshot) {
          // 🔄 LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ ERROR
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading payments:\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          // 📭 EMPTY
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No payment requests yet",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final payments = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final p = payments[index];
              final data = p.data() as Map<String, dynamic>;

              final String tenantId = data["tenantId"] ?? "";
              final String room = data["room"] ?? "No room";
              final double amount = (data["amount"] ?? 0).toDouble();
              final String screenshot = data["screenshot"] ?? "";
              final String status = data["status"] ?? "pending";
              final Timestamp? date = data["date"];

              Color statusColor;
              if (status == "verified") {
                statusColor = Colors.green;
              } else if (status == "rejected") {
                statusColor = Colors.red;
              } else {
                statusColor = Colors.orange;
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(tenantId)
                    .get(),
                builder: (context, tenantSnapshot) {
                  String tenantName = "Loading tenant...";
                  String tenantEmail = "";

                  if (tenantSnapshot.hasData && tenantSnapshot.data!.exists) {
                    final tenantData =
                        tenantSnapshot.data!.data() as Map<String, dynamic>;
                    tenantName = tenantData["name"] ?? "Unnamed Tenant";
                    tenantEmail = tenantData["email"] ?? "";
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 👤 TENANT INFO
                          Text(
                            tenantName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (tenantEmail.isNotEmpty)
                            Text(
                              tenantEmail,
                              style: const TextStyle(color: Colors.grey),
                            ),

                          const SizedBox(height: 10),

                          // 🏠 ROOM
                          Text(
                            "Room: $room",
                            style: const TextStyle(fontSize: 16),
                          ),

                          const SizedBox(height: 5),

                          // 💵 AMOUNT
                          Text(
                            "Amount: ₱$amount",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 🕒 DATE
                          if (date != null)
                            Text(
                              "Submitted: ${date.toDate()}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),

                          const SizedBox(height: 12),

                          // 🖼 SCREENSHOT
                          if (screenshot.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Payment Screenshot",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: InteractiveViewer(
                                          child: Image.network(
                                            screenshot,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Padding(
                                                padding: EdgeInsets.all(20),
                                                child: Text(
                                                  "Failed to load image",
                                                  textAlign: TextAlign.center,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      screenshot,
                                      height: 220,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          height: 180,
                                          width: double.infinity,
                                          color: Colors.grey.shade300,
                                          child: const Center(
                                            child: Text("Image not available"),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text("No screenshot uploaded"),
                              ),
                            ),

                          const SizedBox(height: 14),

                          // 📌 STATUS
                          Row(
                            children: [
                              const Text(
                                "Status: ",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ✅ APPROVE / REJECT
                          if (status == "pending")
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await firestore.approvePayment(
                                        p.id,
                                        tenantId,
                                      );

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text("✅ Payment approved"),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    icon: const Icon(Icons.check),
                                    label: const Text("Approve"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await firestore.rejectPayment(p.id);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text("❌ Payment rejected"),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    icon: const Icon(Icons.close),
                                    label: const Text("Reject"),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
