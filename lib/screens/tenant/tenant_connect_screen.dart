import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/app_warning_banner.dart';
import 'tenant_dashboard.dart';

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

  
  // CONNECT OWNER
 
  Future<void> connectToOwner() async {
    String code = codeController.text.trim();

    if (code.isEmpty) {
      showAppWarningBanner(context, "Enter owner code");
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

     
      // GET ROOMS
      
      final roomQuery = await FirebaseFirestore.instance
          .collection("rooms")
          .where("ownerId", isEqualTo: ownerId)
          .get();

      
      // FILTER AVAILABLE ROOMS ONLY
     
      availableRooms = roomQuery.docs.where((roomDoc) {
        final data = roomDoc.data();

        // AVAILABLE
        if (data["tenantId"] == null) {
          return true;
        }

        if (data["tenantId"].toString().isEmpty) {
          return true;
        }

        // OCCUPIED
        return false;
      }).toList();

      if (availableRooms.isEmpty) {
        throw "No available rooms";
      }

      setState(() {});
    } catch (e) {
      print("CONNECT ERROR: $e");

      if (!mounted) return;
      showAppWarningBanner(context, friendlyAuthError(e));
    }

    setState(() => loading = false);
  }


  // ASSIGN ROOM
  Future<void> assignRoom() async {
    if (selectedRoom == null) {
      showAppWarningBanner(context, "Select a room");
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final roomDoc = availableRooms.firstWhere(
        (room) => room.id == selectedRoom,
      );

      final roomData = roomDoc.data() as Map<String, dynamic>;

      // CHECK AGAIN IF OCCUPIED
      if (roomData["tenantId"] != null &&
          roomData["tenantId"].toString().isNotEmpty) {
        throw "Room already occupied";
      }

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

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TenantDashboard(showConnectionSuccess: true),
        ),
      );
    } catch (e) {
      print("ROOM ASSIGN ERROR: $e");

      if (!mounted) return;
      showAppWarningBanner(context, friendlyAuthError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connect to Owner"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Container(
        color: const Color(0xFFFFF8FC),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // OWNER CODE
            TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Owner Code",
                  hintText: "Enter 6-digit owner code",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Colors.deepOrange,
                      width: 2,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // FIND ROOMS BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : connectToOwner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Find Rooms"),
              ),
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
                        fontSize: 22,
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

                          final bool occupied = room["tenantId"] != null &&
                              room["tenantId"].toString().isNotEmpty;

                          return Card(
                            elevation: 1,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: RadioListTile(
                              value: availableRooms[index].id,
                              groupValue: selectedRoom,
                              onChanged: occupied
                                  ? null
                                  : (value) {
                                      setState(() {
                                        selectedRoom = value.toString();
                                      });
                                    },
                              title: Text(
                                "Room ${room["roomNumber"]}",
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Rent: ₱${room["monthlyRent"]}",
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    occupied ? "Occupied" : "Available",
                                    style: TextStyle(
                                      color:
                                          occupied ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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