import 'dart:math';

import 'owner_rooms_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'payment_requests_screen.dart';
import 'upload_qr_screen.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  @override
  void initState() {
    super.initState();

    generateOwnerCode();
  }

  // =========================================
  // GENERATE 6 DIGIT OWNER CODE
  // =========================================
  Future<void> generateOwnerCode() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final data = doc.data();

    // IF NO OWNER CODE YET
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
                      // =========================
                      // PROFILE
                      // =========================
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
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              "Owner Code",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  15,
                                ),
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

                      // =========================
                      // TENANT INFORMATION BOX
                      // =========================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(
                          18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            18,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                0.08,
                              ),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.badge,
                              size: 40,
                              color: Colors.deepOrange,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Tenant Verification",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "View uploaded tenant valid IDs",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                              ),
                              onPressed: () {
                                _showTenantsDialog(
                                  context,
                                  user.uid,
                                );
                              },
                              icon: const Icon(
                                Icons.visibility,
                              ),
                              label: const Text(
                                "View IDs",
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // =========================
                      // ACTION GRID
                      // =========================
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
  // SHOW TENANTS
  // =====================================================
  void _showTenantsDialog(
    BuildContext context,
    String ownerId,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Tenant Verification"),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .where(
                    "ownerId",
                    isEqualTo: ownerId,
                  )
                  .where(
                    "role",
                    isEqualTo: "tenant",
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No tenants found"),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final tenant = snapshot.data!.docs[index];

                    final data = tenant.data() as Map<String, dynamic>;

                    String name = data["name"] ?? "No Name";

                    String job = data["job"] ?? "No Work";

                    String phone = data["phone"] ?? "No Phone";

                    String room = data["room"] ?? "No Room";

                    String image = data["workIdUrl"] ?? "";

                    return Card(
                      margin: const EdgeInsets.only(
                        bottom: 15,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) {
                                    return Dialog(
                                      child: InteractiveViewer(
                                        child: Image.network(
                                          image,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                height: 180,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  image: image.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            image,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: image.isEmpty
                                    ? const Center(
                                        child: Icon(
                                          Icons.image,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text("Job: $job"),
                            Text("Phone: $phone"),
                            Text("Room: $room"),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
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

              await FirebaseFirestore.instance.collection("rooms").add({
                "roomNumber": roomController.text.trim(),
                "ownerId": ownerId,
                "tenantId": null,
                "monthlyRent": double.tryParse(
                      rentController.text.trim(),
                    ) ??
                    0,
                "createdAt": Timestamp.now(),
              });

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
