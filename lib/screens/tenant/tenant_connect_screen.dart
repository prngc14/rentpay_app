import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TenantConnectScreen extends StatefulWidget {
  const TenantConnectScreen({super.key});

  @override
  State<TenantConnectScreen> createState() => _TenantConnectScreenState();
}

class _TenantConnectScreenState extends State<TenantConnectScreen> {
  final TextEditingController codeController = TextEditingController();

  bool loading = false;

  List<QueryDocumentSnapshot> availableRooms = [];

  String? selectedRoom;
  String? ownerId;

  // =========================
  // CONNECT OWNER
  // =========================
  Future<void> connectToOwner() async {
    String code = codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter owner code"),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // FIND OWNER
      final query = await FirebaseFirestore.instance
          .collection("users")
          .where("ownerCode", isEqualTo: code)
          .where("role", isEqualTo: "owner")
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw "Owner not found";
      }

      final ownerDoc = query.docs.first;

      ownerId = ownerDoc.id;

      // GET AVAILABLE ROOMS
      final roomQuery = await FirebaseFirestore.instance
          .collection("rooms")
          .where("ownerId", isEqualTo: ownerId)
          .where("tenantId", isEqualTo: null)
          .get();

      availableRooms = roomQuery.docs;

      if (availableRooms.isEmpty) {
        throw "No available rooms";
      }

      setState(() {});
    } catch (e) {
      print("CONNECT ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$e"),
        ),
      );
    }

    setState(() => loading = false);
  }

  // =========================
  // ASSIGN ROOM
  // =========================
  Future<void> assignRoom() async {
    if (selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select a room"),
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final roomDoc = availableRooms.firstWhere(
        (room) => room.id == selectedRoom,
      );

      final roomData = roomDoc.data() as Map<String, dynamic>;

      // UPDATE ROOM
      await FirebaseFirestore.instance
          .collection("rooms")
          .doc(roomDoc.id)
          .update({
        "tenantId": user.uid,
      });

      // UPDATE USER
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({
        "ownerId": ownerId,
        "ownerCode": codeController.text.trim(),
        "room": roomData["roomNumber"],
        "approved": true,
        "connected": true,
        "paymentStatus": "unpaid",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Room connected successfully!",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print("ROOM ASSIGN ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$e"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connect to Owner"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // OWNER CODE
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter 6-digit owner code",
              ),
            ),

            const SizedBox(height: 20),

            // CONNECT BUTTON
            ElevatedButton(
              onPressed: loading ? null : connectToOwner,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              child: loading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Text("Find Rooms"),
            ),

            const SizedBox(height: 30),

            // AVAILABLE ROOMS
            if (availableRooms.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      "Available Rooms",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: availableRooms.length,
                        itemBuilder: (context, index) {
                          final room = availableRooms[index].data()
                              as Map<String, dynamic>;

                          return Card(
                            child: RadioListTile(
                              value: availableRooms[index].id,
                              groupValue: selectedRoom,
                              onChanged: (value) {
                                setState(() {
                                  selectedRoom = value.toString();
                                });
                              },
                              title: Text(
                                "Room ${room["roomNumber"]}",
                              ),
                              subtitle: Text(
                                "Rent: ₱${room["monthlyRent"]}",
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: assignRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                        ),
                        child: const Text(
                          "Connect Room",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
