import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_colors.dart';

class RoomDetailsScreen extends StatelessWidget {
  // Kailangan na ngayon ang roomId para makapag-listen ng LIVE data
  // mula sa Firestore. Ito yung document ID ng room sa "rooms" collection
  // (hindi yung roomNumber). Kunin mo ito sa .id ng QueryDocumentSnapshot
  // kapag nag-navigate papunta dito mula sa dashboard, hal.:
  //
  //   RoomDetailsScreen(
  //     roomId: roomDoc.id,
  //     roomData: roomDoc.data() as Map<String, dynamic>,
  //     ...
  //   )
  final String roomId;

  // Ginagamit pa rin ito bilang paunang/fallback data (para walang
  // blangko/flicker habang naglo-load pa ang unang snapshot), pero
  // ang live StreamBuilder na sa ibaba ang siyang magiging source of
  // truth pagkatapos noon.
  final Map<String, dynamic> roomData;

  final VoidCallback? onUpdateBilling;
  final VoidCallback? onDeleteRoom;

  const RoomDetailsScreen({
    super.key,
    required this.roomId,
    required this.roomData,
    this.onUpdateBilling,
    this.onDeleteRoom,
  });

  @override
  Widget build(BuildContext context) {
    // Mga kulay na sumusunod sa light/dark mode
    final c = AppColors.of(context);

    // =====================================================
    // LIVE ROOM STREAM
    // =====================================================
    //
    // Dati, static na Map lang (roomData) ang ginagamit dito kaya
    // hindi agad nakikita ang bagong Monthly Rent / billing pagkatapos
    // mag-update -- kailangan pang bumalik at pumasok ulit sa screen.
    //
    // Ngayon, nakikinig na ito nang live sa "rooms/{roomId}" doc, kaya
    // sa sandaling mag-succeed ang updateRoomBilling() sa Firestore,
    // awtomatiko na ring nag-rerebuild ang buong screen na ito -- kasing
    // bilis ng tenant info section na StreamBuilder na rin dati.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("rooms")
          .doc(roomId)
          .snapshots(),
      builder: (context, roomSnapshot) {
        final liveData = roomSnapshot.data?.data() as Map<String, dynamic>?;

        // Gamitin ang live data pagdating nito; bago 'yon, gamitin muna
        // ang roomData na ipinasa papunta rito (para walang blangkong
        // screen habang naglo-load ang unang snapshot).
        final data = liveData ?? roomData;

        final roomNumber = data["roomNumber"];
        final rent = data["monthlyRent"];
        final tenant = data["tenantId"] ?? "No tenant yet";

        return Scaffold(
          // Ang background ay galing sa theme (light: maputla, dark: itim)

          // =====================================================
          // APP BAR
          // =====================================================
          appBar: AppBar(
            title: Text(
              "Room $roomNumber",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.title,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: c.title,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),

          // =====================================================
          // BODY
          // =====================================================
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              20,
            ),
            child: Column(
              children: [
                // =================================================
                // TENANT INFORMATION
                // =================================================
                if (tenant == "No tenant yet")
                  _buildInfoCard(
                    c: c,
                    icon: Icons.person_outline,
                    title: "Tenant Information",
                    value: tenant,
                    color: const Color(0xFF3E8BEA),
                  )
                else
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("users")
                        .doc(tenant.toString())
                        .snapshots(),
                    builder: (context, snapshot) {
                      final tenantData =
                          snapshot.data?.data() as Map<String, dynamic>?;

                      if (tenantData == null) {
                        return _buildInfoCard(
                          c: c,
                          icon: Icons.person_outline,
                          title: "Tenant Information",
                          value: "Loading tenant information...",
                          color: const Color(0xFF3E8BEA),
                        );
                      }

                      return Card(
                        color: c.glass(0.82),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: c.glassBorder(0.9),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            17,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ---------------------------------
                              // TITLE
                              // ---------------------------------
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3E8BEA)
                                          .withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      color: Color(0xFF3E8BEA),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Tenant Information",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: c.title,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // ---------------------------------
                              // TENANT DETAILS
                              // ---------------------------------
                              _buildTenantDetail(
                                c,
                                "Name",
                                tenantData["name"] ?? "No name",
                              ),

                              _buildTenantDetail(
                                c,
                                "Phone",
                                tenantData["phone"] ?? "No phone",
                              ),

                              _buildTenantDetail(
                                c,
                                "Work",
                                tenantData["job"] ?? "No work",
                              ),

                              const SizedBox(height: 12),

                              // ---------------------------------
                              // MONTHLY RENT
                              // ---------------------------------
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF111111).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF111111)
                                        .withOpacity(0.18),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF111111)
                                            .withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "₱",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFE88916),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Monthly Rent",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: c.subtitle,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            "₱$rent",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: c.title,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ---------------------------------
                              // WORK ID
                              // ---------------------------------
                              if ((tenantData["workIdUrl"] ?? "")
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  "Work ID",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: c.subtitle,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    tenantData["workIdUrl"].toString(),
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return Container(
                                        height: 150,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 20),

                // =================================================
                // UPDATE BILLING BUTTON
                // =================================================
                if (onUpdateBilling != null)
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: onUpdateBilling,
                      icon: const Icon(
                        Icons.electric_bolt,
                        size: 17,
                      ),
                      label: const Text(
                        "Update Billing",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.title,
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: c.title.withAlpha(90),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        minimumSize: const Size(150, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                // =================================================
                // DELETE ROOM BUTTON
                // =================================================
                if (onDeleteRoom != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: onDeleteRoom,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 17,
                      ),
                      label: const Text(
                        "Delete Room",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.danger,
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: c.danger.withAlpha(90),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        minimumSize: const Size(150, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // TENANT DETAIL ROW
  // =====================================================

  Widget _buildTenantDetail(
    AppColors c,
    String label,
    dynamic value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              "$label:",
              style: TextStyle(
                fontSize: 13,
                color: c.subtitle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.title,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // REUSABLE INFO CARD
  // =====================================================

  Widget _buildInfoCard({
    required AppColors c,
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      color: c.glass(0.82),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: c.glassBorder(0.9),
        ),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.title,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: c.subtitle,
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
