import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
                .where("roomNumber", isEqualTo: roomNumber)
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

              final room =
                  roomSnapshot.data!.docs.first.data() as Map<String, dynamic>;

              return Center(
                child: Card(
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.home,
                          size: 80,
                          color: Colors.deepOrange,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Room ${room['roomNumber']}",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "Monthly Rent: ₱${room['monthlyRent']}",
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
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
