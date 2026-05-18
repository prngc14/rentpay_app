import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';

import 'owner_rooms_screen.dart';
import 'payment_requests_screen.dart';
import 'upload_qr_screen.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final FirestoreService firestore = FirestoreService();

  @override
  void initState() {
    super.initState();

    generateOwnerCode();
  }

  // =====================================================
  // GENERATE OWNER CODE
  // =====================================================
  Future<void> generateOwnerCode() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (data == null ||
        data["ownerCode"] == null ||
        data["ownerCode"].toString().isEmpty) {
      final random = Random();

      String code = (100000 + random.nextInt(900000)).toString();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({
        "ownerCode": code,
        "role": "owner",
      });
    }
  }

  // =====================================================
  // TOTAL INCOME
  // =====================================================
  Stream<double> getTotalIncome(String ownerId) async* {
    await for (var snapshot in FirebaseFirestore.instance
        .collection("payments")
        .where("ownerId", isEqualTo: ownerId)
        .where("status", isEqualTo: "verified")
        .snapshots()) {
      double total = 0;

      for (var doc in snapshot.docs) {
        total += (doc["amount"] ?? 0).toDouble();
      }

      yield total;
    }
  }

  // =====================================================
  // COUNT UNPAID
  // =====================================================
  Stream<int> countUnpaid(String ownerId) async* {
    await for (var snapshot in FirebaseFirestore.instance
        .collection("rooms")
        .where("ownerId", isEqualTo: ownerId)
        .where("paymentStatus", isEqualTo: "unpaid")
        .snapshots()) {
      yield snapshot.docs.length;
    }
  }

  // =====================================================
  // COUNT OVERDUE
  // =====================================================
  Stream<int> countOverdue(String ownerId) async* {
    await for (var snapshot in FirebaseFirestore.instance
        .collection("rooms")
        .where("ownerId", isEqualTo: ownerId)
        .snapshots()) {
      int overdue = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();

        Timestamp? dueDate = data["dueDate"];

        String paymentStatus = data["paymentStatus"] ?? "unpaid";

        if (dueDate != null &&
            paymentStatus != "paid" &&
            dueDate.toDate().isBefore(DateTime.now())) {
          overdue++;
        }
      }

      yield overdue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Owner Dashboard"),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text("Not logged in"),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;

                String ownerCode = userData["ownerCode"] ?? "------";

                String name = userData["name"] ?? "Owner";

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // =====================================================
                      // PROFILE
                      // =====================================================
                      Center(
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              child: Icon(
                                Icons.person,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              "Owner Code",
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                ownerCode,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 5,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // =====================================================
                      // ANALYTICS
                      // =====================================================
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<double>(
                              stream: getTotalIncome(user.uid),
                              builder: (context, snapshot) {
                                double total = snapshot.data ?? 0;

                                return _buildStatCard(
                                  "Income",
                                  "₱${total.toStringAsFixed(2)}",
                                  Colors.green,
                                  Icons.attach_money,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StreamBuilder<int>(
                              stream: countUnpaid(user.uid),
                              builder: (context, snapshot) {
                                int total = snapshot.data ?? 0;

                                return _buildStatCard(
                                  "Unpaid",
                                  "$total",
                                  Colors.orange,
                                  Icons.warning,
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      StreamBuilder<int>(
                        stream: countOverdue(user.uid),
                        builder: (context, snapshot) {
                          int total = snapshot.data ?? 0;

                          return _buildStatCard(
                            "Overdue Tenants",
                            "$total",
                            Colors.red,
                            Icons.error,
                          );
                        },
                      ),

                      const SizedBox(height: 25),

                      // =====================================================
                      // ACTIONS
                      // =====================================================
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _buildActionCard(
                            context,
                            "Create Room",
                            Icons.add_home,
                            Colors.deepOrange,
                            () => _showCreateRoomDialog(
                              context,
                              user.uid,
                            ),
                          ),
                          _buildActionCard(
                            context,
                            "My Rooms",
                            Icons.meeting_room,
                            Colors.orange,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OwnerRoomsScreen(
                                    ownerId: user.uid,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            context,
                            "Upload QR",
                            Icons.qr_code,
                            Colors.green,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const UploadQrScreen(),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            context,
                            "Payments",
                            Icons.payment,
                            Colors.blue,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PaymentRequestsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // =====================================================
  // STAT CARD
  // =====================================================
  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 35),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ACTION CARD
  // =====================================================
  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 35,
            ),
            const SizedBox(height: 10),
            Text(title),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // CREATE ROOM
  // =====================================================
  void _showCreateRoomDialog(
    BuildContext context,
    String ownerId,
  ) {
    final roomController = TextEditingController();

    final rentController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Room"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: "Room Number",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Monthly Rent",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (roomController.text.isEmpty || rentController.text.isEmpty) {
                return;
              }

              await firestore.createRoom(
                roomController.text.trim(),
                ownerId,
                double.tryParse(
                      rentController.text.trim(),
                    ) ??
                    0,
              );

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Room created successfully",
                  ),
                ),
              );
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}
