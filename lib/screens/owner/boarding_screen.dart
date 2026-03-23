import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ ADD THIS

import '../../services/firestore_service.dart';

class BoardingScreen extends StatelessWidget {
  const BoardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // ✅ FIXED
    final firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Boarding Tenants"),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getOwnerTenants(user!.uid),
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
              var data = tenants[index];

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.person, size: 40),
                      const SizedBox(height: 10),

                      // NAME
                      Text(
                        data["name"] ?? "",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      // OWNER ID
                      Text(
                        "Owner ID: ${data["ownerId"]}",
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 10),

                      Text("Room: ${data["room"]}"),
                      Text(
                        data["approved"] == true
                            ? "Status: Approved"
                            : "Status: Pending",
                      ),
                      Text("Payment: ${data["paymentStatus"]}"),
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
