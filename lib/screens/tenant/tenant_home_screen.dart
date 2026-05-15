import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TenantHomeScreen extends StatelessWidget {
  const TenantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

          if (userData == null) {
            return const Center(
              child: Text("No user data"),
            );
          }

          final room = userData["room"] ?? "";
          final ownerId = userData["ownerId"] ?? "";

          if (room.isEmpty || ownerId.isEmpty) {
            return const Center(
              child: Text(
                "No room connected yet",
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("rooms")
                .where("roomNumber", isEqualTo: room)
                .where("ownerId", isEqualTo: ownerId)
                .limit(1)
                .snapshots(),
            builder: (context, roomSnapshot) {
              if (!roomSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (roomSnapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("Room not found"),
                );
              }

              final roomData =
                  roomSnapshot.data!.docs.first.data() as Map<String, dynamic>;

              double rent = (roomData["monthlyRent"] ?? 0).toDouble();

              double electricConsumption =
                  (roomData["electricConsumption"] ?? 0).toDouble();

              double electricBill = (roomData["electricBill"] ?? 0).toDouble();

              double waterConsumption =
                  (roomData["waterConsumption"] ?? 0).toDouble();

              double waterBill = (roomData["waterBill"] ?? 0).toDouble();

              double totalBill = (roomData["totalBill"] ?? 0).toDouble();

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // =========================
                    // HEADER
                    // =========================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 60,
                        left: 25,
                        right: 25,
                        bottom: 35,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xffFF5F1F),
                            Color(0xffFF7B3D),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Home",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notifications_none,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Manage your monthly billing",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Monthly Billing",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1D1D1F),
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            "Here’s your billing breakdown for this month.",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 25),

                          // =========================
                          // ROOM CARD
                          // =========================
                          _buildBillCard(
                            icon: Icons.apartment,
                            iconColor: Colors.deepOrange,
                            title: "Room $room",
                            subtitle: "Monthly Rent",
                            amount: "₱${rent.toStringAsFixed(2)}",
                          ),

                          const SizedBox(height: 20),

                          // =========================
                          // ELECTRICITY CARD
                          // =========================
                          _buildBillCard(
                            icon: Icons.flash_on,
                            iconColor: Colors.orange,
                            title: "Electricity",
                            subtitle:
                                "Consumption: ${electricConsumption.toStringAsFixed(1)} kWh",
                            amount: "₱${electricBill.toStringAsFixed(2)}",
                          ),

                          const SizedBox(height: 20),

                          // =========================
                          // WATER CARD
                          // =========================
                          _buildBillCard(
                            icon: Icons.water_drop,
                            iconColor: Colors.blue,
                            title: "Water",
                            subtitle:
                                "Consumption: ${waterConsumption.toStringAsFixed(1)} m³",
                            amount: "₱${waterBill.toStringAsFixed(2)}",
                          ),

                          const SizedBox(height: 30),

                          // =========================
                          // TOTAL BILL CARD
                          // =========================
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xff39B54A),
                                  Color(0xff5EDB72),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "TOTAL BILL",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  "₱${totalBill.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // =========================
  // CUSTOM CARD WIDGET
  // =========================
  Widget _buildBillCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1D1D1F),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
