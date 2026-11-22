import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import 'duck_moment.dart';

/// The Out We Go logo mark: the duck with its rolled-up mattress, standing
/// still (the animated in-app moments use [DuckMoment]).
///
/// One painter for the in-app logo and the generated app icon and splash
/// PNGs (`tool/brand_assets_test.dart`).
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
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

    final ground = background;
    if (ground != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, side, side),
          Radius.circular(side * cornerRadius),
        ),
        Paint()..color = ground,
      );
    }

    // The duck spans about x 34–176 and y 38–202 of its 220 grid: shift it
    // to the centre and let it fill about two thirds of the tile.
    canvas.translate(side / 2, side / 2);
    canvas.scale(contentScale * 0.92);
    canvas.translate(-side / 2 + side * 0.03, -side / 2 - side * 0.06);
    const DuckPainter(mood: DuckMood.idle, seconds: 0, still: true)
        .paint(canvas, Size.square(side));

    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.background != background ||
      old.cornerRadius != cornerRadius ||
      old.contentScale != contentScale;
}

/// The logo mark as an app-icon tile on the lime ground.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(
        painter: BrandMarkPainter(
          background: BrandColors.lime,
          cornerRadius: 0.225,
        ),
      ),
    );
  }
}
