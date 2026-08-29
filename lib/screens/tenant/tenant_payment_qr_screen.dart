import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/firestore_service.dart';
import '../../widgets/app_warning_banner.dart'; // <-- ayusin ang path kung iba ang location 

class TenantPaymentHistoryScreen extends StatelessWidget {
  final String tenantId;
  final String tenantName;

  const TenantPaymentHistoryScreen({
    super.key,
    required this.tenantId,
    required this.tenantName,
  });

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestore = FirestoreService();

    // Ginagamit ang context ng buong Screen (mula sa build() mismo) sa
    // lahat ng banner calls sa ibaba, dele tung  sa specific item card,
    // dahil natatanggal agad ang card na iyon sa StreamBuilder pagka-
    // approve/reject/delete -- kaya laging stable ang context na ito
    // hangga't bukas ang buong screen.
    final screenContext = context;

    return Scaffold(
      appBar: AppBar(
        title: Text(tenantName),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getTenantPayments(tenantId),
        builder: (context, snapshot) {
          // 🔄 LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          //ERROR
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading payments:\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          //EMPTY
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No payment history yet",
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

              final String room = data["room"] ?? "No room";
              final double amount = (data["amount"] ?? 0).toDouble();
              final String screenshot = data["screenshot"] ?? "";
              final String status = data["status"] ?? "pending";
              final bool isPartial = data["isPartial"] ?? false;
              final Timestamp? date = data["date"];

              Color statusColor;

              if (status == "verified") {
                statusColor = Colors.green;
              } else if (status == "rejected") {
                statusColor = Colors.red;
              } else {
                statusColor = Colors.orange;
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
                      //ROOM
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Room: $room",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          if (isPartial)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "PARTIAL",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      //AMOUNT
                      Text(
                        "Amount: ₱${amount.toStringAsFixed(2)}",
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
                          "Submitted: ${DateFormat("yyyy-MM-dd HH:mm:ss").format(date.toDate())}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),

                      const SizedBox(height: 12),

                      //SCREENSHOT
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
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
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
                                  errorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                    return Container(
                                      height: 180,
                                      width: double.infinity,
                                      color: Colors.grey.shade300,
                                      child: const Center(
                                        child: Text(
                                          "Image not available",
                                        ),
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
                            child: Text(
                              "No screenshot uploaded",
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      //STATUS
                      Row(
                        children: [
                          const Text(
                            "Status: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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

                      //APPROVE / REJECT
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

                                  if (!screenContext.mounted) return;
                                  showAppSuccessBanner(
                                      screenContext, "Payment approved");
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
                                  // ✅ FIXED: dinagdagan ng tenantId para
                                  // ma-clear ang activePaymentId lock ng
                                  // tenant kapag na-reject ang payment
                                  // (kailangan ito ng bagong signature ng
                                  // rejectPayment() sa FirestoreService).
                                  await firestore.rejectPayment(
                                    p.id,
                                    tenantId,
                                  );

                                  if (!screenContext.mounted) return;
                                  showAppWarningBanner(
                                      screenContext, "Payment rejected");
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

                      const SizedBox(height: 12),

                      // 🗑 DELETE BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text(
                                    "Delete Payment",
                                  ),
                                  content: const Text(
                                    "Are you sure you want to delete this payment request?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(
                                          context,
                                          false,
                                        );
                                      },
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(
                                          context,
                                          true,
                                        );
                                      },
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              await FirebaseFirestore.instance
                                  .collection("payments")
                                  .doc(p.id)
                                  .delete();

                              // Gamit ang stable na screenContext (dili
                              // yung sa card na ito) dahil matatanggal
                              // agad ang card pagka-delete.
                              if (!screenContext.mounted) return;
                              showAppSuccessBanner(screenContext,
                                  "Payment deleted successfully");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          icon: const Icon(Icons.delete),
                          label: const Text("Delete Payment"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}