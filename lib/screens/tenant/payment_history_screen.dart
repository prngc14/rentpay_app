import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String tenantId = FirebaseAuth.instance.currentUser!.uid;
    FirestoreService firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment History"),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getTenantPayments(tenantId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var payments = snapshot.data!.docs;

          if (payments.isEmpty) {
            return const Center(child: Text("No payments yet"));
          }

          return ListView.builder(
            itemCount: payments.length,
            itemBuilder: (context, index) {
              var doc = payments[index];
              var data = doc.data() as Map<String, dynamic>;

              String status = data["status"] ?? "pending";
              double amount = (data["amount"] ?? 0).toDouble();

              Timestamp? timestamp = data["date"];
              String date =
                  timestamp != null ? timestamp.toDate().toString() : "No date";

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.payment),
                  title: Text("₱$amount"),
                  subtitle: Text(date),
                  trailing: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color:
                          status == "verified" ? Colors.green : Colors.orange,
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
