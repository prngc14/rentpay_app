import 'package:flutter/material.dart';

// Bilog na chat icon na parang Messenger (may kidlat sa loob).
// Sumusunod sa kulay at laki ng IconTheme, kaya gumagana sa
// NavigationBar at BottomNavigationBar.
//
//   MessengerIcon()                 -> puno (para sa selected)
//   MessengerIcon(filled: false)    -> outline (para sa unselected)
class MessengerIcon extends StatelessWidget {
  const MessengerIcon({
    super.key,
    this.filled = true,
    this.size,
    this.color,
  });

  final bool filled;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);

    final double iconSize = size ?? iconTheme.size ?? 24;
    final Color iconColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: CustomPaint(
        painter: _MessengerPainter(
          color: iconColor,
          outlined: !filled,
        ),
      ),
    );
  }
}

class _MessengerPainter extends CustomPainter {
  const _MessengerPainter({
    required this.color,
    required this.outlined,
  });

  final Color color;
  final bool outlined;

  @override
  void paint(Canvas canvas, Size size) {
    // Iginuhit sa 24x24 na grid, tapos i-scale sa laki ng icon.
    canvas.scale(size.width / 24, size.height / 24);

    // Bilog na bubble + maliit na buntot sa kaliwang ibaba
    final Path bubble = Path.combine(
      PathOperation.union,
      Path()
        ..addOval(
          Rect.fromCircle(center: const Offset(12, 11.2), radius: 10),
        ),
      Path()
        ..moveTo(6.4, 18.6)
        ..lineTo(4.0, 22.6)
        ..lineTo(10.0, 20.4)
        ..close(),
    );

    // Kidlat
    final Path bolt = Path()
      ..moveTo(5.4, 14.6)
      ..lineTo(10.5, 9.0)
      ..lineTo(13.1, 11.6)
      ..lineTo(18.6, 9.0)
      ..lineTo(13.5, 14.6)
      ..lineTo(10.9, 12.0)
      ..close();

    if (outlined) {
      // Outline na bubble, puno ang kidlat
      canvas.drawPath(
        bubble,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );

      canvas.drawPath(
        bolt,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color,
      );
    } else {
      // Puno ang bubble, butas ang kidlat
      final Path filled = Path.combine(
        PathOperation.difference,
        bubble,
        bolt,
      );

      canvas.drawPath(
        filled,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MessengerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.outlined != outlined;
  }
}
