import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';

class OwnerRoomsScreen extends StatefulWidget {
  final String ownerId;

  const OwnerRoomsScreen({
    super.key,
    required this.ownerId,
  });

  @override
  State<OwnerRoomsScreen> createState() => _OwnerRoomsScreenState();
}

class _OwnerRoomsScreenState extends State<OwnerRoomsScreen> {
  final firestore = FirestoreService();

  // ======================================
  // SHOW BILLING DIALOG
  // ======================================
  void showBillingDialog(
    String roomId,
    Map<String, dynamic> room,
  ) {
    final prevElectricController = TextEditingController(
      text: room["previousElectric"].toString(),
    );

    final currentElectricController = TextEditingController(
      text: room["currentElectric"].toString(),
    );

    final prevWaterController = TextEditingController(
      text: room["previousWater"].toString(),
    );

    final currentWaterController = TextEditingController(
      text: room["currentWater"].toString(),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Billing"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Electric Meter",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: prevElectricController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Previous Electric Reading",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: currentElectricController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Current Electric Reading",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Water Meter",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: prevWaterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Previous Water Reading",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: currentWaterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Current Water Reading",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
            ),
            onPressed: () async {
              double previousElectric = double.tryParse(
                    prevElectricController.text,
                  ) ??
                  0;

              double currentElectric = double.tryParse(
                    currentElectricController.text,
                  ) ??
                  0;

              double previousWater = double.tryParse(
                    prevWaterController.text,
                  ) ??
                  0;

              double currentWater = double.tryParse(
                    currentWaterController.text,
                  ) ??
                  0;

              await firestore.updateRoomBilling(
                roomId: roomId,
                previousElectric: previousElectric,
                currentElectric: currentElectric,
                previousWater: previousWater,
                currentWater: currentWater,
              );

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Billing updated successfully",
                  ),
                ),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ======================================
  // FORMAT DATE
  // ======================================
  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return "Not yet paid";
    }

    DateTime dt = timestamp.toDate();

    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
        "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Rooms"),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getOwnerRooms(widget.ownerId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final rooms = snapshot.data!.docs;

          if (rooms.isEmpty) {
            return const Center(
              child: Text("No rooms created"),
            );
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final roomDoc = rooms[index];

              final room = roomDoc.data() as Map<String, dynamic>;

              final tenantId = room["tenantId"];

              String paymentStatus = room["paymentStatus"] ?? "unpaid";

              Timestamp? paidAt = room["paidAt"];

              return Card(
                margin: const EdgeInsets.all(10),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: Text(
                          "Room ${room["roomNumber"]}",
                        ),
                        subtitle: Text(
                          "Monthly Rent: ₱${room["monthlyRent"]}",
                        ),
                        trailing: tenantId == null
                            ? const Text(
                                "Available",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : const Text(
                                "Occupied",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),

                      const Divider(),

                      // ======================================
                      // TENANT INFORMATION
                      // ======================================
                      if (tenantId != null)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection("users")
                              .doc(tenantId)
                              .get(),
                          builder: (context, tenantSnapshot) {
                            if (!tenantSnapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(),
                              );
                            }

                            final tenantData = tenantSnapshot.data!.data()
                                as Map<String, dynamic>?;

                            if (tenantData == null) {
                              return const SizedBox();
                            }

                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(
                                bottom: 15,
                              ),
                              padding: const EdgeInsets.all(
                                15,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(
                                  15,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Tenant Information",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 15,
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Text(
                                          tenantData["name"] ?? "No Name",
                                          style: const TextStyle(
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone,
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Text(
                                          tenantData["phone"] ?? "No Phone",
                                          style: const TextStyle(
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.work,
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Text(
                                          tenantData["job"] ?? "No Work",
                                          style: const TextStyle(
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      // ======================================
                      // BILLING INFO
                      // ======================================
                      const Text(
                        "Utility Billing",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Electric Consumption: ${room["electricConsumption"] ?? 0} kWh",
                      ),

                      Text(
                        "Electric Bill: ₱${room["electricBill"] ?? 0}",
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Water Consumption: ${room["waterConsumption"] ?? 0} m³",
                      ),

                      Text(
                        "Water Bill: ₱${room["waterBill"] ?? 0}",
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "TOTAL BILL: ₱${room["totalBill"] ?? 0}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // ======================================
                      // PAYMENT STATUS
                      // ======================================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: paymentStatus == "paid"
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paymentStatus == "paid" ? "PAID" : "UNPAID",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: paymentStatus == "paid"
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Payment Date: ${formatDate(paidAt)}",
                              style: const TextStyle(
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // ======================================
                      // UPDATE BILLING BUTTON
                      // ======================================
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            showBillingDialog(
                              roomDoc.id,
                              room,
                            );
                          },
                          icon: const Icon(
                            Icons.electric_bolt,
                          ),
                          label: const Text(
                            "Update Billing",
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ======================================
                      // DELETE ROOM
                      // ======================================
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text(
                                    "Delete Room",
                                  ),
                                  content: const Text(
                                    "Are you sure you want to delete this room?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(
                                          context,
                                          false,
                                        );
                                      },
                                      child: const Text(
                                        "Cancel",
                                      ),
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
                                      child: const Text(
                                        "Delete",
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              await FirebaseFirestore.instance
                                  .collection("rooms")
                                  .doc(roomDoc.id)
                                  .delete();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Room deleted successfully",
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.delete,
                          ),
                          label: const Text(
                            "Delete Room",
                          ),
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
