import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/firestore_service.dart';
import 'tenant_payment_history_screen.dart';

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
        title: const Text("Payment History"),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getOwnerPayments(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading payments:\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No payment history yet",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final payments = snapshot.data!.docs;

          final Map<String, List<QueryDocumentSnapshot>> grouped = {};

          for (final doc in payments) {
            final data = doc.data() as Map<String, dynamic>;
            final String tenantId = data["tenantId"] ?? "";

            if (tenantId.isEmpty) continue;

            grouped.putIfAbsent(tenantId, () => []).add(doc);
          }

          final tenantIds = grouped.keys.toList();

          if (tenantIds.isEmpty) {
            return const Center(
              child: Text(
                "No payment requests yet",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tenantIds.length,
            itemBuilder: (context, index) {
              final tenantId = tenantIds[index];
              final group = grouped[tenantId]!;

              final int totalCount = group.length;

              final int pendingCount = group.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return (data["status"] ?? "pending") == "pending";
              }).length;

              final latestData = group.first.data() as Map<String, dynamic>;

              final String room = latestData["room"] ?? "No room";

              final Timestamp? latestDate = latestData["date"];

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

                  final String tenantUsername = tenantEmail.contains("@")
                      ? tenantEmail.split("@").first
                      : tenantEmail;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TenantPaymentHistoryScreen(
                              ownerId: user.uid,
                              tenantId: tenantId,
                              tenantName: tenantName,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.deepOrange.shade50,
                              child: const Icon(
                                Icons.person,
                                color: Colors.deepOrange,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tenantName,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (pendingCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            "$pendingCount Pending",
                                            style: const TextStyle(
                                              color: Colors.deepOrange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (tenantUsername.isNotEmpty)
                                    Text(
                                      "Username: $tenantUsername",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Room: $room",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Total Payments: $totalCount",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (latestDate != null)
                                    Text(
                                      "Last Submitted: ${DateFormat("yyyy-MM-dd HH:mm:ss").format(latestDate.toDate())}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                          ],
                        ),
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