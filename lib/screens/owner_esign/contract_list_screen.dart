
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'contract_preview_screen.dart';
import 'create_contract_screen.dart';
import '../../widgets/app_warning_banner.dart';

class ContractListScreen extends StatelessWidget {
  const ContractListScreen({super.key});

  // Mga status na hindi na active
  static const List<String> _inactiveStatuses = [
    'Expired',
    'Cancelled',
    'Terminated',
    'Renewed',
  ];

  // =====================================================
  // TERMINATE CONTRACT
  // =====================================================

  Future<void> _terminateContract({
    required BuildContext context,
    required String contractId,
    required String? roomId,
    required String tenantName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Terminate Contract'),
          content: Text(
            'Are you sure you want to terminate '
            '$tenantName\'s contract? '
            'It will be removed from this list, and the tenant '
            'and room will become available again for a new contract.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Terminate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final contractRef = FirebaseFirestore.instance
          .collection('contracts')
          .doc(contractId);

      batch.update(contractRef, {
        'status': 'Terminated',
        'terminatedAt': Timestamp.now(),
      });

      if (roomId != null && roomId.isNotEmpty) {
        final roomRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId);

        batch.update(roomRef, {
          'tenantId': null,
        });
      }

      await batch.commit();

      if (context.mounted) {
        showAppSuccessBanner(
          context,
          'Contract terminated successfully.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppWarningBanner(
          context,
          friendlyAuthError(e),
        );
      }
    }
  }

  // =====================================================
  // RENEW CONTRACT
  // =====================================================

  void _renewContract({
    required BuildContext context,
    required String contractId,
    required Map<String, dynamic> data,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateContractScreen(
          renewalData: {
            "contractId": contractId,
            "tenantId": data["tenantId"],
            "tenantName": data["tenantName"],
            "roomId": data["roomId"],
            "roomNumber": data["roomNumber"],
            "monthlyRent": data["monthlyRent"],
            "securityDeposit": data["securityDeposit"],
            "advancePayment": data["advancePayment"],
            "electricRate": data["electricRate"],
            "waterRate": data["waterRate"],
            "termsAndConditions": data["termsAndConditions"],
          },
        ),
      ),
    );
  }

  // =====================================================
  // ROOM NUMBER SORTING
  // =====================================================

  static int _roomNumberValue(dynamic value) {
    final text = value?.toString().trim() ?? '';

    final directNumber = int.tryParse(text);

    if (directNumber != null) {
      return directNumber;
    }

    final match = RegExp(r'\d+').firstMatch(text);

    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

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
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF123E5A),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('contracts')
            .where('ownerId', isEqualTo: user.uid)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Firestore query error: ${snapshot.error}',
                  textAlign: TextAlign.center,
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
          // FILTER ACTIVE CONTRACTS
          // =================================================

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final status =
                data['status'] ?? 'Pending Signature';

            return !_inactiveStatuses.contains(status);
          }).toList();

          // =================================================
          // SORT BY ROOM NUMBER
          // =================================================

          docs.sort((a, b) {
            final dataA =
                a.data() as Map<String, dynamic>;

            final dataB =
                b.data() as Map<String, dynamic>;

            final roomA =
                _roomNumberValue(dataA['roomNumber']);

            final roomB =
                _roomNumberValue(dataB['roomNumber']);

            return roomA.compareTo(roomB);
          });

          // =================================================
          // EMPTY STATE
          // =================================================

