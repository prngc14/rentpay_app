import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// =====================================================
// RENTPAY GLASS PANEL
// Parehong itsura ng glass panels sa owner dashboard at
// tenant Home: blur, tint, border at shadow.
// =====================================================
class RentpayGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const RentpayGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xCC1B2124) : const Color(0xB8FFFFFF),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.82),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7196A3).withOpacity(0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// =====================================================
// PANEL HEADER
// Orange na bilog na icon + title (kapareho ng
// "Payment Status" / "Monthly Billing" sa Home).
// May optional na `trailing` (halimbawa, status badge)
// sa dulong kanan.
// =====================================================
class RentpayPanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final bool compact;

  // dense = mas maliit pa kaysa compact (para sa maliliit na panel).
  final bool dense;

  const RentpayPanelHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.compact = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary =
        isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);

    final Widget? trailingWidget = trailing;

    return Row(
      children: [
        CircleAvatar(
          radius: dense ? 13 : (compact ? 15 : 18),
          backgroundColor: const Color(0xFF111111),
          child: Icon(
            icon,
            color: Colors.white,
            size: dense ? 15 : (compact ? 17 : 21),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: dense ? 15 : (compact ? 16 : 18),
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ),
        if (trailingWidget != null) ...[
          const SizedBox(width: 8),
          trailingWidget,
        ],
      ],
    );
  }
}
