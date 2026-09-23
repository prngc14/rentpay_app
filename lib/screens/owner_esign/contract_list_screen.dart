import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'contract_preview_screen.dart';
import 'create_contract_screen.dart';
import '../../widgets/app_warning_banner.dart';

class ContractListScreen extends StatelessWidget {
  const ContractListScreen({super.key});

  static const List<String> _inactiveStatuses = [
    'Expired',
    'Cancelled',
    'Terminated',
    'Renewed',
  ];

  Future<void> _terminateContract({
    required BuildContext context,
    required String contractId,
    required String? roomId,
    required String tenantName,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1B2124) : Colors.white,
          title: Text(
            'Terminate Contract',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF123E5A),
            ),
          ),
          content: Text(
            'Are you sure you want to terminate '
            '$tenantName\'s contract? '
            'It will be removed from this list, and the tenant '
            'and room will become available again for a new contract.',
            style: TextStyle(
              color: isDark ? const Color(0xFFD5DDE1) : const Color(0xFF454B50),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFB8C2C7)
                      : const Color(0xFF123E5A),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
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

      final contractRef =
          FirebaseFirestore.instance.collection('contracts').doc(contractId);

      batch.update(contractRef, {
        'status': 'Terminated',
        'terminatedAt': Timestamp.now(),
      });

      if (roomId != null && roomId.isNotEmpty) {
        final roomRef =
            FirebaseFirestore.instance.collection('rooms').doc(roomId);

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
            'contractId': contractId,
            'tenantId': data['tenantId'],
            'tenantName': data['tenantName'],
            'roomId': data['roomId'],
            'roomNumber': data['roomNumber'],
            'monthlyRent': data['monthlyRent'],
            'securityDeposit': data['securityDeposit'],
            'advancePayment': data['advancePayment'],
            'electricRate': data['electricRate'],
            'waterRate': data['waterRate'],
            'termsAndConditions': data['termsAndConditions'],
          },
        ),
      ),
    );
  }

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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? Colors.black : const Color(0xFFFFF8FC);

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF123E5A);

    final secondaryTextColor =
        isDark ? const Color(0xFFB8C2C7) : const Color(0xFF587287);

    final surfaceColor =
        isDark ? const Color(0xFF1B2124) : Colors.white.withOpacity(0.78);

    final borderColor =
        isDark ? const Color(0xFF46545B) : Colors.white.withOpacity(0.8);

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'User not logged in',
            style: TextStyle(
              color: primaryTextColor,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        title: Text(
          'Rentpay',
          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: primaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: primaryTextColor,
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
                  style: TextStyle(
                    color: primaryTextColor,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: primaryTextColor,
              ),
            );
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final status = data['status'] ?? 'Pending Signature';

            return !_inactiveStatuses.contains(status);
          }).toList();

          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            final roomA = _roomNumberValue(dataA['roomNumber']);
            final roomB = _roomNumberValue(dataB['roomNumber']);

            return roomA.compareTo(roomB);
          });

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No digital contracts',
                style: TextStyle(
                  color: primaryTextColor,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final contractId = docs[index].id;

              final data = docs[index].data() as Map<String, dynamic>;

              final tenantName = data['tenantName']?.toString() ?? 'Tenant';

              final roomNumber = data['roomNumber']?.toString() ?? 'Room';

              final roomId = data['roomId']?.toString();

              final status = data['status']?.toString() ?? 'Pending Signature';

              final monthlyRent = data['monthlyRent'] ?? 0;

              final createdAt = data['createdAt'] as Timestamp?;
              final startDate = data['startDate'] as Timestamp?;
              final endDate = data['endDate'] as Timestamp?;

              String created = '--';
              String start = '--';
              String end = '--';

              if (createdAt != null) {
                created = DateFormat('MMM dd, yyyy').format(createdAt.toDate());
              }

              if (startDate != null) {
                start = DateFormat('MMM dd, yyyy').format(startDate.toDate());
              }

              if (endDate != null) {
                end = DateFormat('MMM dd, yyyy').format(endDate.toDate());
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
                isDark: isDark,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              );
            },
          );
        },
      ),

      // =====================================================
      // NEW CONTRACT BUTTON
      // =====================================================

      floatingActionButton: SizedBox(
        height: 40,
        child: FloatingActionButton.extended(
          heroTag: 'newContractFab',

          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateContractScreen(),
              ),
            );
          },

          // BLACK IN DARK MODE
          backgroundColor: isDark ? Colors.black : const Color(0xE6FFFFFF),

          foregroundColor: isDark ? Colors.white : const Color(0xFF123E5A),

          elevation: 1,

          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isDark
                ? const BorderSide(
                    color: Color(0xFF46545B),
                  )
                : BorderSide.none,
          ),

          icon: const Icon(
            Icons.add,
            size: 16,
          ),

          label: const Text(
            'New Contract',
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
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final accentColor =
        isDark ? const Color(0xFFFFB36B) : const Color(0xFFE88916);

    final accentBackground =
        isDark ? const Color(0x26FFB36B) : const Color(0x1AE88916);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      elevation: isDark ? 1 : 0,
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: borderColor,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: CircleAvatar(
          backgroundColor: accentBackground,
          child: Icon(
            Icons.article_outlined,
            color: accentColor,
          ),
        ),
        title: Text(
          'Contract for $tenantName',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Room: $roomNumber  •  ₱$monthlyRent/mo',
          style: TextStyle(
            color: secondaryTextColor,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: accentBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert,
                size: 19,
                color: secondaryTextColor,
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
                      Text('Renew Contract'),
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
              builder: (_) => ContractPreviewScreen(
                contractData: data,
              ),
            ),
          );
        },
      ),
    );
  }
}
