import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OwnerNotificationButton extends StatelessWidget {
  final String ownerId;
  final VoidCallback? onPressed;

  const OwnerNotificationButton({
    super.key,
    required this.ownerId,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("payments")
          .where("ownerId", isEqualTo: ownerId)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.where((payment) {
              final data = payment.data() as Map<String, dynamic>;
              return (data["status"] ?? "pending") == "pending";
            }).length ??
            0;

        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onPressed,
            child: Badge(
              isLabelVisible: count > 0,
              label: Text(count > 9 ? "9+" : "$count"),
              backgroundColor: const Color(0xFFE93636),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0x66FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications,
                  color: Color(0xFF123E5A),
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
