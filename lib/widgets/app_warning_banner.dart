import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BannerType { warning, success, info }

class _BannerStyle {
  final String title;
  final Color accent;
  final IconData icon;

  const _BannerStyle({
    required this.title,
    required this.accent,
    required this.icon,
  });
}

const Map<BannerType, _BannerStyle> _bannerStyles = {
  BannerType.warning: _BannerStyle(
    title: 'Needs attention',
    accent: Color(0xFFE88916),
    icon: Icons.warning_amber_rounded,
  ),
  BannerType.success: _BannerStyle(
    title: 'Completed',
    accent: Color(0xFF219B8A),
    icon: Icons.check_circle_rounded,
  ),
  BannerType.info: _BannerStyle(
    title: 'RentPay update',
    accent: Color(0xFF328FA8),
    icon: Icons.notifications_rounded,
  ),
};

class AppBanner extends StatelessWidget {
  final String message;
  final BannerType type;
  final VoidCallback onClose;

  const AppBanner({
    super.key,
    required this.message,
    required this.onClose,
    this.type = BannerType.warning,
  });

  @override
  Widget build(BuildContext context) {
    final style = _bannerStyles[type]!;
    final colors = AppColors.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
        decoration: BoxDecoration(
          color: colors.isDark
              ? const Color(0xFF1B2429)
              : const Color(0xFFF8FDFE),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.isDark
                ? Colors.white.withOpacity(0.10)
                : const Color(0xFFD8EBEF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(colors.isDark ? 0.28 : 0.10),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: style.accent.withOpacity(colors.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(style.icon, color: style.accent, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      style.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.title,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: TextStyle(
                        color: colors.subtitle,
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Just now',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              tooltip: 'Dismiss notification',
              onPressed: onClose,
              icon: Icon(Icons.close, color: colors.textMuted, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backwards-compatible alias (kung may ibang file na tumatawag pa sa
/// lumang pangalan na `AppWarningBanner`).
typedef AppWarningBanner = AppBanner;

/// _showBanner (internal)
/// Common logic para sa warning at success banners: nilalagay sa top
/// ng screen gamit ang Overlay, auto-dismiss after 2 seconds, at
/// isa lang laging bisible sa isang pagkakataon.
OverlayEntry? _currentBannerEntry;

void _showBanner(BuildContext context, String message, BannerType type) {
  // Tanggalin muna ang existing banner (kung meron) para isa lang laging lumalabas
  _currentBannerEntry?.remove();
  _currentBannerEntry = null;

  final overlay = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppBanner(
              message: message,
              type: type,
              onClose: () {
                entry.remove();
                if (_currentBannerEntry == entry) _currentBannerEntry = null;
              },
            ),
          ),
        ),
      ),
    ),
  );

  _currentBannerEntry = entry;
  overlay.insert(entry);

  // Auto-dismiss after 2 seconds
  Future.delayed(const Duration(seconds: 2), () {
    if (_currentBannerEntry == entry) {
      entry.remove();
      _currentBannerEntry = null;
    }
  });
}

void showAppWarningBanner(BuildContext context, String message) {
  _showBanner(context, message, BannerType.warning);
}

void showAppSuccessBanner(BuildContext context, String message) {
  _showBanner(context, message, BannerType.success);
}

String friendlyAuthError(Object error) {
  final msg = error.toString().toLowerCase();

  if (msg.contains('invalid-credential') ||
      msg.contains('wrong-password') ||
      msg.contains('user-not-found')) {
    return "Wrong username or password.";
  }
  if (msg.contains('email-already-in-use')) {
    return "That username is already taken.";
  }
  if (msg.contains('network-request-failed')) {
    return "No internet connection. Please try again.";
  }
  if (msg.contains('permission-denied')) {
    return "You do not have permission to connect this room.";
  }
  if (msg.contains('too-many-requests')) {
    return "Too many attempts. Please try again later.";
  }
  if (msg.contains('weak-password')) {
    return "Password is too weak.";
  }
  if (msg.contains('user-disabled')) {
    return "This account has been disabled.";
  }
  if (msg.contains('email verification is disabled')) {
    return "Email verification is unavailable right now.";
  }

  return "Something went wrong. Please try again.";
}
