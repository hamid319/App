import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

/// What the duck is doing: one per in-app moment of the Out We Go design.
enum DuckMood {
  /// Breathes and blinks (home, trips tab).
  idle,

  /// Waves a wing (a friend joined, packing done).
  wave,

  /// Hops with joy and squashes on landing (a match).
  hop,

  /// Asleep on its mattress, Zs floating up (empty or offline).
  sleep,
}

/// The Out We Go duck with its rolled-up mattress, animated per [mood].
/// Respects the system's reduce-motion setting (then it stands still).
class DuckMoment extends StatefulWidget {
  const DuckMoment({
    super.key,
    required this.mood,
    this.size = 120,
    this.onDark = false,
  });

  final DuckMood mood;
  final double size;

  /// On a forest-green ground: the sleeping duck's head turns lime and its
  /// Zs cream, as in the design.
  final bool onDark;

  @override
  State<DuckMoment> createState() => _DuckMomentState();
}

class _DuckMomentState extends State<DuckMoment>
    with SingleTickerProviderStateMixin {
  // A long linear clock; each animation takes the time modulo its period.
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (_, __) => CustomPaint(
            painter: DuckPainter(
              mood: widget.mood,
              seconds: _clock.value * 3600,
              onDark: widget.onDark,
              still: MediaQuery.of(context).disableAnimations,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the duck on the design's 220 × 220 grid (y from −10).
class DuckPainter extends CustomPainter {
  const DuckPainter({
    required this.mood,
    required this.seconds,
    this.onDark = false,
    this.still = false,
  });

  final DuckMood mood;
  final double seconds;
  final bool onDark;

  /// Reduce motion: no movement, but the Zs stay visible.
  final bool still;

  static const _ink = Color(0xFF141414);
  static const _cream = Color(0xFFFFFDF7);
  static const _wing = Color(0xFFE6E0D0);

  /// Piecewise keyframes [(time 0–1, value)], eased in and out per segment
  /// like CSS's default timing.
  static double _key(double t, List<(double, double)> frames) {
    for (var i = 1; i < frames.length; i++) {
      final (t1, v1) = frames[i];
      final (t0, v0) = frames[i - 1];
      if (t <= t1) {
        final f = t1 == t0 ? 1.0 : (t - t0) / (t1 - t0);
        return v0 + (v1 - v0) * Curves.easeInOut.transform(f);
      }
    }
    return frames.last.$2;
  }

  double _phase(double period, [double delay = 0]) =>
      ((seconds - delay) % period) / period;

  // Smooth 0 → 1 → 0 over a period (the CSS 0/50/100 % loops).
  double _wave(double period) =>
      (1 - math.cos(2 * math.pi * _phase(period))) / 2;

  Paint get _stroke => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  void _shape(Canvas canvas, Path path, Color fill, {double? stroke = 5}) {
    canvas.drawPath(
        path,
        Paint()
          ..color = fill
          ..isAntiAlias = true);
    if (stroke != null) canvas.drawPath(path, _stroke..strokeWidth = stroke);
  }

  Path _rect(double x, double y, double w, double h, double r) =>
      Path()..addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(r)));

  Path _bill(double top, double r) => Path()
    ..moveTo(142, top)
    ..lineTo(174, top)
    ..arcToPoint(Offset(174 - r, top + r),
        radius: Radius.circular(r), clockwise: true)
    ..lineTo(142, top + r)
    ..close();

  // Scales the canvas about a pivot.
  void _about(Canvas canvas, Offset pivot, double sx, double sy) {
    canvas.translate(pivot.dx, pivot.dy);
    canvas.scale(sx, sy);
    canvas.translate(-pivot.dx, -pivot.dy);
  }

  void _rotateAbout(Canvas canvas, Offset pivot, double degrees) {
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-pivot.dx, -pivot.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 220);
    canvas.translate(0, 10);
    if (mood == DuckMood.sleep) {
      _paintSleep(canvas);
    } else {
      _paintAwake(canvas);
    }
    canvas.restore();
  }

  void _paintAwake(Canvas canvas) {
    final hop = mood == DuckMood.hop;
    const pivot = Offset(110, 190);

    // Character transform: breathe, or hop with squash and stretch.
    var dy = 0.0, sx = 1.0, sy = 1.0, shadow = 1.0, shadowAlpha = 1.0;
    if (hop) {
      final t = _phase(1.2);
      const frames = [0.0, 0.15, 0.45, 0.75, 0.88, 1.0];
      dy = _key(t, [
        for (final (i, v) in [0.0, 0, -34, 0, 0, 0].indexed)
          (frames[i], v.toDouble())
      ]);
      sx = _key(t, [
        for (final (i, v) in [1.1, .94, .97, 1.12, .98, 1.1].indexed)
          (frames[i], v)
      ]);
      sy = _key(t, [
        for (final (i, v) in [.88, 1.08, 1.04, .86, 1.03, .88].indexed)
          (frames[i], v)
      ]);
      shadow = _key(t, [(0, 1), (.15, 1), (.45, .6), (.75, 1), (1, 1)]);
      shadowAlpha = _key(t, [(0, 1), (.15, 1), (.45, .5), (.75, 1), (1, 1)]);
    } else {
      final b = _wave(2.6);
      sx = 1 - 0.015 * b;
      sy = 1 + 0.03 * b;
    }

    // Shadow stays on the ground.
    canvas.save();
    _about(canvas, const Offset(110, 192), shadow, shadow);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(110, 192), width: 112, height: 12),
      Paint()..color = _ink.withValues(alpha: 0.15 * shadowAlpha),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(0, dy);
    _about(canvas, pivot, sx, sy);

    // Backpack and the rolled mattress on it, wobbling.
    _shape(canvas, _rect(44, 98, 32, 58, 12), BrandColors.forest);
    canvas.save();
    final wobble = mood == DuckMood.wave
        ? 0.0
        : math.sin(2 * math.pi * _phase(hop ? 0.6 : 2.6)) * 3;
    _rotateAbout(canvas, const Offset(59, 96), wobble);
    _shape(canvas, _rect(34, 74, 50, 22, 11), BrandColors.orange);
    canvas.restore();

    // Feet, body, head, bill.
    _shape(canvas, _rect(84, 176, 26, 12, 6), BrandColors.orange);
    _shape(canvas, _rect(112, 176, 26, 12, 6), BrandColors.orange);
    _shape(canvas, _rect(68, 90, 76, 92, 38), _cream);
    _shape(
      canvas,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(116, 60), radius: 32)),
      BrandColors.forest,
    );
    _shape(canvas, hop ? _bill(50, 18) : _bill(52, 16), BrandColors.orange);

    if (hop) {
      // Happy closed eye.
      canvas.drawPath(
        Path()
          ..moveTo(116, 58)
          ..quadraticBezierTo(124, 46, 132, 58),
        _stroke..color = _cream,
      );
    } else {
      // Blink: squash the eye for a moment every 4 s.
      final t = _phase(4);
      final open = _key(t, [(0, 1), (.92, 1), (.95, .1), (1, 1)]);
      canvas.save();
      _about(canvas, const Offset(124, 54), 1, open);
      canvas.drawCircle(
          const Offset(124, 54), 8, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(126, 54), 4.5, Paint()..color = _ink);
      canvas.restore();
    }

    // Wing; it waves in the wave mood.
    final wing = Path()
      ..moveTo(94, 118)
      ..arcToPoint(const Offset(120, 144),
          radius: const Radius.circular(26), clockwise: false)
      ..lineTo(120, 118)
      ..close();
    canvas.save();
    if (mood == DuckMood.wave) {
      final angle = _key(_phase(1.4),
          [(0, 0), (.25, -110), (.45, -80), (.65, -115), (.85, -20), (1, 0)]);
      _rotateAbout(canvas, const Offset(120, 118), angle);
      _shape(canvas, wing, _wing, stroke: 4);
    } else {
      _shape(canvas, wing, _wing, stroke: null);
    }
    canvas.restore();

    canvas.restore();
  }

  void _paintSleep(Canvas canvas) {
    final zColor = onDark ? _cream : BrandColors.forest;

    // The mattress, rolled out.
    _shape(canvas, _rect(20, 168, 170, 22, 11), BrandColors.orange);

    canvas.save();
    final s = _wave(3.6);
    _about(canvas, const Offset(110, 190), 1 + 0.03 * s, 1 - 0.03 * s);
    _shape(canvas, _rect(68, 98, 76, 76, 38), _cream);
    _shape(
      canvas,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(116, 74), radius: 32)),
      onDark ? BrandColors.lime : BrandColors.forest,
    );
    _shape(canvas, _bill(70, 16), BrandColors.orange);
    canvas.drawPath(
      Path()
        ..moveTo(116, 70)
        ..quadraticBezierTo(124, 78, 132, 70),
      _stroke
        ..strokeWidth = 4.5
        ..color = onDark ? _ink : _cream,
    );
    canvas.restore();

    // Three Zs floating up one after another.
    for (final (x, size, delay) in const [
      (150.0, 22.0, 0.0),
      (160.0, 18.0, 1.2),
      (168.0, 14.0, 2.4)
    ]) {
      final t = _phase(3.6, delay);
      final opacity = still ? 1.0 : (t < .2 ? t / .2 : 1 - (t - .2) / .8);
      final rise = still ? 0.0 : Curves.easeOut.transform(t);
      final painter = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w700,
            fontSize: size,
            color: zColor.withValues(alpha: opacity.clamp(0, 1)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // The design's y is the text baseline.
      painter.paint(canvas, Offset(x + 14 * rise, 40 - 34 * rise - size * 0.8));
    }
  }

  @override
  bool shouldRepaint(DuckPainter old) =>
      old.seconds != seconds ||
      old.mood != mood ||
      old.onDark != onDark ||
      old.still != still;
}
