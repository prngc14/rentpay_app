import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_requests_screen.dart';
import 'upload_qr_screen.dart';
import 'boarding_screen.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

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
          ? const Center(child: Text("Not logged in"))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var userData = snapshot.data!.data() as Map<String, dynamic>;

                String ownerCode = userData["ownerCode"] ?? "------";
                String name = userData["name"] ?? "Owner";

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 👤 PROFILE
                      Center(
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              child: Icon(Icons.person, size: 40),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🔑 OWNER CODE
                      Card(
                        color: Colors.orange[100],
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text("Your Owner Code"),
                              const SizedBox(height: 10),
                              Text(
                                ownerCode,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // 🔥 TENANTS LIST
                      const Text(
                        "Your Tenants",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 10),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("users")
                            .where("ownerId", isEqualTo: user.uid)
                            .where("role", isEqualTo: "tenant")
                            .snapshots(),
                        builder: (context, tenantSnapshot) {
                          if (!tenantSnapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          var tenants = tenantSnapshot.data!.docs;

                          if (tenants.isEmpty) {
                            return const Text("No tenants yet");
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tenants.length,
                            itemBuilder: (context, index) {
                              var tenant =
                                  tenants[index].data() as Map<String, dynamic>;

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(tenant["name"] ?? "No Name"),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Room: ${tenant["room"] ?? "-"}"),
                                      Text(
                                          "Status: ${tenant["approved"] == true ? "Approved" : "Pending"}"),
                                      Text(
                                          "Payment: ${tenant["paymentStatus"] ?? "unpaid"}"),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 25),

                      // ⚡ ACTION GRID
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
                            () => _showCreateRoomDialog(context, user.uid),
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
                                  builder: (_) => const UploadQRScreen(),
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
                          _buildActionCard(
                            context,
                            "Boarding",
                            Icons.apartment,
                            Colors.purple,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BoardingScreen(),
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
            Icon(icon, color: color, size: 35),
            const SizedBox(height: 10),
            Text(title),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, String ownerId) {
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
              decoration: const InputDecoration(labelText: "Room Number"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Monthly Rent"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (roomController.text.isEmpty || rentController.text.isEmpty)
                return;

              await FirebaseFirestore.instance.collection("rooms").add({
                "roomNumber": roomController.text.trim(),
                "ownerId": ownerId,
                "tenantId": null,
                "monthlyRent": double.tryParse(rentController.text.trim()) ?? 0,
                "createdAt": Timestamp.now(),
              });

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Room created successfully")),
              );
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }
}
