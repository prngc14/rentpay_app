import 'package:flutter/material.dart';

class RentPayBackdrop extends StatelessWidget {
  final Widget child;

  const RentPayBackdrop({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: CustomPaint(
            painter: _RentPayBackdropPainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class _RentPayBackdropPainter extends CustomPainter {
  const _RentPayBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFE4F3F7),
          Color(0xFFF8FCFC),
          Color(0xFFF1F8FA),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    _drawGlow(
      canvas,
      Offset(size.width * 0.12, size.height * 0.17),
      size.width * 0.42,
      const Color(0xB8FFFFFF),
    );
    _drawGlow(
      canvas,
      Offset(size.width * 0.84, size.height * 0.34),
      size.width * 0.34,
      const Color(0x70C8E7EE),
    );
    _drawGlow(
      canvas,
      Offset(size.width * 0.50, size.height * 0.76),
      size.width * 0.52,
      const Color(0x55FFFFFF),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
