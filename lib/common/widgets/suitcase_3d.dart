import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../utils/suitcase_progress.dart';
import 'suitcase_view.dart';

/// The suitcase as a small 3D model the user can spin all the way round:
/// a hard shell with rounded corners and grooves, four spinner wheels, the
/// telescopic and carry handles, city stickers and earned extras, lit from
/// the upper left. A fling keeps it spinning; it then settles on its front.
/// It sways gently while idle (not with reduced motion).
///
/// No 3D engine: every face is a flat shape drawn through a perspective
/// matrix, hidden faces are culled and parts are drawn back to front.
class Suitcase3D extends StatefulWidget {
  const Suitcase3D({
    super.key,
    required this.stickers,
    required this.extras,
    this.size = 180,
    this.semanticLabel,
  });

  final List<SuitcaseSticker> stickers;
  final Set<SuitcaseExtra> extras;
  final double size;
  final String? semanticLabel;

  @override
  State<Suitcase3D> createState() => _Suitcase3DState();
}

class _Suitcase3DState extends State<Suitcase3D> with TickerProviderStateMixin {
  /// Turn around the vertical axis in radians; multiples of 2π show the
  /// front.
  double _yaw = 0;
  bool _dragging = false;

  late final AnimationController _motion =
      AnimationController.unbounded(vsync: this)
        ..addListener(() => setState(() => _yaw = _motion.value));

