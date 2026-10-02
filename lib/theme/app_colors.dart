import 'package:flutter/material.dart';


class AppColors {
  final bool isDark;

  const AppColors._(this.isDark);

  factory AppColors.of(BuildContext context) {
    return AppColors._(Theme.of(context).brightness == Brightness.dark);
  }



  Color get background =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF3FAFC);


  Color get text => isDark ? Colors.white : const Color(0xFF164563);

  Color get textMuted =>
      isDark ? const Color(0xFFB8C2C7) : const Color(0xFF6E8992);
  Color get title => isDark ? Colors.white : const Color(0xFF123E5A);

  Color get subtitle =>
      isDark ? const Color(0xFFB8C2C7) : const Color(0xFF587287);

  // Pula para sa Delete at error (mas maliwanag sa dark mode)
  Color get danger =>
      isDark ? const Color(0xFFEF5350) : const Color(0xFFD93636);


  // Card
  Color get card => isDark ? const Color(0xFF1B2124) : Colors.white;

  Color glass([double opacity = 0.78]) => isDark
      ? const Color(0xFF1B2124)
      : Colors.white.withAlpha((opacity * 255).round());

  Color glassBorder([double opacity = 0.8]) => isDark
      ? const Color(0x1FFFFFFF)
      : Colors.white.withAlpha((opacity * 255).round());

  Color get cardInner =>
      isDark ? const Color(0xFF232B2F) : const Color(0xFFF3F6F8);

  Color get cardBorder =>
      isDark ? const Color(0x14FFFFFF) : const Color(0xFFDCEBF0);

  Color get divider =>
      isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE1ECEF);


  Color get appBar =>
      isDark ? const Color(0xFF000000) : const Color(0xFFE4F3F7);

  Color get bar => isDark ? const Color(0xFF0A0D0F) : const Color(0xEBFFFFFF);

  Color get inputFill =>
      isDark ? const Color(0xFF1B2124) : const Color(0xFFF3F6F8);

  Color get accent => const Color(0xFFE76F3C);


  Color get bubbleOwner =>
      isDark ? const Color(0xFF1F5A80) : const Color(0xFF164563);

  Color get sendButton =>
      isDark ? const Color(0xFFE76F3C) : const Color(0xFF164563);
}
