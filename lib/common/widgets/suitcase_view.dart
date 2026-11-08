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

/// The user's suitcase: an upright grooved hard-shell trolley with a
/// telescopic handle, four spinner wheels, city stickers and earned extras.
/// Drawn on a 100 × 100 grid.
class SuitcasePainter extends CustomPainter {
  const SuitcasePainter({
    this.stickers = const [],
    this.extras = const {},
    this.handleOut = 0,
    this.wheelTurn = 0,
    this.shine,
    this.lastStickerScale = 1,
  });

  /// Shows the newest [maxStickers] of them.
  final List<SuitcaseSticker> stickers;
  final Set<SuitcaseExtra> extras;

  /// 0 = telescopic handle stowed, 1 = fully out.
  final double handleOut;

  /// Wheel rotation in radians, for rolling.
  final double wheelTurn;

  /// Position of a light sweep across the shell (0..1); null for none.
  final double? shine;

  /// Scale of the newest sticker, for slapping it on.
  final double lastStickerScale;

  static const maxStickers = 6;

  // Shell bounds on the grid.
  static const _l = 28.0, _r = 72.0, _t = 26.0, _b = 84.0;

  // Sticker spots on the front: (x, y, tilt).
  static const _spots = [
    (50.0, 58.0, -0.08),
    (38.0, 37.0, -0.16),
    (62.0, 39.0, 0.12),
    (38.0, 75.0, 0.1),
    (62.0, 74.0, -0.12),
    (51.0, 44.0, 0.05),
  ];

  static const _palette = [
    BrandColors.coral,
    BrandColors.amber,
    BrandColors.sky,
    Color(0xFF8FE3BF), // mint
    Color(0xFFFFFFFF),
    Color(0xFFC9B6FF), // lilac
  ];

  static const _dark = Color(0xFF141B4D);
  static const _groove = Color(0xFF2E3C8C);

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);

    final fill = Paint()..isAntiAlias = true;
    final goldGrip = extras.contains(SuitcaseExtra.goldHandle);

    // Telescopic handle behind the shell: two rods and the grip.
    final gripY = _t - 4 - 16 * handleOut.clamp(0.0, 1.2);
    final rod = Paint()
      ..color = const Color(0xFF9AA3C7)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(Offset(38, gripY), const Offset(38, _t + 4), rod);
    canvas.drawLine(Offset(62, gripY), const Offset(62, _t + 4), rod);
    canvas.drawRRect(
      RRect.fromLTRBR(35, gripY - 3, 65, gripY + 2.5, const Radius.circular(3)),
      fill..color = goldGrip ? BrandColors.amber : _dark,
    );

    // Spinner wheels: a housing and a wheel at each bottom corner.
    final goldWheels = extras.contains(SuitcaseExtra.goldWheels);
    for (final x in const [33.0, 67.0]) {
      canvas.drawRRect(
        RRect.fromLTRBR(
            x - 4, _b - 2, x + 4, _b + 3, const Radius.circular(1.5)),
        fill..color = _dark,
      );
      final c = Offset(x, _b + 6);
      canvas.drawCircle(
          c, 3.6, fill..color = goldWheels ? BrandColors.amber : _dark);
      canvas.drawLine(
        c,
        c + Offset(math.cos(wheelTurn), math.sin(wheelTurn)) * 2.8,
        Paint()
          ..color = goldWheels ? BrandColors.navy : const Color(0xFF5A66A8)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
    }

    // Shell with its grooves.
    final shell = RRect.fromLTRBR(_l, _t, _r, _b, const Radius.circular(7));
    canvas.drawRRect(shell, fill..color = BrandColors.navy);
    canvas.save();
    canvas.clipRRect(shell);
    final groove = Paint()
      ..color = _groove
      ..strokeWidth = 1.3;
    for (var x = _l + 5.5; x < _r - 3; x += 4.4) {
      canvas.drawLine(Offset(x, _t + 3), Offset(x, _b - 3), groove);
    }
    // Corner guards.
    for (final (cx, cy) in const [(_l, _t), (_r, _t), (_l, _b), (_r, _b)]) {
      canvas.drawCircle(Offset(cx, cy), 6, fill..color = _dark);
    }
    if (extras.contains(SuitcaseExtra.strap)) {
      canvas.drawRect(
          const Rect.fromLTRB(_l, 50, _r, 56), fill..color = BrandColors.coral);
    }
    if (shine case final s?) {
      // A diagonal light band sweeping left to right.
      final x = _l - 20 + (_r - _l + 40) * s;
      canvas.drawPath(
        Path()
          ..moveTo(x, _t)
          ..lineTo(x + 9, _t)
          ..lineTo(x - 6, _b)
          ..lineTo(x - 15, _b)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
    }
    canvas.restore();
    if (extras.contains(SuitcaseExtra.strap)) {
      final buckle =
          RRect.fromLTRBR(45, 49, 55, 57, const Radius.circular(1.5));
      canvas.drawRRect(buckle, fill..color = BrandColors.amber);
      canvas.drawRRect(buckle.deflate(1.8), fill..color = BrandColors.coral);
    }

    // Carry handle on top, in front of the telescopic rods.
    canvas.drawRRect(
      RRect.fromLTRBR(43, _t - 4, 57, _t + 1, const Radius.circular(2.5)),
      fill..color = _dark,
    );

    if (extras.contains(SuitcaseExtra.tag)) {
      // Luggage tag on a cord from the carry handle.
      canvas.drawLine(
        Offset(56, _t - 2),
        Offset(66, _t + 3),
        Paint()
          ..color = BrandColors.amber
          ..strokeWidth = 1.2
          ..isAntiAlias = true,
      );
      canvas.save();
      canvas.translate(70, _t + 8);
      canvas.rotate(0.5);
      final tag = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-6, -4.5, 13, 9), const Radius.circular(2));
      canvas.drawRRect(tag, fill..color = BrandColors.amber);
      canvas.drawCircle(const Offset(-3.6, 0), 1.1, fill..color = _dark);
      final ink = Paint()
        ..color = BrandColors.navy
        ..strokeWidth = 0.9;
      canvas.drawLine(const Offset(-0.5, -1.2), const Offset(4.5, -1.2), ink);
      canvas.drawLine(const Offset(-0.5, 1.4), const Offset(3, 1.4), ink);
      canvas.restore();
    }

    _paintStickers(canvas, fill);
    canvas.restore();
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
        canvas.drawCircle(Offset.zero, 8.5, fill);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(-9.5, -7, 19, 14),
                const Radius.circular(3)),
            fill);
      }
      final label = TextPainter(
        text: TextSpan(
          text: s.label,
          style: TextStyle(
            fontSize: 5.8,
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
      old.handleOut != handleOut ||
      old.wheelTurn != wheelTurn ||
      old.shine != shine ||
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
