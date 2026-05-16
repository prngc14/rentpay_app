import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class TenantRoomScreen extends StatelessWidget {
  const TenantRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Room"),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user!.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;

          final roomNumber = userData["room"];

          if (roomNumber == null || roomNumber == "") {
            return const Center(
              child: Text("No room assigned"),
            );
          }

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection("rooms")
                .where(
                  "roomNumber",
                  isEqualTo: roomNumber,
                )
                .limit(1)
                .get(),
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

              final room = roomDoc.data() as Map<String, dynamic>;

              double monthlyRent = (room["monthlyRent"] ?? 0).toDouble();

              double electricRate = (room["electricRate"] ?? 0).toDouble();

              double waterRate = (room["waterRate"] ?? 0).toDouble();

              double electricConsumption =
                  (room["electricConsumption"] ?? 0).toDouble();

              double waterConsumption =
                  (room["waterConsumption"] ?? 0).toDouble();

              double electricBill = (room["electricBill"] ?? 0).toDouble();

              double waterBill = (room["waterBill"] ?? 0).toDouble();

              double totalBill = (room["totalBill"] ?? 0).toDouble();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Icon(
                            Icons.home,
                            size: 80,
                            color: Colors.deepOrange,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Center(
                          child: Text(
                            "Room ${room["roomNumber"]}",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // ====================================
                        // TENANT INFO
                        // ====================================
                        const Text(
                          "Tenant Information",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(
                            userData["name"] ?? "No Name",
                          ),
                        ),

                        ListTile(
                          leading: const Icon(Icons.phone),
                          title: Text(
                            userData["phone"] ?? "No Phone",
                          ),
                        ),

                        ListTile(
                          leading: const Icon(Icons.work),
                          title: Text(
                            userData["job"] ?? "No Work",
                          ),
                        ),

                        const Divider(height: 40),

                        // ====================================
                        // RENT
                        // ====================================
                        const Text(
                          "Monthly Rent",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "₱${monthlyRent.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 26,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const Divider(height: 40),

                        // ====================================
                        // ELECTRIC BILL
                        // ====================================
                        const Text(
                          "Electric Billing",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          "Previous Reading: ${room["previousElectric"]}",
                        ),

                        Text(
                          "Current Reading: ${room["currentElectric"]}",
                        ),

                        Text(
                          "Consumption: ${electricConsumption.toStringAsFixed(2)} kWh",
                        ),

                        Text(
                          "Rate per kWh: ₱${electricRate.toStringAsFixed(2)}",
                        ),

                        const SizedBox(height: 10),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${electricConsumption.toStringAsFixed(2)} × ₱${electricRate.toStringAsFixed(2)} = ₱${electricBill.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const Divider(height: 40),

                        // ====================================
                        // WATER BILL
                        // ====================================
                        const Text(
                          "Water Billing",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          "Previous Reading: ${room["previousWater"]}",
                        ),

                        Text(
                          "Current Reading: ${room["currentWater"]}",
                        ),

                        Text(
                          "Consumption: ${waterConsumption.toStringAsFixed(2)} m³",
                        ),

                        Text(
                          "Rate per m³: ₱${waterRate.toStringAsFixed(2)}",
                        ),

                        const SizedBox(height: 10),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${waterConsumption.toStringAsFixed(2)} × ₱${waterRate.toStringAsFixed(2)} = ₱${waterBill.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const Divider(height: 40),

                        // ====================================
                        // MONTHLY ANALYTICS
                        // ====================================
                        const Text(
                          "Monthly Analytics",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 250,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("rooms")
                                .doc(roomDoc.id)
                                .collection("billingHistory")
                                .orderBy("createdAt")
                                .snapshots(),
                            builder: (context, chartSnapshot) {
                              if (!chartSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final docs = chartSnapshot.data!.docs;

                              if (docs.isEmpty) {
                                return const Center(
                                  child: Text(
                                    "No analytics data yet",
                                  ),
                                );
                              }

                              List<FlSpot> electricSpots = [];

                              List<FlSpot> waterSpots = [];

                              for (int i = 0; i < docs.length; i++) {
                                final data =
                                    docs[i].data() as Map<String, dynamic>;

                                electricSpots.add(
                                  FlSpot(
                                    i.toDouble(),
                                    (data["electricConsumption"] ?? 0)
                                        .toDouble(),
                                  ),
                                );

                                waterSpots.add(
                                  FlSpot(
                                    i.toDouble(),
                                    (data["waterConsumption"] ?? 0).toDouble(),
                                  ),
                                );
                              }

                              return LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: true),
                                  borderData: FlBorderData(show: true),
                                  titlesData: FlTitlesData(show: true),
                                  lineBarsData: [
                                    // ELECTRIC
                                    LineChartBarData(
                                      spots: electricSpots,
                                      isCurved: true,
                                      barWidth: 4,
                                      dotData: FlDotData(show: true),
                                      color: Colors.orange,
                                    ),

                                    // WATER
                                    LineChartBarData(
                                      spots: waterSpots,
                                      isCurved: true,
                                      barWidth: 4,
                                      dotData: FlDotData(show: true),
                                      color: Colors.blue,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ====================================
                        // TOTAL BILL
                        // ====================================
                        const Text(
                          "Total Billing Summary",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          "Monthly Rent: ₱${monthlyRent.toStringAsFixed(2)}",
                        ),

                        Text(
                          "Electric Bill: ₱${electricBill.toStringAsFixed(2)}",
                        ),

                        Text(
                          "Water Bill: ₱${waterBill.toStringAsFixed(2)}",
                        ),

                        const SizedBox(height: 15),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "TOTAL BILL",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "₱${totalBill.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 32,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
