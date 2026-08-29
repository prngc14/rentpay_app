import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingPaymentScreen extends StatelessWidget {
  final String paymentId;
  final String tenantId;
  final VoidCallback onContinue;
  final VoidCallback onSubmitNew;

  const PendingPaymentScreen({
    super.key,
    required this.paymentId,
    required this.tenantId,
    required this.onContinue,
    required this.onSubmitNew,
  });

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Status"),
        backgroundColor: Colors.deepOrange,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("payments")
            .doc(paymentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildRejected(
              context,
              "Hindi na ma-access ang payment record na ito "
              "(maaaring na-delete na). Pindutin sa ibaba para "
              "makabalik sa normal na payment screen.",
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return _buildRejected(context, "Payment record not found.");
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String status = data["status"] ?? "pending";
          final bool isPartial = data["isPartial"] ?? false;

          if (status == "verified") {
            return isPartial
                ? _buildPartialApproved(context)
                : _buildApproved(context);
          } else if (status == "rejected") {
            return _buildRejected(context, null);
          }

          return _buildPending(context);
        },
      ),
    );
  }

  Widget _buildPending(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top, color: Colors.orange, size: 72),
            const SizedBox(height: 20),
            const Text(
              "Payment Submitted",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Your payment screenshot has been sent successfully.\nPlease wait for the owner to review and accept it.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "STATUS: PENDING REVIEW",
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApproved(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 20),
            const Text(
              "Payment Approved!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Your payment has been reviewed and accepted by the owner.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Continue to Dashboard"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartialApproved(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt, color: Colors.blue, size: 72),
            const SizedBox(height: 20),
            const Text(
              "Partial Payment Accepted!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Your partial payment has been reviewed and accepted by the owner.\nYou may check your remaining balance on the dashboard.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "STATUS: PARTIAL PAYMENT",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Go to Dashboard"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejected(BuildContext context, String? overrideMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 72),
            const SizedBox(height: 20),
            const Text(
              "Payment Rejected",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              overrideMessage ??
                  "Your payment could not be verified.\nPlease submit a new payment screenshot.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSubmitNew,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Submit New Payment"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}