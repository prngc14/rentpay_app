import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import 'tenant_payment_history_screen.dart';

class PaymentRequestsScreen extends StatelessWidget {
  const PaymentRequestsScreen({super.key});

  // Gets the numeric value from the room number.
  // Examples:
  // "1"       -> 1
  // "Room 1"  -> 1
  // "Room 12" -> 12
  // "12A"     -> 12
  static int _roomNumberValue(dynamic value) {
    final text = value?.toString().trim() ?? '';

    final directNumber = int.tryParse(text);
    if (directNumber != null) {
      return directNumber;
    }

    final match = RegExp(r'\d+').firstMatch(text);

    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestore = FirestoreService();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Not logged in"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Rentpay",
          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: Color(0xFF123E5A),
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF123E5A),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getOwnerPayments(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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
      "No payment history",
    ),
  );
}

          final payments = snapshot.data!.docs;

          final Map<String, List<QueryDocumentSnapshot>> grouped = {};

          for (final doc in payments) {
            final data = doc.data() as Map<String, dynamic>;

            final String tenantId = data["tenantId"] ?? "";

            if (tenantId.isEmpty) continue;

            grouped.putIfAbsent(
              tenantId,
              () => [],
            ).add(doc);
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

          // Sort tenants according to their room number.
          //
          // Example:
          // Room 1
          // Room 2
          // Room 3
          // Room 4
          // Room 5
          // Room 6
          //
          // This prevents Firestore's payment order from making
          // Room 2 appear before Room 1.
          tenantIds.sort((a, b) {
            final groupA = grouped[a]!;
            final groupB = grouped[b]!;

            final dataA = groupA.first.data() as Map<String, dynamic>;
            final dataB = groupB.first.data() as Map<String, dynamic>;

            final roomA = _roomNumberValue(dataA["room"]);
            final roomB = _roomNumberValue(dataB["room"]);

            return roomA.compareTo(roomB);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: tenantIds.length,
            itemBuilder: (context, index) {
              final tenantId = tenantIds[index];
              final group = grouped[tenantId]!;

              final int pendingCount = group.where((d) {
                final data = d.data() as Map<String, dynamic>;

                return (data["status"] ?? "pending") == "pending";
              }).length;

              final latestData =
                  group.first.data() as Map<String, dynamic>;

              final String room = latestData["room"] ?? "No room";

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(tenantId)
                    .get(),
                builder: (context, tenantSnapshot) {
                  if (tenantSnapshot.hasError) {
                    return Text(
                      "Unable to load tenant: ${tenantSnapshot.error}",
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    );
                  }

                  String tenantName = "Loading tenant...";

                  if (tenantSnapshot.hasData &&
                      tenantSnapshot.data!.exists) {
                    final tenantData =
                        tenantSnapshot.data!.data()
                            as Map<String, dynamic>;

                    tenantName =
                        tenantData["name"] ?? "Unnamed Tenant";
                  }

                  return _buildCompactPaymentCard(
                    context: context,
                    ownerId: user.uid,
                    tenantId: tenantId,
                    tenantName: tenantName,
                    room: room,
                    pendingCount: pendingCount,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCompactPaymentCard({
    required BuildContext context,
    required String ownerId,
    required String tenantId,
    required String tenantName,
    required String room,
    required int pendingCount,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      elevation: 0,
      color: Colors.white.withOpacity(0.78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.white.withOpacity(0.8),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: const CircleAvatar(
          backgroundColor: Color(0x1AE88916),
          child: Icon(
            Icons.person,
            color: Color(0xFFE88916),
          ),
        ),
        title: Text(
          tenantName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF123E5A),
          ),
        ),
        subtitle: Text(
          "Room: $room",
          style: const TextStyle(
            color: Color(0xFF587287),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1AE88916),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$pendingCount",
                  style: const TextStyle(
                    color: Color(0xFFE88916),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF587287),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TenantPaymentHistoryScreen(
                ownerId: ownerId,
                tenantId: tenantId,
                tenantName: tenantName,
              ),
            ),
          );
        },
      ),
    );
  }
}