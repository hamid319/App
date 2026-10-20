import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The SwipeTrip logo mark: a map pin swiping right, with a heart inside.
///
/// Drawn on a 100 × 100 grid (the same geometry as the logo design), so the
/// in-app logo and the generated app icon / splash PNGs
/// (`tool/brand_assets_test.dart`) come from one source.
class SwipePinPainter extends CustomPainter {
  const SwipePinPainter({
    required this.accent,
    this.foreground = Colors.white,
    this.background,
    this.cornerRadius = 0,
    this.contentScale = 1,
  });

  /// Heart colour; matches the ground so it reads as a cut-out.
  final Color accent;

  /// Pin and motion lines.
  final Color foreground;

  /// Tile fill; null leaves the ground transparent.
  final Color? background;

  /// Tile corner radius as a fraction of the side (0.225 ≈ iOS icon).
  final double cornerRadius;

  /// Shrinks the mark around the centre, e.g. for adaptive icon safe zones.
  final double contentScale;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate(
      (size.width - side) / 2,
      (size.height - side) / 2,
    );
    canvas.scale(side / 100);

    final ground = background;
    if (ground != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 100, 100),
          Radius.circular(100 * cornerRadius),
        ),
        Paint()..color = ground,
      );
    }

    canvas.translate(50, 50);
    canvas.scale(contentScale);
    canvas.translate(-50, -50);

    final paint = Paint()..isAntiAlias = true;

    // Motion lines left of the pin.
    void bar(double x, double y, double w, double opacity) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, 5),
          const Radius.circular(2.5),
        ),
        paint..color = foreground.withValues(alpha: opacity),
      );
    }

    bar(14, 35, 16, 0.55);
    bar(9, 46, 21, 0.85);
    bar(16, 57, 13, 0.55);

    // Pin, tilted 14° around its tip.
    canvas.save();
    canvas.translate(58, 78);
    canvas.rotate(14 * math.pi / 180);
    canvas.translate(-58, -78);

    final pin = Path()
      ..moveTo(58, 18)
      ..cubicTo(45.8, 18, 36, 27.6, 36, 39.4)
      ..cubicTo(36, 55, 58, 78, 58, 78)
      ..cubicTo(58, 78, 80, 55, 80, 39.4)
      ..cubicTo(80, 27.6, 70.2, 18, 58, 18)
      ..close();
    canvas.drawPath(pin, paint..color = foreground);

    final heart = Path()
      ..moveTo(58, 49)
      ..cubicTo(58, 49, 49, 43.4, 49, 37.4)
      ..arcToPoint(const Offset(58, 34.7), radius: const Radius.circular(4.9))
      ..arcToPoint(const Offset(67, 37.4), radius: const Radius.circular(4.9))
      ..cubicTo(67, 43.4, 58, 49, 58, 49)
      ..close();
    canvas.drawPath(heart, paint..color = accent);

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(SwipePinPainter old) =>
      old.accent != accent ||
      old.foreground != foreground ||
      old.background != background ||
      old.cornerRadius != cornerRadius ||
      old.contentScale != contentScale;
}

/// The logo mark as an app-icon tile in the theme's brand colour.
class SwipePinMark extends StatelessWidget {
  const SwipePinMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: SwipePinPainter(
          accent: primary,
          background: primary,
          cornerRadius: 0.225,
        ),
      ),
    );
  }
}