if (docs.isEmpty) {
  return const Center(
    child: Text("No digital contracts"),
  );
}

          // =================================================
          // CONTRACT LIST
          // =================================================

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              vertical: 4,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final contractId = docs[index].id;

              final data =
                  docs[index].data()
                      as Map<String, dynamic>;

              final tenantName =
                  data['tenantName'] ?? 'Tenant';

              final roomNumber =
                  data['roomNumber'] ?? 'Room';

              final roomId =
                  data['roomId'] as String?;

              final status =
                  data['status'] ??
                      'Pending Signature';

              final monthlyRent =
                  data['monthlyRent'] ?? 0;

              Timestamp? createdAt =
                  data['createdAt'];

              Timestamp? startDate =
                  data['startDate'];

              Timestamp? endDate =
                  data['endDate'];

              String created = '--';
              String start = '--';
              String end = '--';

              if (createdAt != null) {
                created = DateFormat(
                  'MMM dd, yyyy',
                ).format(
                  createdAt.toDate(),
                );
              }

              if (startDate != null) {
                start = DateFormat(
                  'MMM dd, yyyy',
                ).format(
                  startDate.toDate(),
                );
              }

              if (endDate != null) {
                end = DateFormat(
                  'MMM dd, yyyy',
                ).format(
                  endDate.toDate(),
                );
              }

              return _buildCompactContractCard(
                context: context,
                contractId: contractId,
                data: data,
                tenantName: tenantName,
                roomNumber: roomNumber,
                roomId: roomId,
                status: status,
                monthlyRent: monthlyRent,
                start: start,
                end: end,
                created: created,
              );
            },
          );
        },
      ),

      // ===================================================
      // NEW CONTRACT BUTTON
      // ===================================================

      floatingActionButton: SizedBox(
        height: 36,
        child: FloatingActionButton.extended(
          heroTag: "newContractFab",

          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const CreateContractScreen(),
              ),
            );
          },

          backgroundColor: const Color(0xE6FFFFFF),
          foregroundColor: const Color(0xFF123E5A),
          elevation: 1,

          extendedPadding:
              const EdgeInsets.symmetric(
            horizontal: 10,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),

          icon: const Icon(
            Icons.add,
            size: 15,
          ),

          label: const Text(
            "New Contract",
            style: TextStyle(
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // CONTRACT CARD
  // =====================================================

  Widget _buildCompactContractCard({
    required BuildContext context,
    required String contractId,
    required Map<String, dynamic> data,
    required String tenantName,
    required String roomNumber,
    required String? roomId,
    required String status,
    required dynamic monthlyRent,
    required String start,
    required String end,
    required String created,
  }) {
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
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),

        leading: const CircleAvatar(
          backgroundColor: Color(0x1AE88916),
          child: Icon(
            Icons.article_outlined,
            color: Color(0xFFE88916),
          ),
        ),

        title: Text(
          'Contract for $tenantName',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF123E5A),
          ),
          overflow: TextOverflow.ellipsis,
        ),

        subtitle: Text(
          'Room: $roomNumber  •  ₱$monthlyRent/mo',
          style: const TextStyle(
            color: Color(0xFF587287),
          ),
        ),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),

              decoration: BoxDecoration(
                color: const Color(0x1AE88916),
                borderRadius:
                    BorderRadius.circular(20),
              ),

              child: Text(
                status,
                style: const TextStyle(
                  color: Color(0xFFE88916),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),

            PopupMenuButton<String>(
              padding: EdgeInsets.zero,

              icon: const Icon(
                Icons.more_vert,
                size: 19,
                color: Color(0xFF587287),
              ),

              onSelected: (value) {
                if (value == 'terminate') {
                  _terminateContract(
                    context: context,
                    contractId: contractId,
                    roomId: roomId,
                    tenantName: tenantName,
                  );
                } else if (value == 'renew') {
                  _renewContract(
                    context: context,
                    contractId: contractId,
                    data: data,
                  );
                }
              },

              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'renew',

                  child: Row(
                    children: [
                      Icon(
                        Icons.autorenew,
                        color: Colors.deepOrange,
                        size: 20,
                      ),

                      SizedBox(width: 8),

                      Text(
                        'Renew Contract',
                      ),
                    ],
                  ),
                ),

                const PopupMenuItem(
                  value: 'terminate',

                  child: Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: Colors.red,
                        size: 20,
                      ),

                      SizedBox(width: 8),

                      Text(
                        'Terminate Contract',
                        style: TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ContractPreviewScreen(
                contractData: data,
              ),
            ),
          );
        },
      ),
    );
  }
}