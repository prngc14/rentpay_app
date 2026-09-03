import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_warning_banner.dart'; // <-- ayusin ang path kung iba ang location 

class TenantContractsScreen extends StatefulWidget {
  const TenantContractsScreen({super.key});

  @override
  State<TenantContractsScreen> createState() => _TenantContractsScreenState();
}

class _TenantContractsScreenState extends State<TenantContractsScreen> {
  final List<Offset> _signaturePoints = [];
  bool _isSavingSignature = false;

  // ✅ ADDED: "Renewed"
  static const List<String> _inactiveStatuses = [
    'Expired',
    'Cancelled',
    'Terminated',
    'Renewed',
  ];

  final Map<String, String> _ownerCodeCache = {};

  Future<String> _getOwnerCode(String ownerId) async {
    if (ownerId.isEmpty) return "--";

    if (_ownerCodeCache.containsKey(ownerId)) {
      return _ownerCodeCache[ownerId]!;
    }

    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(ownerId)
          .get();

      final data = ownerDoc.data();
      final ownerCode = (data?["ownerCode"] as String?) ?? "--";

      _ownerCodeCache[ownerId] = ownerCode;
      return ownerCode;
    } catch (e) {
      return "--";
    }
  }

  Future<void> _saveSignature(String contractId) async {
    if (_signaturePoints.isEmpty) {
      showAppWarningBanner(context, "Please sign the contract first.");
      return;
    }

    setState(() {
      _isSavingSignature = true;
    });

    try {
      final contractDoc = await FirebaseFirestore.instance
          .collection("contracts")
          .doc(contractId)
          .get();

      final contractData = contractDoc.data();
      final currentStatus = contractData?['status'] ?? 'Pending Signature';
      final isLocked = contractData?['signatureLocked'] == true ||
          currentStatus == 'Sent to Owner';

      if (isLocked) {
        if (mounted) {
          showAppWarningBanner(context,
              "This signature is already locked and cannot be changed.");
        }
        return;
      }

      final signatureData = _signaturePoints
          .map((point) => {
                "x": point.dx,
                "y": point.dy,
              })
          .toList();

      await FirebaseFirestore.instance
          .collection("contracts")
          .doc(contractId)
          .update({
        "tenantSignature": signatureData,
        "status": "Signed by Tenant",
        "tenantSignedAt": Timestamp.now(),
      });

      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        showAppSuccessBanner(context, "Signature saved successfully.");
      }
    } catch (e) {
      if (mounted) {
        showAppWarningBanner(context, friendlyAuthError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSignature = false;
          _signaturePoints.clear();
        });
      }
    }
  }

  Future<void> _sendToOwner(String contractId) async {
    await FirebaseFirestore.instance
        .collection("contracts")
        .doc(contractId)
        .update({
      "status": "Sent to Owner",
      "signatureLocked": true,
      "tenantSentAt": Timestamp.now(),
    });

    if (mounted) {
      showAppSuccessBanner(context, "Contract sent to owner.");
    }
  }

  void _showSignatureDialog({
    required String contractId,
    required String roomNumber,
  }) {
    _signaturePoints.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text("E-Sign Contract"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Room: $roomNumber"),
                    const SizedBox(height: 12),
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.deepOrange,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Text(
                              "Tenant Signature",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: GestureDetector(
                              onPanStart: (details) {
                                setDialogState(() {
                                  _signaturePoints.add(details.localPosition);
                                });
                              },
                              onPanUpdate: (details) {
                                setDialogState(() {
                                  _signaturePoints.add(details.localPosition);
                                });
                              },
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: SignaturePainter(_signaturePoints),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                _signaturePoints.clear();
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text("Clear"),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isSavingSignature
                                ? null
                                : () => _saveSignature(contractId),
                            icon: const Icon(Icons.check),
                            label: const Text("Save Signature"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // STATUS DISPLAY HELPERS
  // ==========================================================
  Color _statusColor(String status) {
    switch (status) {
      case "Signed by Tenant":
        return Colors.blue;
      case "Sent to Owner":
        return Colors.green;
      default:
        return Colors.deepOrange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "Signed by Tenant":
        return Icons.edit_document;
      case "Sent to Owner":
        return Icons.mark_email_read_outlined;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  // ==========================================================
  // SMALL DETAIL ROW (icon + label + value)
  // ==========================================================
  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xff1D1D1F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("contracts")
            .where("tenantId", isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Unable to load contracts.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Pending Signature';
            return !_inactiveStatuses.contains(status);
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "No contracts found",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final contractId = docs[index].id;
              final data = docs[index].data() as Map<String, dynamic>;

              final roomNumber = data["roomNumber"] ?? "Room";
              final ownerId = data["ownerId"] ?? "";
              final status = data["status"] ?? "Pending Signature";
              final terms = data["termsAndConditions"] ?? "";
              final electricRate = data["electricRate"] ?? 0;
              final waterRate = data["waterRate"] ?? 0;

              Timestamp? startTimestamp = data["startDate"];
              Timestamp? endTimestamp = data["endDate"];
              Timestamp? createdTimestamp = data["createdAt"];

              String startDate = "--";
              String endDate = "--";
              String createdDate = "--";

              if (startTimestamp != null) {
                startDate = DateFormat("MMM dd, yyyy")
                    .format(startTimestamp.toDate());
              }

              if (endTimestamp != null) {
                endDate =
                    DateFormat("MMM dd, yyyy").format(endTimestamp.toDate());
              }

              if (createdTimestamp != null) {
                createdDate = DateFormat("MMM dd, yyyy")
                    .format(createdTimestamp.toDate());
              }

              final bool isSigned = status == "Signed by Tenant";
              final bool isSentToOwner = status == "Sent to Owner";
              final Color statusColor = _statusColor(status);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= HEADER =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.article_outlined,
                              color: statusColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Rental Contract",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff1D1D1F),
                                  ),
                                ),
                                Text(
                                  "Room $roomNumber",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _statusIcon(status),
                                  size: 13,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ================= DETAILS =================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow(
                            icon: Icons.meeting_room_outlined,
                            label: "Room",
                            value: roomNumber.toString(),
                          ),
                          FutureBuilder<String>(
                            future: _getOwnerCode(ownerId),
                            builder: (context, ownerSnapshot) {
                              final displayCode =
                                  ownerSnapshot.data ?? "Loading...";
                              return _detailRow(
                                icon: Icons.badge_outlined,
                                label: "Owner ID",
                                value: displayCode,
                              );
                            },
                          ),
                          _detailRow(
                            icon: Icons.flash_on_outlined,
                            label: "Electric Rate",
                            value: "₱$electricRate per kWh",
                          ),
                          _detailRow(
                            icon: Icons.water_drop_outlined,
                            label: "Water Rate",
                            value: "₱$waterRate per m³",
                          ),
                          _detailRow(
                            icon: Icons.calendar_today_outlined,
                            label: "Start Date",
                            value: startDate,
                          ),
                          _detailRow(
                            icon: Icons.event_busy_outlined,
                            label: "End Date",
                            value: endDate,
                          ),
                          _detailRow(
                            icon: Icons.history_outlined,
                            label: "Created",
                            value: createdDate,
                          ),
                        ],
                      ),
                    ),

                    // ================= TERMS =================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffF7F7FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.notes_outlined,
                                  size: 15,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Terms & Conditions",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              terms.isEmpty ? "No terms provided" : terms,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    Divider(height: 1, color: Colors.grey.shade200),

                    // ================= ACTIONS =================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSentToOwner
                                    ? Colors.grey.shade300
                                    : Colors.deepOrange,
                                foregroundColor: isSentToOwner
                                    ? Colors.grey.shade700
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: isSentToOwner ? 0 : 2,
                              ),
                              onPressed: isSentToOwner
                                  ? null
                                  : () => _showSignatureDialog(
                                        contractId: contractId,
                                        roomNumber: roomNumber,
                                      ),
                              icon: Icon(
                                isSentToOwner ? Icons.lock_outline : Icons.draw,
                                size: 18,
                              ),
                              label: Text(
                                isSentToOwner
                                    ? "Signature Locked"
                                    : "Review & Sign",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (isSigned && !isSentToOwner) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: () => _sendToOwner(contractId),
                                icon: const Icon(Icons.send, size: 18),
                                label: const Text(
                                  "Send to Owner",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (isSentToOwner) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_outlined,
                                    color: Colors.green.shade700,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Signature is locked and sent to owner for verification.",
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepOrange
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    if (points.length < 2) {
      if (points.isNotEmpty) {
        canvas.drawCircle(points.first, 2, paint);
      }
      return;
    }

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) {
    return true;
  }
}