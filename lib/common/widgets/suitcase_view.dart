import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../utils/passport_stamps.dart';
import '../utils/suitcase_progress.dart';

/// A city sticker on the suitcase.
class SuitcaseSticker {
  const SuitcaseSticker({
    required this.label,
    required this.seed,
    this.faded = false,
  });

  /// From a passport stamp: the first three letters of the city; faded
  /// until the user checked in on site, like the stamp.
  SuitcaseSticker.fromStamp(PassportStamp s)
      : label = cityStickerLabel(s.cityName),
        seed = s.seed,
        faded = !s.checkedIn;

  final String label;

  /// Picks colour, shape and tilt, so a city always looks the same.
  final int seed;
  final bool faded;
}

/// "Berlin" -> "BER".
String cityStickerLabel(String city) {
  final letters = city.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
  return (letters.length > 3 ? letters.substring(0, 3) : letters).toUpperCase();
}

/// The user's suitcase: the logo's suitcase with a lid that opens, city
/// stickers and earned extras. Drawn on the logo's 100 × 100 grid.
class SuitcasePainter extends CustomPainter {
  const SuitcasePainter({
    this.stickers = const [],
    this.extras = const {},
    this.lidAngle = 0,
    this.lastStickerScale = 1,
  });

  /// Shows the newest [maxStickers] of them.
  final List<SuitcaseSticker> stickers;
  final Set<SuitcaseExtra> extras;

  /// 0 = closed; negative opens the lid around its left hinge.
  final double lidAngle;

  /// Scale of the newest sticker, for slapping it on.
  final double lastStickerScale;

  static const maxStickers = 6;

  // Sticker spots on the closed front: (x, y, tilt).
  static const _spots = [
    (50.0, 62.0, -0.08),
    (30.0, 38.0, -0.16),
    (69.0, 38.0, 0.12),
    (29.0, 69.0, 0.1),
    (71.0, 68.0, -0.12),
    (50.0, 36.0, 0.05),
  ];

  static const _palette = [
    BrandColors.coral,
    BrandColors.amber,
    BrandColors.sky,
    Color(0xFF8FE3BF), // mint
    Color(0xFFFFFFFF),
    Color(0xFFC9B6FF), // lilac
  ];

