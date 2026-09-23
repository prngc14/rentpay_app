import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/app_warning_banner.dart';
import '../../widgets/rentpay_backdrop.dart';
import '../../widgets/rentpay_glass_panel.dart';
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

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _textPrimary =>
      _isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);

  Color get _textSecondary =>
      _isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);

  Color get _fieldFill =>
      _isDark ? Colors.white.withOpacity(0.06) : Colors.white;

  Color get _fieldBorder =>
      _isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFDCE6EA);

  // -------------------------------------------------
  // CONNECT OWNER
  // -------------------------------------------------
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
      debugPrint("CONNECT ERROR: $e");

      if (!mounted) return;
      showAppWarningBanner(context, friendlyAuthError(e));
    }

    setState(() => loading = false);
  }

  // -------------------------------------------------
  // ASSIGN ROOM
  // -------------------------------------------------
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
      debugPrint("ROOM ASSIGN ERROR: $e");

      if (!mounted) return;
      showAppWarningBanner(context, friendlyAuthError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textPrimary),
        title: Text(
          "Connect to Owner",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RentPayBackdrop(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top > 0 ? 8 : 16,
              16,
              16,
            ),
            child: Column(
              children: [
                const SizedBox(height: 28),

                // OWNER CODE PANEL
                RentpayGlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RentpayPanelHeader(
                        icon: Icons.key_rounded,
                        title: "Owner Code",
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: _textPrimary),
                        decoration: InputDecoration(
                          hintText: "Enter 6-digit owner code",
                          hintStyle: TextStyle(color: _textSecondary),
                          filled: true,
                          fillColor: _fieldFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _fieldBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF111111),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : connectToOwner,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111111),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Text(
                                  "Find Rooms",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // AVAILABLE ROOMS
                if (availableRooms.isNotEmpty)
                  Expanded(
                    child: RentpayGlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const RentpayPanelHeader(
                            icon: Icons.meeting_room_rounded,
                            title: "Available Rooms",
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.separated(
                              itemCount: availableRooms.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final room = availableRooms[index].data()
                                    as Map<String, dynamic>;

                                final bool occupied =
                                    room["tenantId"] != null &&
                                        room["tenantId"].toString().isNotEmpty;

                                final bool isSelected =
                                    selectedRoom == availableRooms[index].id;

                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: occupied
                                      ? null
                                      : () {
                                          setState(() {
                                            selectedRoom =
                                                availableRooms[index].id;
                                          });
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF111111).withOpacity(
                                              _isDark ? 0.18 : 0.10)
                                          : (_isDark
                                              ? Colors.white.withOpacity(0.04)
                                              : Colors.white),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF111111)
                                            : _fieldBorder,
                                        width: isSelected ? 1.6 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons
                                                  .radio_button_checked_rounded
                                              : Icons
                                                  .radio_button_unchecked_rounded,
                                          color: isSelected
                                              ? const Color(0xFF111111)
                                              : _textSecondary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Room ${room["roomNumber"]}",
                                                style: TextStyle(
                                                  color: _textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                "Rent: ₱${room["monthlyRent"]}",
                                                style: TextStyle(
                                                  color: _textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: occupied
                                                ? const Color(0xFFE93636)
                                                    .withOpacity(0.14)
                                                : const Color(0xFF22C55E)
                                                    .withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            occupied ? "Occupied" : "Available",
                                            style: TextStyle(
                                              color: occupied
                                                  ? const Color(0xFFE93636)
                                                  : const Color(0xFF22C55E),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: assignRoom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF111111),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Connect Room",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