  late final _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  static const _perPixel = 0.014;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _sway.stop();
    } else if (!_sway.isAnimating) {
      _sway.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _sway.dispose();
    super.dispose();
  }

  void _start(DragStartDetails _) {
    _motion.stop();
    _dragging = true;
    HapticFeedback.selectionClick();
  }

  void _update(DragUpdateDetails d) =>
      setState(() => _yaw += d.delta.dx * _perPixel);

  void _end(DragEndDetails d) {
    _dragging = false;
    final v = d.velocity.pixelsPerSecond.dx * _perPixel;
    _motion.value = _yaw;
    if (v.abs() < 1) return _settle();
    _motion
        .animateWith(FrictionSimulation(0.15, _yaw, v))
        .whenCompleteOrCancel(() {
      if (mounted && !_dragging) _settle();
    });
  }

  /// Springs to the nearest front view.
  void _settle() {
    final target = (_yaw / (2 * math.pi)).round() * 2 * math.pi;
    _motion.value = _yaw;
    _motion
        .animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 90, damping: 12),
      _yaw,
      target,
      0,
    ))
        .whenCompleteOrCancel(() {
      // Keep the angle small so it never drifts far from 0.
      if (mounted && !_dragging && !_motion.isAnimating) {
        _yaw -= target;
        _motion.value = _yaw;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _start,
        onHorizontalDragUpdate: _update,
        onHorizontalDragEnd: _end,
        child: AnimatedBuilder(
          animation: _sway,
          builder: (context, _) {
            final idle = _dragging || _motion.isAnimating
                ? 0.0
                : 0.32 * math.sin(_sway.value * 2 * math.pi);
            return CustomPaint(
              size: Size.square(widget.size),
              painter: _SuitcaseModelPainter(
                yaw: _yaw + idle,
                stickers: widget.stickers,
                extras: widget.extras,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A 3D point or direction in model units: x right, y down, z away from
/// the viewer.
class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;

  _V operator +(_V o) => _V(x + o.x, y + o.y, z + o.z);
  _V operator *(double s) => _V(x * s, y * s, z * s);
  double dot(_V o) => x * o.x + y * o.y + z * o.z;
}

/// One flat face: a 2D [shape] on the plane through [o] spanned by [a]
/// (local x) and [b] (local y), facing [n]. [decor] paints on it in the
/// same local coordinates.
class _Face {
  const _Face({
    required this.o,
    required this.a,
    required this.b,
    required this.n,
    required this.shape,
    required this.color,
    this.decor,
  });

  final _V o, a, b, n;
  final Path shape;
  final Color color;
  final void Function(Canvas canvas)? decor;
}

/// A face given directly by its corner points (the rounded corner strips).
class _Quad {
  const _Quad(this.points, this.n, this.color);
  final List<_V> points;
  final _V n;
  final Color color;
}

class _SuitcaseModelPainter extends CustomPainter {
  _SuitcaseModelPainter({
    required this.yaw,
    required this.stickers,
    required this.extras,
  });

  final double yaw;
  final List<SuitcaseSticker> stickers;
  final Set<SuitcaseExtra> extras;

  // Shell half sizes and corner radius, in model units.
  static const hw = 22.0, hh = 29.0, hd = 12.0, r = 5.0;

  // Seen a little from above, with perspective.
  static const _pitch = 0.33;
  static const _focal = 230.0;

  static const _navy = BrandColors.navy;
  static const _dark = Color(0xFF141B4D);
  static const _groove = Color(0xFF2E3C8C);
  static const _rod = Color(0xFF9AA3C7);

  // Light from the upper left, toward the viewer (camera space).
  static final _light = () {
    const l = _V(-0.45, -0.65, -0.62);
    return l * (1 / math.sqrt(l.dot(l)));
  }();

  late double _cy, _sy, _cp, _sp, _u;
  late Offset _center;

  _V _rot(_V p) {
    final x = p.x * _cy - p.z * _sy;
    final z1 = p.x * _sy + p.z * _cy;
    final y = p.y * _cp - z1 * _sp;
    final z = p.y * _sp + z1 * _cp;
    return _V(x, y, z);
  }

  Offset _project(_V p) {
    final q = _rot(p);
    final w = 1 + q.z / _focal;
    return _center + Offset(q.x / w, q.y / w) * _u;
  }

  /// Model -> screen, as one matrix for canvas.transform.
  Matrix4 get _view {
    final rotY = Matrix4.identity()
      ..setEntry(0, 0, _cy)
      ..setEntry(0, 2, -_sy)
      ..setEntry(2, 0, _sy)
      ..setEntry(2, 2, _cy);
    final rotX = Matrix4.identity()
      ..setEntry(1, 1, _cp)
      ..setEntry(1, 2, -_sp)
      ..setEntry(2, 1, _sp)
      ..setEntry(2, 2, _cp);
    final persp = Matrix4.identity()..setEntry(3, 2, 1 / _focal);
    return Matrix4.identity()
      ..translateByDouble(_center.dx, _center.dy, 0, 1)
      ..scaleByDouble(_u, _u, 1, 1)
      ..multiply(persp)
      ..multiply(rotX)
      ..multiply(rotY);
  }

  /// How lit a face is (0..1) and whether it faces the viewer.
  (double, bool) _lit(_V n, _V centre) {
    final rn = _rot(n);
    final rc = _rot(centre);
    final toFace = _V(rc.x, rc.y, rc.z + _focal);
    final visible = rn.dot(toFace) < 0;
    final diffuse = math.max(0.0, rn.dot(_light));
    return (0.58 + 0.42 * diffuse, visible);
  }

  void _drawFace(Canvas canvas, Matrix4 view, _Face f) {
    final (light, visible) = _lit(f.n, f.o);
    if (!visible) return;
    final plane = Matrix4(f.a.x, f.a.y, f.a.z, 0, f.b.x, f.b.y, f.b.z, 0, f.n.x,
        f.n.y, f.n.z, 0, f.o.x, f.o.y, f.o.z, 1);
    canvas.save();
    canvas.transform((view.clone()..multiply(plane)).storage);
    canvas.drawPath(f.shape, Paint()..color = f.color);
    if (f.decor != null) {
      canvas.save();
      canvas.clipPath(f.shape);
      f.decor!(canvas);
      canvas.restore();
    }
    canvas.drawPath(
      f.shape,
      Paint()..color = Colors.black.withValues(alpha: (1 - light) * 0.85),
    );
    canvas.restore();
  }

  void _drawQuad(Canvas canvas, _Quad q) {
    final c = q.points.reduce((a, b) => a + b) * (1 / q.points.length);
    final (light, visible) = _lit(q.n, c);
    if (!visible) return;
    final pts = [for (final p in q.points) _project(p)];
    final path = Path()..addPolygon(pts, true);
    final color = Color.lerp(Colors.black, q.color, 1 - (1 - light) * 0.85)!;
    canvas.drawPath(path, Paint()..color = color);
    // Hairline in the same colour hides seams between strips.
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = color);
  }

  static Path _rect(double l, double t, double r, double b, [double rad = 0]) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

  /// The visible faces of a small box (wheels, handles). [sideRound]
  /// rounds the faces seen from the sides, e.g. to make a wheel.
  List<_Face> _box(_V c, double x, double y, double z, Color color,
      {double round = 1, double sideRound = 1}) {
    return [
      _Face(
          o: c + _V(0, 0, -z),
          a: const _V(1, 0, 0),
          b: const _V(0, 1, 0),
          n: const _V(0, 0, -1),
          shape: _rect(-x, -y, x, y, round),
          color: color),
      _Face(
          o: c + _V(0, 0, z),
          a: const _V(-1, 0, 0),
          b: const _V(0, 1, 0),
          n: const _V(0, 0, 1),
          shape: _rect(-x, -y, x, y, round),
          color: color),
      _Face(
          o: c + _V(x, 0, 0),
          a: const _V(0, 0, 1),
          b: const _V(0, 1, 0),
          n: const _V(1, 0, 0),
          shape: _rect(-z, -y, z, y, sideRound),
          color: color),
      _Face(
          o: c + _V(-x, 0, 0),
          a: const _V(0, 0, -1),
          b: const _V(0, 1, 0),
          n: const _V(-1, 0, 0),
          shape: _rect(-z, -y, z, y, sideRound),
          color: color),
      _Face(
          o: c + _V(0, -y, 0),
          a: const _V(1, 0, 0),
          b: const _V(0, 0, 1),
          n: const _V(0, -1, 0),
          shape: _rect(-x, -z, x, z, round),
          color: color),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    _cy = math.cos(yaw);
    _sy = math.sin(yaw);
    _cp = math.cos(_pitch);
    _sp = math.sin(_pitch);
    _u = size.shortestSide / 104;
    _center = Offset(size.width / 2, size.height / 2 + 6 * _u);
    final view = _view;

    final strap = extras.contains(SuitcaseExtra.strap);
    final goldWheels = extras.contains(SuitcaseExtra.goldWheels);
    final goldGrip = extras.contains(SuitcaseExtra.goldHandle);

    // Ground shadow on the floor plane under the wheels.
    canvas.save();
    canvas.transform((view.clone()
          ..multiply(
              Matrix4(1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, hh + 9.5, 0, 1)))
        .storage);
    canvas.drawRRect(
      RRect.fromLTRBR(
          -hw - 3, -hd - 3, hw + 3, hd + 3, const Radius.circular(10)),
      Paint()
        ..color = const Color(0x30000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();

    // Wheels: a caster housing and a round wheel under each corner.
    final wheels = <(double, List<_Face>)>[];
    for (final sx in const [-1.0, 1.0]) {
      for (final sz in const [-1.0, 1.0]) {
        final c = _V(sx * (hw - 5), hh + 5.2, sz * (hd - 5));
        wheels.add((
          _rot(c).z,
          [
            ..._box(_V(c.x, hh + 1.2, c.z), 3.2, 1.4, 3.2, _dark),
            ..._box(c, 2.3, 3.6, 3.6, goldWheels ? BrandColors.amber : _dark,
                round: 1.6, sideRound: 3.6),
          ]
        ));
      }
    }
    wheels.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (depth, faces) in wheels) {
      if (depth > 0) {
        for (final f in faces) {
          _drawFace(canvas, view, f);
        }
      }
    }

    // Shell: four flat sides, the top, and rounded corner strips.
    final band = strap ? (-5.0, 1.0) : null;
    void sideDecor(Canvas c, double half, {bool front = false}) {
      final g = Paint()
        ..color = _groove
        ..strokeWidth = 1.2;
      for (var x = -half + 2.5; x <= half - 2.4; x += 4.4) {
        c.drawLine(Offset(x, -hh + 3), Offset(x, hh - 3), g);
      }
      if (band != null) {
        c.drawRect(Rect.fromLTRB(-half - 1, band.$1, half + 1, band.$2),
            Paint()..color = BrandColors.coral);
      }
      if (front) _frontDecor(c);
    }

    final faces = <_Face>[
      _Face(
        o: const _V(0, 0, -hd),
        a: const _V(1, 0, 0),
        b: const _V(0, 1, 0),
        n: const _V(0, 0, -1),
        shape: _rect(-hw + r, -hh, hw - r, hh),
        color: _navy,
        decor: (c) => sideDecor(c, hw - r, front: true),
      ),
      _Face(
        o: const _V(0, 0, hd),
        a: const _V(-1, 0, 0),
        b: const _V(0, 1, 0),
        n: const _V(0, 0, 1),
        shape: _rect(-hw + r, -hh, hw - r, hh),
        color: _navy,
        decor: (c) => sideDecor(c, hw - r),
      ),
      for (final s in const [-1.0, 1.0])
        _Face(
          o: _V(s * hw, 0, 0),
          a: _V(0, 0, s),
          b: const _V(0, 1, 0),
          n: _V(s, 0, 0),
          shape: _rect(-hd + r, -hh, hd - r, hh),
          color: _navy,
          decor: (c) {
            sideDecor(c, hd - r);
            // Side carry handle.
            c.drawRRect(
                RRect.fromLTRBR(-4.5, -14, 4.5, -10, const Radius.circular(2)),
                Paint()..color = _dark);
          },
        ),
      _Face(
        o: const _V(0, -hh, 0),
        a: const _V(1, 0, 0),
        b: const _V(0, 0, 1),
        n: const _V(0, -1, 0),
        shape: _rect(-hw, -hd, hw, hd, r),
        color: _navy,
        decor: (c) => c.drawRRect(
            RRect.fromLTRBR(
                -12, hd - 6, 12, hd - 2.5, const Radius.circular(1.5)),
            Paint()..color = _dark),
      ),
    ];
    for (final f in faces) {
      _drawFace(canvas, view, f);
    }
    for (final (cx, cz, from) in const [
      (1.0, 1.0, 0.0),
      (1.0, -1.0, -0.5),
      (-1.0, 1.0, 0.5),
      (-1.0, -1.0, 1.0),
    ]) {
      for (var i = 0; i < 4; i++) {
        for (final q in _cornerStrip(cx, cz, (from + i / 8) * math.pi,
            (from + (i + 1) / 8) * math.pi, band)) {
          _drawQuad(canvas, q);
        }
      }
    }

    for (final (depth, faces) in wheels) {
      if (depth <= 0) {
        for (final f in faces) {
          _drawFace(canvas, view, f);
        }
      }
    }

    // Handles on top, farthest first.
    final grip = goldGrip ? BrandColors.amber : _dark;
    final handles = [
      for (final x in const [-10.0, 10.0])
        _box(_V(x, -hh - 8, hd - 4.2), 0.9, 8, 0.9, _rod, round: 0.5),
      _box(const _V(0, -hh - 17.5, hd - 4.2), 13, 1.7, 1.9, grip),
      _box(const _V(0, -hh - 1.5, -2), 7, 1.4, 1.8, _dark),
    ]..sort((a, b) => _rot(b[4].o).z.compareTo(_rot(a[4].o).z));
    for (final h in handles) {
      for (final f in h) {
        _drawFace(canvas, view, f);
      }
    }
  }

  /// One segment of a rounded vertical corner, split around the strap.
  List<_Quad> _cornerStrip(
      double sx, double sz, double t0, double t1, (double, double)? band) {
    final cx = sx * (hw - r), cz = sz * (hd - r);
    _V at(double t, double y) =>
        _V(cx + r * math.cos(t), y, cz + r * math.sin(t));
    final tm = (t0 + t1) / 2;
    final n = _V(math.cos(tm), 0, math.sin(tm));
    final spans = band == null
        ? [(-hh, hh, _navy)]
        : [
            (-hh, band.$1, _navy),
            (band.$1, band.$2, BrandColors.coral),
            (band.$2, hh, _navy),
          ];
    return [
      for (final (y0, y1, color) in spans)
        _Quad([at(t0, y0), at(t1, y0), at(t1, y1), at(t0, y1)], n, color),
    ];
  }

  /// Stickers, strap buckle and luggage tag on the front, in front-face
  /// coordinates (origin at the centre of the shell).
  void _frontDecor(Canvas canvas) {
    final fill = Paint()..isAntiAlias = true;
    if (extras.contains(SuitcaseExtra.strap)) {
      final buckle = RRect.fromLTRBR(-5, -6, 5, 2, const Radius.circular(1.5));
      canvas.drawRRect(buckle, fill..color = BrandColors.amber);
      canvas.drawRRect(buckle.deflate(1.8), fill..color = BrandColors.coral);
    }
    const spots = [
      (0.0, 3.0, -0.08),
      (-8.0, -17.0, -0.16),
      (8.0, -15.0, 0.12),
      (-8.0, 19.0, 0.1),
      (8.0, 18.0, -0.12),
      (1.0, -10.0, 0.05),
    ];
    const palette = [
      BrandColors.coral,
      BrandColors.amber,
      BrandColors.sky,
      Color(0xFF8FE3BF),
      Color(0xFFFFFFFF),
      Color(0xFFC9B6FF),
    ];
    final shown = stickers.length > spots.length
        ? stickers.sublist(stickers.length - spots.length)
        : stickers;
    for (final (i, s) in shown.indexed) {
      final (x, y, tilt) = spots[i];
      final alpha = s.faded ? 0.5 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tilt + ((s.seed >> 4) % 7 - 3) * 0.03);
      canvas.scale(0.85);
      fill.color = palette[s.seed % palette.length].withValues(alpha: alpha);
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
    if (extras.contains(SuitcaseExtra.tag)) {
      canvas.drawLine(
        const Offset(4, -hh),
        const Offset(9, -hh + 6),
        Paint()
          ..color = BrandColors.amber
          ..strokeWidth = 1,
      );
      canvas.save();
      canvas.translate(11, -hh + 9);
      canvas.rotate(0.35);
      final tag = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, -4, 11, 8), const Radius.circular(2));
      canvas.drawRRect(tag, fill..color = BrandColors.amber);
      canvas.drawCircle(const Offset(-2.6, 0), 1, fill..color = _dark);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SuitcaseModelPainter old) =>
      old.yaw != yaw || old.stickers != stickers || old.extras != extras;
}
