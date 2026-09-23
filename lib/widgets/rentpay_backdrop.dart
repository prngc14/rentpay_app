import 'package:flutter/material.dart';

// =====================================================
// RENTPAY BACKDROP
// Background sa likod ng mga glass panel. Sumusunod sa
// light/dark mode ng app:
//   Light: parehong itsura tulad ng dati.
//   Dark:  nagsisimula sa mismong kulay ng scaffold (kaya
//          walang guhit sa pagitan ng AppBar at ng screen),
//          may malalabong teal na liwanag para makita pa
//          rin ang blur ng glass panels.
// =====================================================
class RentPayBackdrop extends StatelessWidget {
  final Widget child;

  const RentPayBackdrop({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RentPayBackdropPainter(
              isDark: isDark,
              darkBase: theme.scaffoldBackgroundColor,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _RentPayBackdropPainter extends CustomPainter {
  final bool isDark;

  // Kulay ng scaffold sa dark mode; dito nagsisimula ang gradient.
  final Color darkBase;

  const _RentPayBackdropPainter({
    required this.isDark,
    required this.darkBase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> gradientColors = isDark
        ? [
            darkBase,
            Color.lerp(darkBase, const Color(0xFF12222A), 0.55)!,
            Color.lerp(darkBase, const Color(0xFF0E1A20), 0.85)!,
          ]
        : const [
            Color(0xFFE4F3F7),
            Color(0xFFF8FCFC),
            Color(0xFFF1F8FA),
          ];

    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final Color glowA =
        isDark ? const Color(0x2E7196A3) : const Color(0xB8FFFFFF);
    final Color glowB =
        isDark ? const Color(0x2438607A) : const Color(0x70C8E7EE);
    final Color glowC =
        isDark ? const Color(0x1A7196A3) : const Color(0x55FFFFFF);

    _drawGlow(
      canvas,
      Offset(size.width * 0.12, size.height * 0.17),
      size.width * 0.42,
      glowA,
    );
    _drawGlow(
      canvas,
      Offset(size.width * 0.84, size.height * 0.34),
      size.width * 0.34,
      glowB,
    );
    _drawGlow(
      canvas,
      Offset(size.width * 0.50, size.height * 0.76),
      size.width * 0.52,
      glowC,
    );
  }

  void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);
  }

  @override
  bool shouldRepaint(covariant _RentPayBackdropPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.darkBase != darkBase;
  }
}
