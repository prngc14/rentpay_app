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
              final roomDoc = rooms[index];
              final room = roomDoc.data() as Map<String, dynamic>;

              final tenantId = room['tenantId'];

              return Card(
                margin: const EdgeInsets.all(10),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: Text(
                          "Room ${room['roomNumber']}",
                        ),
                        subtitle: Text(
                          "Monthly Rent: ₱${room['monthlyRent']}",
                        ),
                        trailing: tenantId == null
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

                      // ===============================
                      // TENANT INFO
                      // ===============================
                      if (tenantId != null)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection("users")
                              .doc(tenantId)
                              .get(),
                          builder: (context, tenantSnapshot) {
                            if (!tenantSnapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(),
                              );
                            }

                            final tenantData = tenantSnapshot.data!.data()
                                as Map<String, dynamic>?;

                            if (tenantData == null) {
                              return const SizedBox();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),

                                const SizedBox(height: 10),

                                const Text(
                                  "Tenant Information",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Text(
                                  "Name: ${tenantData["name"] ?? ""}",
                                ),

                                Text(
                                  "Job: ${tenantData["job"] ?? ""}",
                                ),

                                Text(
                                  "Phone: ${tenantData["phone"] ?? ""}",
                                ),

                                const SizedBox(height: 15),

                                // ===============================
                                // WORK ID IMAGE
                                // ===============================
                                if (tenantData["workIdUrl"] != null)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Tenant Work ID",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => Dialog(
                                              child: InteractiveViewer(
                                                child: Image.network(
                                                  tenantData["workIdUrl"],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Image.network(
                                            tenantData["workIdUrl"],
                                            height: 200,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 15),
                              ],
                            );
                          },
                        ),

                      const SizedBox(height: 10),

                      // ===============================
                      // DELETE BUTTON
                      // ===============================
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text("Delete Room"),
                                  content: const Text(
                                    "Are you sure you want to delete this room?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(
                                          context,
                                          false,
                                        );
                                      },
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(
                                          context,
                                          true,
                                        );
                                      },
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              await FirebaseFirestore.instance
                                  .collection('rooms')
                                  .doc(roomDoc.id)
                                  .delete();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Room deleted successfully",
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text("Delete Room"),
                        ),
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
