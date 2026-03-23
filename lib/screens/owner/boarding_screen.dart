import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';

class BoardingScreen extends StatelessWidget {
  const BoardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Boarding Tenants"),
        backgroundColor: Colors.deepOrange,
      ),
      body: user == null
          ? const Center(child: Text("Not logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: firestore.getOwnerTenants(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var tenants = snapshot.data!.docs;

                if (tenants.isEmpty) {
                  return const Center(child: Text("No tenants yet"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tenants.length,
                  itemBuilder: (context, index) {
                    var data = tenants[index].data() as Map<String, dynamic>;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      margin: const EdgeInsets.only(bottom: 15),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(Icons.person, size: 40),
                            const SizedBox(height: 10),

                            // 👤 NAME
                            Text(
                              data["name"] ?? "No Name",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 5),

                            // ✅ FIXED HERE (SHOW OWNER CODE)
                            Text(
                              "Owner Code: ${data["ownerCode"] ?? "------"}",
                              style: const TextStyle(color: Colors.grey),
                            ),

                            const SizedBox(height: 10),

                            // 🏠 ROOM
                            Text("Room: ${data["room"] ?? "-"}"),

                            // 📌 STATUS
                            Text(
                              data["approved"] == true
                                  ? "Status: Approved"
                                  : "Status: Pending",
                            ),

                            // 💰 PAYMENT
                            Text(
                              "Payment: ${data["paymentStatus"] ?? "unpaid"}",
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
