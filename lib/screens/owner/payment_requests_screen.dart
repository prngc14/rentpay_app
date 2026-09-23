import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import 'tenant_payment_history_screen.dart';

class PaymentRequestsScreen extends StatelessWidget {
  const PaymentRequestsScreen({super.key});

  static const Color _primaryLight = Color(0xFF123E5A);
  static const Color _secondaryLight = Color(0xFF587287);

  static const Color _textPrimaryDark = Color(0xFFE8EEF0);
  static const Color _textSecondaryDark = Color(0xFFA9B4B8);

  static const Color _orange = Color(0xFFE88916);

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
    final firestore = FirestoreService();
    final user = FirebaseAuth.instance.currentUser;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textPrimary = isDark ? _textPrimaryDark : _primaryLight;

    final textSecondary = isDark ? _textSecondaryDark : _secondaryLight;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Not logged in',
            style: TextStyle(
              color: textPrimary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Rentpay',
          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getOwnerPayments(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: _orange,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading payments:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFFFF8585) : Colors.red,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No payment history',
                style: TextStyle(
                  color: textSecondary,
                ),
              ),
            );
          }

          final payments = snapshot.data!.docs;

          final Map<String, List<QueryDocumentSnapshot>> grouped = {};

          for (final doc in payments) {
            final data = doc.data() as Map<String, dynamic>;

            final String tenantId = data['tenantId'] ?? '';

            if (tenantId.isEmpty) continue;

            grouped
                .putIfAbsent(
                  tenantId,
                  () => [],
                )
                .add(doc);
          }

          final tenantIds = grouped.keys.toList();

          if (tenantIds.isEmpty) {
            return Center(
              child: Text(
                'No payment requests yet',
                style: TextStyle(
                  fontSize: 18,
                  color: textPrimary,
                ),
              ),
            );
          }

          tenantIds.sort((a, b) {
            final groupA = grouped[a]!;
            final groupB = grouped[b]!;

            final dataA = groupA.first.data() as Map<String, dynamic>;

            final dataB = groupB.first.data() as Map<String, dynamic>;

            final roomA = _roomNumberValue(dataA['room']);

            final roomB = _roomNumberValue(dataB['room']);

            return roomA.compareTo(roomB);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              vertical: 4,
            ),
            itemCount: tenantIds.length,
            itemBuilder: (context, index) {
              final tenantId = tenantIds[index];
              final group = grouped[tenantId]!;

              final pendingCount = group.where((d) {
                final data = d.data() as Map<String, dynamic>;

                return (data['status'] ?? 'pending') == 'pending';
              }).length;

              final latestData = group.first.data() as Map<String, dynamic>;

              final String room = latestData['room'] ?? 'No room';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(tenantId)
                    .get(),
                builder: (context, tenantSnapshot) {
                  if (tenantSnapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Unable to load tenant: '
                        '${tenantSnapshot.error}',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFF8585) : Colors.red,
                        ),
                      ),
                    );
                  }

                  String tenantName = 'Loading tenant...';

                  if (tenantSnapshot.hasData && tenantSnapshot.data!.exists) {
                    final tenantData =
                        tenantSnapshot.data!.data() as Map<String, dynamic>;

                    tenantName = tenantData['name'] ?? 'Unnamed Tenant';
                  }

                  return _buildCompactPaymentCard(
                    context: context,
                    ownerId: user.uid,
                    tenantId: tenantId,
                    tenantName: tenantName,
                    room: room,
                    pendingCount: pendingCount,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCompactPaymentCard({
    required BuildContext context,
    required String ownerId,
    required String tenantId,
    required String tenantName,
    required String room,
    required int pendingCount,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final cardColor =
        isDark ? const Color(0xCC1B2124) : Colors.white.withOpacity(0.78);

    final borderColor =
        isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.8);

    final avatarBackground =
        isDark ? const Color(0xFF232A2E) : const Color(0x1AE88916);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      elevation: 0,
      color: cardColor,
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
          backgroundColor: avatarBackground,
          child: const Icon(
            Icons.person,
            color: _orange,
          ),
        ),
        title: Text(
          tenantName,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        subtitle: Text(
          'Room: $room',
          style: TextStyle(
            color: textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x33E88916)
                      : const Color(0x1AE88916),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 5),
            Icon(
              Icons.chevron_right,
              color: textSecondary,
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TenantPaymentHistoryScreen(
                ownerId: ownerId,
                tenantId: tenantId,
                tenantName: tenantName,
              ),
            ),
          );
        },
      ),
    );
  }
}
