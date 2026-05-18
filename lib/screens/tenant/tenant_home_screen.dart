import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

              final roomDoc = roomSnapshot.data!.docs.first;

              final roomData = roomDoc.data() as Map<String, dynamic>;

              // =========================================
              // AUTO FIX TENANT ID
              // =========================================
              if (roomData["tenantId"] == null ||
                  roomData["tenantId"].toString().isEmpty) {
                FirebaseFirestore.instance
                    .collection("rooms")
                    .doc(roomDoc.id)
                    .update({
                  "tenantId": user.uid,
                });
              }

              // =========================================
              // AUTO FIX PAYMENT STATUS
              // =========================================
              if (roomData["paymentStatus"] == null) {
                FirebaseFirestore.instance
                    .collection("rooms")
                    .doc(roomDoc.id)
                    .update({
                  "paymentStatus": "unpaid",
                });
              }

              double rent = (roomData["monthlyRent"] ?? 0).toDouble();

              double electricConsumption =
                  (roomData["electricConsumption"] ?? 0).toDouble();

              double electricBill = (roomData["electricBill"] ?? 0).toDouble();

              double waterConsumption =
                  (roomData["waterConsumption"] ?? 0).toDouble();

              double waterBill = (roomData["waterBill"] ?? 0).toDouble();

              double totalBill = (roomData["totalBill"] ?? 0).toDouble();

              String paymentStatus = roomData["paymentStatus"] ?? "unpaid";

              bool isOverdue = roomData["isOverdue"] ?? false;

              Timestamp? dueTimestamp = roomData["dueDate"];

              Timestamp? paidAt = roomData["paidAt"];

              String dueDate = "No due date";

              if (dueTimestamp != null) {
                dueDate = DateFormat(
                  "MMMM dd, yyyy",
                ).format(
                  dueTimestamp.toDate(),
                );
              }

              String paidDate = "Not paid yet";

              if (paidAt != null) {
                paidDate = DateFormat(
                  "MMMM dd, yyyy - hh:mm a",
                ).format(
                  paidAt.toDate(),
                );
              }

              Color statusColor;

              if (paymentStatus == "paid") {
                statusColor = Colors.green;
              } else if (isOverdue) {
                statusColor = Colors.red;
              } else {
                statusColor = Colors.orange;
              }

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // =========================================
                      // TITLE
                      // =========================================
                      const Text(
                        "Monthly Billing",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1D1D1F),
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        "Here’s your billing breakdown for this month.",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // =========================================
                      // PAYMENT STATUS
                      // =========================================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(
                            22,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  paymentStatus == "paid"
                                      ? Icons.check_circle
                                      : isOverdue
                                          ? Icons.warning
                                          : Icons.access_time,
                                  color: statusColor,
                                  size: 28,
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  paymentStatus == "paid"
                                      ? "PAID"
                                      : isOverdue
                                          ? "OVERDUE"
                                          : "UNPAID",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "Due Date: $dueDate",
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Paid Date: $paidDate",
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // =========================================
                      // ROOM RENT
                      // =========================================
                      _buildBillCard(
                        icon: Icons.apartment,
                        iconColor: Colors.deepOrange,
                        title: "Room $room",
                        subtitle: "Monthly Rent",
                        amount: "₱${rent.toStringAsFixed(2)}",
                      ),

                      const SizedBox(height: 16),

                      // =========================================
                      // ELECTRIC BILL
                      // =========================================
                      _buildBillCard(
                        icon: Icons.flash_on,
                        iconColor: Colors.orange,
                        title: "Electricity",
                        subtitle:
                            "Consumption: ${electricConsumption.toStringAsFixed(1)} kWh",
                        amount: "₱${electricBill.toStringAsFixed(2)}",
                      ),

                      const SizedBox(height: 16),

                      // =========================================
                      // WATER BILL
                      // =========================================
                      _buildBillCard(
                        icon: Icons.water_drop,
                        iconColor: Colors.blue,
                        title: "Water",
                        subtitle:
                            "Consumption: ${waterConsumption.toStringAsFixed(1)} m³",
                        amount: "₱${waterBill.toStringAsFixed(2)}",
                      ),

                      const SizedBox(height: 24),

                      // =========================================
                      // TOTAL BILL
                      // =========================================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(
                          24,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xff39B54A),
                              Color(0xff5EDB72),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            24,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.25),
                              blurRadius: 14,
                              offset: const Offset(
                                0,
                                8,
                              ),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "TOTAL BILL",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(
                              height: 16,
                            ),
                            Text(
                              "₱${totalBill.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
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

  // =========================================
  // BILL CARD
  // =========================================
  Widget _buildBillCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1D1D1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 21,
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
