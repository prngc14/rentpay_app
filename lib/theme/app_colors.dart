import 'package:flutter/material.dart';

/// Mga kulay na awtomatikong sumusunod sa light/dark mode.
///
/// Paano gamitin sa kahit anong screen:
///
///   final c = AppColors.of(context);
///   Text('Hello', style: TextStyle(color: c.title));
///   Card(color: c.glass());
///
/// Huwag nang gumamit ng Colors.white o Color(0xFF123E5A) na nakasulat
/// nang direkta sa screen, dahil hindi ito nagbabago sa dark mode.
class AppColors {
  final bool isDark;

  const AppColors._(this.isDark);

  factory AppColors.of(BuildContext context) {
    return AppColors._(Theme.of(context).brightness == Brightness.dark);
  }

  // -----------------------------------------------------
  // BACKGROUND
  // -----------------------------------------------------

  // Background ng buong screen
  Color get background =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF3FAFC);

  // -----------------------------------------------------
  // LETRA AT ICON
  // -----------------------------------------------------

  // Pangunahing letra at icon (Juggernaut chat)
  Color get text => isDark ? Colors.white : const Color(0xFF164563);

  // Pangalawang letra (Juggernaut chat)
  Color get textMuted =>
      isDark ? const Color(0xFFB8C2C7) : const Color(0xFF6E8992);

  // Pamagat ng screen, pangalan, halaga (dating 0xFF123E5A)
  Color get title => isDark ? Colors.white : const Color(0xFF123E5A);

  // Subtitle at label (dating 0xFF587287)
  Color get subtitle =>
      isDark ? const Color(0xFFB8C2C7) : const Color(0xFF587287);

  // Pula para sa Delete at error (mas maliwanag sa dark mode)
  Color get danger =>
      isDark ? const Color(0xFFEF5350) : const Color(0xFFD93636);

  // -----------------------------------------------------
  // CARD AT PANEL
  // -----------------------------------------------------

  // Card
  Color get card => isDark ? const Color(0xFF1B2124) : Colors.white;

  // Card na bahagyang transparent sa light mode
  // (dating Colors.white.withOpacity(0.78))
  Color glass([double opacity = 0.78]) => isDark
      ? const Color(0xFF1B2124)
      : Colors.white.withAlpha((opacity * 255).round());

  // Gilid ng glass card
  // (dating Colors.white.withOpacity(0.8))
  Color glassBorder([double opacity = 0.8]) => isDark
      ? const Color(0x1FFFFFFF)
      : Colors.white.withAlpha((opacity * 255).round());

  // Panel sa loob ng card (bahagyang naiiba sa card)
  Color get cardInner =>
      isDark ? const Color(0xFF232B2F) : const Color(0xFFF3F6F8);

  Color get cardBorder =>
      isDark ? const Color(0x14FFFFFF) : const Color(0xFFDCEBF0);

  Color get divider =>
      isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE1ECEF);

  // -----------------------------------------------------
  // TAAS AT BABA NG SCREEN
  // -----------------------------------------------------

  Color get appBar =>
      isDark ? const Color(0xFF000000) : const Color(0xFFE4F3F7);

  Color get bar => isDark ? const Color(0xFF0A0D0F) : const Color(0xEBFFFFFF);

  // Text field
  Color get inputFill =>
      isDark ? const Color(0xFF1B2124) : const Color(0xFFF3F6F8);

  // Orange accent (pareho sa dalawang mode)
  Color get accent => const Color(0xFFE76F3C);

  // -----------------------------------------------------
  // CHAT
  // -----------------------------------------------------

  Color get bubbleOwner =>
      isDark ? const Color(0xFF1F5A80) : const Color(0xFF164563);

  Color get sendButton =>
      isDark ? const Color(0xFFE76F3C) : const Color(0xFF164563);
}