  static const _seam = Color(0xFF141B4D);

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);

    final fill = Paint()..isAntiAlias = true;
    final gold = extras.contains(SuitcaseExtra.goldWheels);

    // Wheels.
    for (final x in const [29.0, 71.0]) {
      canvas.drawCircle(Offset(x, 85), 4.5,
          fill..color = gold ? BrandColors.amber : BrandColors.navy);
      if (gold) {
        canvas.drawCircle(Offset(x, 85), 1.6, fill..color = BrandColors.navy);
      }
    }

    // Lower shell.
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(16, 45, 84, 81,
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
          bottomLeft: const Radius.circular(13),
          bottomRight: const Radius.circular(13)),
      fill..color = BrandColors.navy,
    );
    if (extras.contains(SuitcaseExtra.strap)) {
      canvas.drawRect(
          const Rect.fromLTRB(46, 45, 54, 81), fill..color = BrandColors.coral);
    }

    // Lid with handle, turned around its left hinge.
    canvas.save();
    canvas.translate(16, 45);
    canvas.rotate(lidAngle);
    canvas.translate(-16, -45);
    _paintLid(canvas, fill);
    canvas.restore();

    if (lidAngle == 0) {
      canvas.drawLine(
        const Offset(17, 45),
        const Offset(83, 45),
        Paint()
          ..color = _seam
          ..strokeWidth = 1.2,
      );
      if (extras.contains(SuitcaseExtra.strap)) {
        final buckle = RRect.fromRectAndRadius(
            const Rect.fromLTWH(44.5, 41.5, 11, 7), const Radius.circular(1.5));
        canvas.drawRRect(buckle, fill..color = BrandColors.amber);
        canvas.drawRRect(buckle.deflate(1.8), fill..color = BrandColors.coral);
      }
      _paintStickers(canvas, fill);
    }

    canvas.restore();
  }

  void _paintLid(Canvas canvas, Paint fill) {
    final handleColor = extras.contains(SuitcaseExtra.goldHandle)
        ? BrandColors.amber
        : BrandColors.navy;
    canvas.drawPath(
      Path()
        ..moveTo(39, 30)
        ..lineTo(39, 21)
        ..quadraticBezierTo(39, 17, 43, 17)
        ..lineTo(57, 17)
        ..quadraticBezierTo(61, 17, 61, 21)
        ..lineTo(61, 30),
      Paint()
        ..color = handleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(16, 27, 84, 45,
          topLeft: const Radius.circular(13),
          topRight: const Radius.circular(13),
          bottomLeft: const Radius.circular(2),
          bottomRight: const Radius.circular(2)),
      fill..color = BrandColors.navy,
    );
    if (extras.contains(SuitcaseExtra.strap)) {
      canvas.drawRect(
          const Rect.fromLTRB(46, 27, 54, 45), fill..color = BrandColors.coral);
    }
    if (extras.contains(SuitcaseExtra.tag)) {
      // Luggage tag on a cord from the handle.
      canvas.drawLine(
        const Offset(60, 23),
        const Offset(70, 21),
        Paint()
          ..color = BrandColors.amber
          ..strokeWidth = 1.2
          ..isAntiAlias = true,
      );
      canvas.save();
      canvas.translate(75, 22);
      canvas.rotate(0.35);
      final tag = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-6, -4.5, 13, 9), const Radius.circular(2));
      canvas.drawRRect(tag, fill..color = BrandColors.amber);
      canvas.drawCircle(const Offset(-3.6, 0), 1.1, fill..color = _seam);
      canvas.drawLine(
        const Offset(-0.5, -1.2),
        const Offset(4.5, -1.2),
        Paint()
          ..color = BrandColors.navy
          ..strokeWidth = 0.9,
      );
      canvas.drawLine(
        const Offset(-0.5, 1.4),
        const Offset(3, 1.4),
        Paint()
          ..color = BrandColors.navy
          ..strokeWidth = 0.9,
      );
      canvas.restore();
    }
  }

  void _paintStickers(Canvas canvas, Paint fill) {
    final shown = stickers.length > maxStickers
        ? stickers.sublist(stickers.length - maxStickers)
        : stickers;
    for (final (i, s) in shown.indexed) {
      final (x, y, tilt) = _spots[i];
      final scale = i == shown.length - 1 ? lastStickerScale : 1.0;
      if (scale <= 0) continue;
      final alpha = s.faded ? 0.5 : 1.0;
      final color = _palette[s.seed % _palette.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tilt + ((s.seed >> 4) % 7 - 3) * 0.03);
      canvas.scale(scale);
      fill.color = color.withValues(alpha: alpha);
      if ((s.seed >> 8).isEven) {
        canvas.drawCircle(Offset.zero, 9.5, fill);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(-10, -8, 20, 16), const Radius.circular(3)),
            fill);
      }
      final label = TextPainter(
        text: TextSpan(
          text: s.label,
          style: TextStyle(
            fontSize: 6.4,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            color: BrandColors.navy.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SuitcasePainter old) =>
      old.stickers != stickers ||
      old.extras != extras ||
      old.lidAngle != lidAngle ||
      old.lastStickerScale != lastStickerScale;
}

/// The closed suitcase on a soft round ground, e.g. in the profile.
class SuitcaseView extends StatelessWidget {
  const SuitcaseView({
    super.key,
    required this.stickers,
    required this.extras,
    this.size = 112,
    this.semanticLabel,
  });

  final List<SuitcaseSticker> stickers;
  final Set<SuitcaseExtra> extras;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: BrandColors.sky.withValues(alpha: 0.45),
        ),
        padding: EdgeInsets.all(size * 0.08),
        child: CustomPaint(
          painter: SuitcasePainter(stickers: stickers, extras: extras),
        ),
      ),
    );
  }
}
