import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../widgets/app_warning_banner.dart';
import 'room_details_screen.dart';

// Clean, simple fade-only transition -- walang slide/position shift,
// para hindi na gamitin ang default Android "shared axis" transition.
Route<T> _fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 180),
  );
}

class OwnerRoomsScreen extends StatefulWidget {
  final String ownerId;

  const OwnerRoomsScreen({
    super.key,
    required this.ownerId,
  });

  @override
  State<OwnerRoomsScreen> createState() => _OwnerRoomsScreenState();
}

class _OwnerRoomsScreenState extends State<OwnerRoomsScreen> {
  final firestore = FirestoreService();

  // =====================================================
  // SHOW BILLING DIALOG
  // =====================================================

  void showBillingDialog(
    String roomId,
    Map<String, dynamic> room,
  ) {
    final rentController = TextEditingController(
      text: (room["monthlyRent"] ?? 0).toString(),
    );

    final prevElectricController = TextEditingController(
      text: (room["previousElectric"] ?? 0).toString(),
    );

    final currentElectricController = TextEditingController(
      text: (room["currentElectric"] ?? 0).toString(),
    );

    final prevWaterController = TextEditingController(
      text: (room["previousWater"] ?? 0).toString(),
    );

    final currentWaterController = TextEditingController(
      text: (room["currentWater"] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Billing"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Monthly Rent",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: rentController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Monthly Rent",
                  prefixText: "₱ ",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Electric Meter",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: prevElectricController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Previous Electric Reading",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: currentElectricController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Current Electric Reading",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Water Meter",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: prevWaterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Previous Water Reading",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: currentWaterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Current Water Reading",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),

        // =================================================
        // ACTION BUTTONS
        // =================================================

        actions: [
          // CANCEL
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: Color(0xFF123E5A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // SAVE
          TextButton(
            onPressed: () async {
              double monthlyRent = double.tryParse(
                    rentController.text,
                  ) ??
                  (room["monthlyRent"] as num).toDouble();

              double previousElectric = double.tryParse(
                    prevElectricController.text,
                  ) ??
                  0;

              double currentElectric = double.tryParse(
                    currentElectricController.text,
                  ) ??
                  0;

              double previousWater = double.tryParse(
                    prevWaterController.text,
                  ) ??
                  0;

              double currentWater = double.tryParse(
                    currentWaterController.text,
                  ) ??
                  0;

              await firestore.updateRoomBilling(
                roomId: roomId,
                monthlyRent: monthlyRent,
                previousElectric: previousElectric,
                currentElectric: currentElectric,
                previousWater: previousWater,
                currentWater: currentWater,
              );

              if (!mounted) return;

              Navigator.pop(context);

              showAppSuccessBanner(
                context,
                "Billing updated successfully",
              );
            },
            child: const Text(
              "Save",
              style: TextStyle(
                color: Color(0xFF123E5A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Rentpay",
          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: Color(0xFF123E5A),
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF123E5A),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getOwnerRooms(widget.ownerId),
        builder: (context, snapshot) {
          // Ipakita ang aktwal na error sa halip na
          // infinite loading kung mag-error ang stream.
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "ERROR: ${snapshot.error}",
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // =================================================
          // GET ROOMS
          // =================================================

          final rooms = snapshot.data!.docs.toList();

          if (rooms.isEmpty) {
            return const Center(
              child: Text("No rooms created"),
            );
          }

          // =================================================
          // SORT ROOMS NUMERICALLY
          // =================================================
          //
          // Example:
          // Room 1
          // Room 2
          // Room 3
          // ...
          // Room 9
          // Room 10
          //
          // Hindi naka-base sa Occupied/Available.
          // Hindi rin naka-base sa Firebase creation order.
          // =================================================

          rooms.sort((a, b) {
            final roomA =
                (a.data() as Map<String, dynamic>)["roomNumber"];

            final roomB =
                (b.data() as Map<String, dynamic>)["roomNumber"];

            final numberA =
                int.tryParse(roomA.toString()) ?? 0;

            final numberB =
                int.tryParse(roomB.toString()) ?? 0;

            return numberA.compareTo(numberB);
          });

          // =================================================
          // ROOM LIST
          // =================================================

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final roomDoc = rooms[index];

              final room =
                  roomDoc.data() as Map<String, dynamic>;

              return _buildCompactRoomCard(
                context,
                roomDoc.id,
                room,
              );
            },
          );
        },
      ),
    );
  }

  // =====================================================
  // ROOM CARD
  // =====================================================

  Widget _buildCompactRoomCard(
    BuildContext context,
    String roomId,
    Map<String, dynamic> room,
  ) {
    final tenantId = room["tenantId"]?.toString() ?? "";
    final isOccupied = tenantId.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      elevation: 0,
      color: Colors.white.withOpacity(0.78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.white.withOpacity(0.8),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),

        leading: const CircleAvatar(
          backgroundColor: Color(0x1AE88916),
          child: Icon(
            Icons.home_work_outlined,
            color: Color(0xFFE88916),
          ),
        ),

        title: Text(
          "Room ${room["roomNumber"]}",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF123E5A),
          ),
        ),

        subtitle: Text(
          "Monthly Rent: ₱${room["monthlyRent"]}",
          style: const TextStyle(
            color: Color(0xFF587287),
          ),
        ),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOccupied ? "Occupied" : "Available",
              style: TextStyle(
                color: isOccupied
                    ? const Color(0xFFE88916)
                    : const Color(0xFF1EBA63),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF587287),
            ),
          ],
        ),

        onTap: () {
          Navigator.push(
            context,
            _fadeRoute(
              RoomDetailsScreen(
                roomData: {
                  ...room,
                  "roomId": roomId,
                },

                onUpdateBilling: () =>
                    showBillingDialog(
                  roomId,
                  room,
                ),

                onDeleteRoom: () async {
                  final confirmed =
                      await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) =>
                        AlertDialog(
                      title: const Text(
                        "Delete Room",
                      ),
                      content: const Text(
                        "Are you sure you want to delete this room?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(
                            dialogContext,
                            false,
                          ),
                          child: const Text(
                            "Cancel",
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(
                            dialogContext,
                            true,
                          ),
                          child: const Text(
                            "Delete",
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed != true) return;

                  await FirebaseFirestore.instance
                      .collection("rooms")
                      .doc(roomId)
                      .delete();

                  if (!context.mounted) return;

                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}