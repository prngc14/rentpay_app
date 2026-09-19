import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> roomData;
  final VoidCallback? onUpdateBilling;
  final VoidCallback? onDeleteRoom;

  const RoomDetailsScreen({
    super.key,
    required this.roomData,
    this.onUpdateBilling,
    this.onDeleteRoom,
  });

  @override
  Widget build(BuildContext context) {
    final roomNumber = roomData["roomNumber"];
    final rent = roomData["monthlyRent"];
    final tenant = roomData["tenantId"] ?? "No tenant yet";

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8FA),

      // =====================================================
      // APP BAR
      // =====================================================
      appBar: AppBar(
        title: Text(
          "Room $roomNumber",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF123E5A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF123E5A),
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
                  final data =
                      snapshot.data?.data()
                          as Map<String, dynamic>?;

                  if (data == null) {
                    return _buildInfoCard(
                      icon: Icons.person_outline,
                      title: "Tenant Information",
                      value:
                          "Loading tenant information...",
                      color: const Color(0xFF3E8BEA),
                    );
                  }

                  return Card(
                    color: Colors.white.withOpacity(0.82),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.9),
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
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
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
                              const Text(
                                "Tenant Information",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF123E5A),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ---------------------------------
                          // TENANT DETAILS
                          // ---------------------------------
                          _buildTenantDetail(
                            "Name",
                            data["name"] ?? "No name",
                          ),

                          _buildTenantDetail(
                            "Phone",
                            data["phone"] ?? "No phone",
                          ),

                          _buildTenantDetail(
                            "Work",
                            data["job"] ?? "No work",
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
                              color: const Color(0xFFFFA02E)
                                  .withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFA02E)
                                    .withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFA02E)
                                        .withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "₱",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight:
                                            FontWeight.w800,
                                        color:
                                            Color(0xFFE88916),
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
                                      const Text(
                                        "Monthly Rent",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              Color(0xFF587287),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        "₱$rent",
                                        style:
                                            const TextStyle(
                                          fontSize: 18,
                                          fontWeight:
                                              FontWeight.w800,
                                          color:
                                              Color(0xFF123E5A),
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
                          if ((data["workIdUrl"] ?? "")
                              .toString()
                              .isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text(
                              "Work ID",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF587287),
                              ),
                            ),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(12),
                              child: Image.network(
                                data["workIdUrl"].toString(),
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) {
                                  return Container(
                                    height: 150,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey
                                          .withOpacity(0.08),
                                      borderRadius:
                                          BorderRadius.circular(
                                        12,
                                      ),
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
                    foregroundColor:
                        const Color(0xFF123E5A),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: const Color(0xFF123E5A)
                          .withOpacity(0.35),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    minimumSize: const Size(150, 36),
                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
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
                    foregroundColor:
                        const Color(0xFFD93636),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: const Color(0xFFD93636)
                          .withOpacity(0.35),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    minimumSize: const Size(150, 36),
                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =====================================================
  // TENANT DETAIL ROW
  // =====================================================

  Widget _buildTenantDetail(
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
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF587287),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF123E5A),
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
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.82),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.white.withOpacity(0.9),
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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF123E5A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF587287),
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