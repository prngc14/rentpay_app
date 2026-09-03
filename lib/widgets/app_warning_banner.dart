import 'package:flutter/material.dart';


/// BannerType
/// Uri ng banner - kada type may sariling kulay at icon, pero PAREHONG
/// shape, size, position, at auto-dismiss timing.

enum BannerType { warning, success }

class _BannerStyle {
  final Color background;
  final Color accent;
  final IconData icon;

  const _BannerStyle({
    required this.background,
    required this.accent,
    required this.icon,
  });
}

const Map<BannerType, _BannerStyle> _bannerStyles = {
  BannerType.warning: _BannerStyle(
    background: Color(0xFFFCE8E8), // light pink
    accent: Color(0xFFE53935), // red
    icon: Icons.warning_amber_rounded,
  ),
  BannerType.success: _BannerStyle(
    background: Color(0xFFE6F6EA), // light green
    accent: Color(0xFF2E7D32), // green
    icon: Icons.check_circle_rounded,
  ),
};


/// AppBanner
/// Isang consistent banner design (parehong shape/size/position) para
/// gamitin sa LAHAT ng screens: Login, Register, Owner, Tenant,
/// Contract, Payment, etc. Nagbabago lang ang kulay/icon base sa type.

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

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: style.accent, width: 5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(style.icon, color: style.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: style.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close, color: style.accent, size: 20),
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


/// showAppWarningBanner / showAppSuccessBanner
/// Tawagin saan mang page para lumabas ang banner sa pinakataas ng
/// screen. Parehong shape, size, position, at 2-second auto-dismiss --
/// nagkakaiba lang ng kulay (red vs green) at icon.
///
/// USAGE:
///   showAppWarningBanner(context, "Wrong username or password.");
///   showAppSuccessBanner(context, "Registered Successfully.");
void showAppWarningBanner(BuildContext context, String message) {
  _showBanner(context, message, BannerType.warning);
}

void showAppSuccessBanner(BuildContext context, String message) {
  _showBanner(context, message, BannerType.success);
}

/// friendlyAuthError
/// Ginagawang readable/user-friendly ang raw exception mula sa Firebase
/// Auth o iba pang error (hal. "[firebase_auth/invalid-credential] ...")
/// para hindi na technical jargon ang makikita ng user sa banner.
///
/// USAGE:
///   showAppWarningBanner(context, friendlyAuthError(e));
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