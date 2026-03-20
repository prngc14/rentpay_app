import 'package:flutter/material.dart';

class RoomDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> roomData;

  const RoomDetailsScreen({
    super.key,
    required this.roomData,
  });

  @override
  Widget build(BuildContext context) {
    final roomNumber = roomData["roomNumber"];
    final rent = roomData["monthlyRent"];
    final tenant = roomData["tenantId"] ?? "No tenant yet";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Room $roomNumber"),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🏠 ROOM HEADER CARD
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.home, size: 60, color: Colors.blue),
                    const SizedBox(height: 10),
                    Text(
                      "Room $roomNumber",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 💰 RENT CARD
            _buildInfoCard(
              icon: Icons.attach_money,
              title: "Monthly Rent",
              value: "₱$rent",
              color: Colors.green,
            ),

            const SizedBox(height: 15),

            // 👤 TENANT CARD
            _buildInfoCard(
              icon: Icons.person,
              title: "Tenant",
              value: tenant,
              color: Colors.deepPurple,
            ),

            const SizedBox(height: 25),

            // ⚡ ACTION BUTTONS (optional but nice)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Assign tenant
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text("Assign Tenant"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Edit room
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 REUSABLE CARD
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
