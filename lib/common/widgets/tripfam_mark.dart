import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

/// The TripFam logo mark: a suitcase with three stickers, a heart (the
/// group), a paper plane (the trip) and a map pin (the place).
///
/// Drawn on a 100 × 100 grid, so the in-app logo and the generated app icon
/// and splash PNGs (`tool/brand_assets_test.dart`) come from one source.
class TripFamPainter extends CustomPainter {
  const TripFamPainter({
    this.background,
    this.cornerRadius = 0,
    this.contentScale = 1,
  });

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
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
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

    final fill = Paint()..isAntiAlias = true;

    // Handle.
    final handle = Path()
      ..moveTo(39, 30)
      ..lineTo(39, 21)
      ..quadraticBezierTo(39, 17, 43, 17)
      ..lineTo(57, 17)
      ..quadraticBezierTo(61, 17, 61, 21)
      ..lineTo(61, 30);
    canvas.drawPath(
      handle,
      Paint()
        ..color = BrandColors.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    // Body and wheels.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 27, 68, 54),
        const Radius.circular(13),
      ),
      fill..color = BrandColors.navy,
    );
    canvas.drawCircle(const Offset(29, 85), 4.5, fill..color = BrandColors.navy);
    canvas.drawCircle(const Offset(71, 85), 4.5, fill..color = BrandColors.navy);

    // Heart sticker: coral disc with a white heart.
    canvas.drawCircle(const Offset(35, 44), 10.5, fill..color = BrandColors.coral);
    final heart = Path()
      ..moveTo(35, 50)
      ..cubicTo(35, 50, 29, 46.2, 29, 42.2)
      ..arcToPoint(const Offset(35, 40.4), radius: const Radius.circular(3.3))
      ..arcToPoint(const Offset(41, 42.2), radius: const Radius.circular(3.3))
      ..cubicTo(41, 46.2, 35, 50, 35, 50)
      ..close();
    canvas.drawPath(heart, fill..color = Colors.white);

    // Plane sticker: white tile, slightly tilted, navy paper plane.
    canvas.save();
    canvas.translate(64, 43);
    canvas.rotate(-8 * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10.5, -10.5, 21, 21),
        const Radius.circular(4.5),
      ),
      fill..color = Colors.white,
    );
    final plane = Path()
      ..moveTo(-6, 1)
      ..lineTo(6.5, -5.5)
      ..lineTo(1.5, 6.5)
      ..lineTo(-0.5, 2.2)
      ..close();
    canvas.drawPath(plane, fill..color = BrandColors.navy);
    canvas.drawPath(
      Path()
        ..moveTo(-0.5, 2.2)
        ..lineTo(6.5, -5.5)
        ..lineTo(1, 1.2)
        ..close(),
      fill..color = BrandColors.sky,
    );
    canvas.restore();

    // Pin sticker: amber tile, slightly tilted, navy map pin.
    canvas.save();
    canvas.translate(50, 66);
    canvas.rotate(6 * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9.5, -9.5, 19, 19),
        const Radius.circular(4.5),
      ),
      fill..color = BrandColors.amber,
    );
    final pin = Path()
      ..moveTo(0, 6.5)
      ..cubicTo(0, 6.5, -5, 1.6, -5, -1.6)
      ..arcToPoint(const Offset(5, -1.6), radius: const Radius.circular(5))
      ..cubicTo(5, 1.6, 0, 6.5, 0, 6.5)
      ..close();
    canvas.drawPath(pin, fill..color = BrandColors.navy);
    canvas.drawCircle(const Offset(0, -1.8), 1.9, fill..color = BrandColors.amber);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(TripFamPainter old) =>
      old.background != background ||
      old.cornerRadius != cornerRadius ||
      old.contentScale != contentScale;
}

/// The logo mark as an app-icon tile on the sky ground.
class TripFamMark extends StatelessWidget {
  const TripFamMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(
        painter: TripFamPainter(
          background: BrandColors.sky,
          cornerRadius: 0.225,
        ),
      ),
    );
  }
}
