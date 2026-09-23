import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/firestore_service.dart';
import '../../widgets/rentpay_glass_panel.dart';

class TenantPaymentHistoryScreen extends StatelessWidget {
  final String tenantId;

  const TenantPaymentHistoryScreen({
    super.key,
    required this.tenantId,
  });

  static const Color _green = Color(0xFF1EBA63);
  static const Color _blue = Color(0xFF3E8BEA);
  static const Color _amber = Color(0xFFF2A51E);
  static const Color _red = Color(0xFFE93636);

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
        return _green;
      case 'rejected':
        return _red;
      default:
        return _amber;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'verified':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary =
        isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);
    final Color textSecondary =
        isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // Kapareho ng ibang screens: "Rentpay" script sa gitna, transparent.
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
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.maybePop(context),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.arrow_back, color: textPrimary, size: 22),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getTenantPayments(tenantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: textPrimary),
            );
          }

          if (snapshot.hasError) {
            return _buildMessage(
              context,
              icon: Icons.error_outline,
              title: 'Unable to load payment history',
              message: '${snapshot.error}',
            );
          }

          final payments = [...(snapshot.data?.docs ?? [])];
          payments.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['date'] as Timestamp?;
            final bDate = bData['date'] as Timestamp?;

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          if (payments.isEmpty) {
            return _buildMessage(
              context,
              icon: Icons.history,
              title: 'No payment history yet',
              message: 'Your submitted payments will show up here.',
            );
          }

          // Unang item = header; kasunod ang mga payment.
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: payments.length + 1,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: RentpayPanelHeader(
                    icon: Icons.history,
                    title: 'Payment History',
                    trailing: Text(
                      '${payments.length} total',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ),
                );
              }

              final data = payments[index - 1].data() as Map<String, dynamic>;

              return _buildPaymentCard(
                context,
                data,
                textPrimary,
                textSecondary,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPill(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    Map<String, dynamic> data,
    Color textPrimary,
    Color textSecondary,
  ) {
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final room = data['room']?.toString() ?? 'No room';
    final status = data['status']?.toString() ?? 'pending';
    final isPartial = data['isPartial'] == true;
    final date = data['date'] as Timestamp?;

    final Color statusColor = _statusColor(status);

    return RentpayGlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RentpayPanelHeader(
            icon: Icons.receipt_long,
            title: 'Room $room',
            dense: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPartial) ...[
                  _buildPill('PARTIAL', _blue, Icons.timelapse),
                  const SizedBox(width: 6),
                ],
                _buildPill(
                  status.toUpperCase(),
                  statusColor,
                  _statusIcon(status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Naka-indent (35) para kapantay ng salitang "Room X", hindi
          // sa ilalim ng icon.
          Padding(
            padding: const EdgeInsets.only(left: 35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount',
                  style: TextStyle(fontSize: 10, color: textSecondary),
                ),
                const SizedBox(height: 1),
                Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: textSecondary),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        date == null
                            ? 'Date not available'
                            : DateFormat('MMMM dd, yyyy - hh:mm a')
                                .format(date.toDate()),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary =
        isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);
    final Color textSecondary =
        isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: RentpayGlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF111111),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
