import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';

class OwnerRoomsScreen extends StatelessWidget {
  final String ownerId;

  const OwnerRoomsScreen({
    super.key,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Rooms"),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getOwnerRooms(ownerId),
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
              final room = rooms[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.home),
                  title: Text(
                    "Room ${room['roomNumber']}",
                  ),
                  subtitle: Text(
                    "Monthly Rent: ₱${room['monthlyRent']}",
                  ),
                  trailing: room['tenantId'] == null
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
              );
            },
          );
        },
      ),
    );
  }
}
