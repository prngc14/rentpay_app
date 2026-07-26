import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TenantContractsScreen extends StatefulWidget {
  const TenantContractsScreen({super.key});

  @override
  State<TenantContractsScreen> createState() => _TenantContractsScreenState();
}

class _TenantContractsScreenState extends State<TenantContractsScreen> {
  final List<Offset> _signaturePoints = [];
  bool _isSavingSignature = false;

  // Cache para hindi paulit-ulit mag-fetch ng ownerCode kapag pareho
  // ang owner ng maraming contract
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign the contract first.")),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "This signature is already locked and cannot be changed."),
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signature saved successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving signature: $e")),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contract sent to owner.")),
      );
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No contracts found"),
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

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.article_outlined,
                            color: Colors.deepOrange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "New Contract",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.shade50,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text("Room: $roomNumber"),
                      FutureBuilder<String>(
                        future: _getOwnerCode(ownerId),
                        builder: (context, ownerSnapshot) {
                          final displayCode =
                              ownerSnapshot.data ?? "Loading...";
                          return Text("Owner ID: $displayCode");
                        },
                      ),
                      Text("Electric Rate: ₱$electricRate per kWh"),
                      Text("Water Rate: ₱$waterRate per m³"),
                      Text("Start Date: $startDate"),
                      Text("End Date: $endDate"),
                      Text("Created: $createdDate"),
                      const SizedBox(height: 12),
                      Text(
                        terms.isEmpty ? "No terms provided" : terms,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSentToOwner
                                ? Colors.grey
                                : Colors.deepOrange,
                          ),
                          onPressed: isSentToOwner
                              ? null
                              : () => _showSignatureDialog(
                                    contractId: contractId,
                                    roomNumber: roomNumber,
                                  ),
                          icon: const Icon(Icons.draw),
                          label: Text(
                            isSentToOwner
                                ? "Signature Locked"
                                : "Review & Sign",
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isSigned && !isSentToOwner)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () => _sendToOwner(contractId),
                            icon: const Icon(Icons.send),
                            label: const Text("Send to Owner"),
                          ),
                        ),
                      if (isSentToOwner)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "Signature is locked and sent to owner for verification.",
                            style: TextStyle(color: Colors.green),
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
    // Laging i-repaint dahil ang _signaturePoints ay iisang list lang
    // na dinadagdagan (mutated in place), kaya ang reference comparison
    // (oldDelegate.points != points) ay laging false kahit may bagong
    // stroke -- kaya kailangan laging i-force ang repaint.
    return true;
  }
}