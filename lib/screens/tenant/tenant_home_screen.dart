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
                .where(
                  "roomNumber",
                  isEqualTo: room,
                )
                .where(
                  "ownerId",
                  isEqualTo: ownerId,
                )
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 10,
                    ),

                    const Text(
                      "Monthly Billing",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ======================================
                    // ROOM INFO
                    // ======================================
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          20,
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Room $room",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text(
                              "Monthly Rent: ₱$rent",
                              style: const TextStyle(
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ======================================
                    // ELECTRIC BILL
                    // ======================================
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Electricity",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 15,
                            ),
                            Text(
                              "Consumption: $electricConsumption kWh",
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Text(
                              "Bill: ₱$electricBill",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ======================================
                    // WATER BILL
                    // ======================================
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Water",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 15,
                            ),
                            Text(
                              "Consumption: $waterConsumption m³",
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Text(
                              "Bill: ₱$waterBill",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    // ======================================
                    // TOTAL BILL
                    // ======================================
                    Card(
                      color: Colors.green,
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          25,
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Text(
                                "TOTAL BILL",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 15,
                              ),
                              Text(
                                "₱$totalBill",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}
