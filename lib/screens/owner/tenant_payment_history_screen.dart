import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/firestore_service.dart';
import '../../widgets/app_warning_banner.dart';

class TenantPaymentHistoryScreen extends StatelessWidget {
  final String ownerId;
  final String tenantId;
  final String tenantName;

  const TenantPaymentHistoryScreen({
    super.key,
    required this.ownerId,
    required this.tenantId,
    required this.tenantName,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final screenContext = context;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor =
        isDark ? const Color(0xFF0D1114) : const Color(0xFFF5F8FA);

    final cardColor = isDark ? const Color(0xFF1B2124) : Colors.white;

    final primaryText =
        isDark ? const Color(0xFFE8EEF0) : const Color(0xFF1D1D1F);

    final secondaryText = isDark ? const Color(0xFFA9B4B8) : Colors.grey;

    final appBarText =
        isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Rentpay',
          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: appBarText,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: appBarText,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getTenantPaymentsForOwner(
          ownerId,
          tenantId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE88916),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading payments:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: primaryText),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No payments history',
                style: TextStyle(color: primaryText),
              ),
            );
          }

          final payments = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final p = payments[index];
              final data = p.data() as Map<String, dynamic>;

              final String room = data['room'] ?? 'No room';

              final double amount = (data['amount'] ?? 0).toDouble();

              final String screenshot = data['screenshot'] ?? '';

              final String status = data['status'] ?? 'pending';

              final bool isPartial = data['isPartial'] ?? false;

              final Timestamp? date = data['date'];

              Color statusColor;

              if (status == 'verified') {
                statusColor = Colors.green;
              } else if (status == 'rejected') {
                statusColor = Colors.red;
              } else {
                statusColor = Colors.orange;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: isDark ? 0 : 2,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Room: $room',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: primaryText,
                              ),
                            ),
                          ),
                          if (isPartial)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0x333BA7FF)
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'PARTIAL',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '',
                      ),
                      Text(
                        'Amount: ₱${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (date != null)
                        Text(
                          'Submitted: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Payment Screenshot',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 7),
                      if (screenshot.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.all(20),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    color: cardColor,
                                    child: InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      child: Image.network(
                                        screenshot,
                                        fit: BoxFit.contain,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Text(
                                              'Failed to load image',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: primaryText,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              screenshot,
                              height: 125,
                              width: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return _imageErrorBox(
                                  isDark,
                                  'Image not available',
                                );
                              },
                            ),
                          ),
                        )
                      else
                        _imageErrorBox(
                          isDark,
                          'No screenshot uploaded',
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Status: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: primaryText,
                            ),
                          ),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (status == 'pending') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    await firestore.approvePayment(
                                      p.id,
                                      tenantId,
                                    );

                                    if (!screenContext.mounted) return;

                                    showAppSuccessBanner(
                                      screenContext,
                                      'Payment approved',
                                    );
                                  } catch (error) {
                                    debugPrint(
                                      'APPROVE BUTTON ERROR: $error',
                                    );

                                    if (!screenContext.mounted) return;

                                    final message = error
                                            .toString()
                                            .contains('permission-denied')
                                        ? 'Permission denied. Check Firestore rules.'
                                        : 'Unable to approve payment';

                                    showAppWarningBanner(
                                      screenContext,
                                      message,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text(
                                  'Approve',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    await firestore.rejectPayment(p.id);

                                    if (!screenContext.mounted) return;

                                    showAppWarningBanner(
                                      screenContext,
                                      'Payment rejected',
                                    );
                                  } catch (error) {
                                    if (!screenContext.mounted) return;

                                    showAppWarningBanner(
                                      screenContext,
                                      'Unable to reject payment',
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text(
                                  'Reject',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierColor: Colors.black.withOpacity(0.25),
                              builder: (dialogContext) {
                                return AlertDialog(
                                  backgroundColor: cardColor,
                                  title: Text(
                                    'Delete this payment?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: primaryText,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(
                                          dialogContext,
                                          false,
                                        );
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: secondaryText,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(
                                          dialogContext,
                                          true,
                                        );
                                      },
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: Color(0xFFD93636),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              await FirebaseFirestore.instance
                                  .collection('payments')
                                  .doc(p.id)
                                  .delete();

                              if (!screenContext.mounted) return;

                              showAppSuccessBanner(
                                screenContext,
                                'Payment deleted successfully',
                              );
                            }
                          },
                          child: const Text(
                            'Delete Payment',
                            style: TextStyle(
                              color: Color(0xFFD93636),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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

  Widget _imageErrorBox(bool isDark, String message) {
    return Container(
      height: 125,
      width: 180,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF263136) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade400 : Colors.grey,
          ),
        ),
      ),
    );
  }
}
