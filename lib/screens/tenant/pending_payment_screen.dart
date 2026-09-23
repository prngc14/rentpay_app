import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingPaymentScreen extends StatelessWidget {
  final String paymentId;
  final String tenantId;
  final VoidCallback onContinue;
  final VoidCallback onSubmitNew;

  const PendingPaymentScreen({
    super.key,
    required this.paymentId,
    required this.tenantId,
    required this.onContinue,
    required this.onSubmitNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textPrimary =
        isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments')
            .doc(paymentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildRejected(
              context,
              'Hindi na ma-access ang payment record na ito.\n'
              'Pindutin ang button sa ibaba para magsumite ulit.',
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: textPrimary,
                strokeWidth: 2,
              ),
            );
          }

          if (!snapshot.data!.exists) {
            return _buildRejected(
              context,
              'Payment record not found.\n'
              'Pindutin ang button sa ibaba para magsumite ulit.',
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'pending').toString();
          final isPartial = data['isPartial'] == true;

          if (status == 'verified') {
            return isPartial
                ? _buildPartialApproved(context)
                : _buildApproved(context);
          }

          if (status == 'rejected') {
            return _buildRejected(context, null);
          }

          return _buildPending(context);
        },
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String? statusText,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textPrimary =
        isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);

    final textSecondary =
        isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12.5, height: 1.4, color: textSecondary),
            ),
            if (statusText != null) ...[
              const SizedBox(height: 12),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: textSecondary,
                ),
              ),
            ],
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: textPrimary,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                ),
                icon: Icon(Icons.upload_file_outlined,
                    size: 16, color: textPrimary),
                label: Text(
                  buttonText,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPending(BuildContext context) => _buildStatusCard(
        context,
        icon: Icons.send_rounded,
        iconColor: const Color(0xFFDDE3E6),
        title: 'Payment Submitted',
        message:
            'Your payment screenshot has been sent successfully.\nPlease wait for the owner to review and accept it.',
        statusText: 'STATUS: PENDING REVIEW',
      );

  Widget _buildApproved(BuildContext context) => _buildStatusCard(
        context,
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF1EBA63),
        title: 'Payment Approved!',
        message: 'Your payment has been reviewed and accepted by the owner.',
        buttonText: 'Continue to Dashboard',
        onPressed: onContinue,
      );

  Widget _buildPartialApproved(BuildContext context) => _buildStatusCard(
        context,
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF3E8BEA),
        title: 'Partial Payment Accepted!',
        message:
            'Your partial payment has been reviewed and accepted by the owner.\nYou may check your remaining balance on the dashboard.',
        buttonText: 'Continue to Dashboard',
        onPressed: onContinue,
      );

  Widget _buildRejected(BuildContext context, String? overrideMessage) =>
      _buildStatusCard(
        context,
        icon: Icons.close_rounded,
        iconColor: const Color(0xFFE93636),
        title: 'Payment Rejected',
        message: overrideMessage ??
            'Your payment could not be verified.\nPlease submit a new payment screenshot.',
        buttonText: 'Submit New Payment',
        onPressed: onSubmitNew,
      );
}
