import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  final FirestoreService _tenantFirestoreService = FirestoreService();
  bool _contractDueNotificationShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _maybeSendContractDueNotification(user.uid);
      }
    });
  }

  Future<void> _maybeSendContractDueNotification(String tenantId) async {
    if (_contractDueNotificationShown) return;
    _contractDueNotificationShown = true;

    final shouldSend = await _tenantFirestoreService
        .shouldSendContractDueNotification(tenantId);
    if (!mounted || !shouldSend) return;

    final DateTime? dueDate =
        await _tenantFirestoreService.getNextContractDueDateForTenant(tenantId);
    if (!mounted || dueDate == null) return;

    await NotificationService.showLocalNotification(
      title: 'RentPay Reminder',
      body:
          'Your contract-based rent due date is ${DateFormat("MMMM dd, yyyy").format(dueDate)}. Please pay if not yet paid.',
    );
  }

  // =========================
  // STATUS DISPLAY HELPERS
  // Priority: PAID > PARTIAL > OVERDUE > UNPAID
  // =========================
  String _statusLabel(String paymentStatus, bool isOverdue) {
    if (paymentStatus == "paid") return "PAID";
    if (paymentStatus == "partial") return "PARTIAL PAYMENT";
    if (isOverdue) return "OVERDUE";
    return "UNPAID";
  }

  Color _statusColor(String paymentStatus, bool isOverdue) {
    if (paymentStatus == "paid") return Colors.green;
    if (paymentStatus == "partial") return Colors.orange;
    if (isOverdue) return Colors.red;
    return Colors.orange;
  }

  Color _statusBgColor(String paymentStatus, bool isOverdue) {
    if (paymentStatus == "paid") return Colors.green.shade50;
    if (paymentStatus == "partial") return Colors.orange.shade50;
    if (isOverdue) return Colors.red.shade50;
    return Colors.orange.shade50;
  }

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

              double amountPaid = (roomData["amountPaid"] ?? 0).toDouble();

              double remainingBalance = (roomData["remainingBalance"] ??
                      (totalBill - amountPaid))
                  .toDouble();

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

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // =========================
                      // TITLE
                      // =========================
                      const Text(
                        "Monthly Billing",
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1D1D1F),
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        "Here’s your billing breakdown for this month.",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =========================
                      // PAYMENT STATUS
                      // =========================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _statusBgColor(paymentStatus, isOverdue),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusLabel(paymentStatus, isOverdue),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(paymentStatus, isOverdue),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Due Date: $dueDate",
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),

                            // PARTIAL: ipakita ang Amount Paid + Remaining
                            if (paymentStatus == "partial") ...[
                              const SizedBox(height: 5),
                              Text(
                                "Amount Paid: ₱${amountPaid.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Remaining Balance: ₱${remainingBalance.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 5),
                              Text(
                                "Paid Date: $paidDate",
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

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

                      const SizedBox(height: 16),

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

                      const SizedBox(height: 16),

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

                      const SizedBox(height: 22),

                      // =========================
                      // TOTAL / REMAINING BILL CARD
                      // =========================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xff39B54A),
                              Color(0xff5EDB72),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              paymentStatus == "partial"
                                  ? "REMAINING BALANCE"
                                  : "TOTAL BILL",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "₱${(paymentStatus == "partial" ? remainingBalance : totalBill).toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
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
                    fontSize: 20,
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