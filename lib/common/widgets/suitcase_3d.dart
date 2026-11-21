import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../utils/suitcase_progress.dart';
import 'suitcase_view.dart';

/// The suitcase as a small 3D model the user can spin all the way round:
/// a matt metal shell with bevelled edges, ribs, a frame with a latch, metal
/// corner caps, four double spinner wheels, the telescopic and carry handles,
/// city stickers and earned extras, lit from the upper left. A fling keeps
/// it spinning; it then settles on its front. It sways gently while idle
/// (not with reduced motion).
///
/// No 3D engine: every face is a flat shape drawn through a perspective
/// matrix, hidden faces are culled and parts are drawn back to front. The
/// model is built once; a turn only repaints (no rebuild, no layout).
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

  /// What the painter draws: [_yaw] plus the idle sway.
  final _angle = ValueNotifier<double>(0);

  late final AnimationController _motion =
      AnimationController.unbounded(vsync: this)
        ..addListener(() {
          _yaw = _motion.value;
          _show();
        });

  late final _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..addListener(_show);

  static const _perPixel = 0.014;

  void _show() {
    final idle = _dragging || _motion.isAnimating
        ? 0.0
        : 0.32 * math.sin(_sway.value * 2 * math.pi);
    _angle.value = _yaw + idle;
  }

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
    _angle.dispose();
    super.dispose();
  }

  void _start(DragStartDetails _) {
    _motion.stop();
    _dragging = true;
    HapticFeedback.selectionClick();
  }

  void _update(DragUpdateDetails d) {
    _yaw += d.delta.dx * _perPixel;
    _show();
  }

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
        // Its own layer: a turn repaints the suitcase, not the card.
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _SuitcaseModelPainter(
              yaw: _angle,
              stickers: widget.stickers,
              extras: widget.extras,
            ),
          ),
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
  _Face({
    required this.o,
    required this.a,
    required this.b,
    required this.n,
    required this.shape,
    required this.color,
    this.decor,
  }) : plane = Matrix4(a.x, a.y, a.z, 0, b.x, b.y, b.z, 0, n.x, n.y, n.z, 0,
            o.x, o.y, o.z, 1);

  final _V o, a, b, n;
  final Path shape;
  final Color color;
  final void Function(Canvas canvas)? decor;

  /// Face coordinates -> model.
  final Matrix4 plane;
}

/// A face given directly by its corner points (the rounded corner strips).
class _Quad {
  _Quad(this.points, this.n, this.color)
      : centre = points.reduce((a, b) => a + b) * (1 / points.length);
  final List<_V> points;
  final _V n, centre;
  final Color color;
}

/// A part that is sorted by depth as a whole (a wheel, a handle).
class _Part {
  const _Part(this.at, this.faces);
  final _V at;
  final List<_Face> faces;
}

class _SuitcaseModelPainter extends CustomPainter {
  _SuitcaseModelPainter({
    required this.yaw,
    required this.stickers,
    required this.extras,
  }) : super(repaint: yaw);

  final ValueListenable<double> yaw;
  final List<SuitcaseSticker> stickers;
  final Set<SuitcaseExtra> extras;

  // Shell half sizes, corner radius and the bevel around the top, in model
  // units.
  static const hw = 22.0, hh = 29.0, hd = 12.0, r = 5.0, c = 2.2;
  static const _s2 = math.sqrt1_2;

  // Seen a little from above, with perspective.
  static const _pitch = 0.33;
  static const _focal = 230.0;

  static const _navy = BrandColors.navy;
  static const _dark = BrandColors.navyDeep;
  static const _lite = BrandColors.navyLight;
  static const _steel = Color(0xFFB4BCD9);
  static const _steelDark = Color(0xFF7C86B0);

  // Light from the upper left, toward the viewer (camera space).
  static final _light = () {
    const l = _V(-0.45, -0.65, -0.62);
    return l * (1 / math.sqrt(l.dot(l)));
  }();

  /// The light a face straight toward the viewer gets: neither lit nor
  /// shaded.
  static const _neutral = 0.38;

  late double _cy, _sy, _cp, _sp, _u;
  late Offset _center;

  bool get _strap => extras.contains(SuitcaseExtra.strap);
  (double, double)? get _band => _strap ? (-5.0, 1.0) : null;

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

  /// The veil that lights or shades a face with normal [n] around
  /// [centre]; null when the face looks away from the viewer.
  Color? _veil(_V n, _V centre) {
    final rn = _rot(n);
    final rc = _rot(centre);
    if (rn.dot(_V(rc.x, rc.y, rc.z + _focal)) >= 0) return null;
    final k = rn.dot(_light) - _neutral;
    return k < 0
        ? Colors.black.withValues(alpha: math.min(0.5, -k * 0.46))
        : Colors.white.withValues(alpha: k * 0.16);
  }

  final _paint = Paint();
  final _seam = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6;

  void _drawFace(Canvas canvas, Matrix4 view, _Face f) {
    final veil = _veil(f.n, f.o);
    if (veil == null) return;
    canvas.save();
    canvas.transform(view.multiplied(f.plane).storage);
    canvas.drawPath(f.shape, _paint..color = f.color);
    if (f.decor != null) {
      canvas.save();
      canvas.clipPath(f.shape);
      f.decor!(canvas);
      canvas.restore();
    }
    canvas.drawPath(f.shape, _paint..color = veil);
    canvas.restore();
  }

  void _drawQuad(Canvas canvas, _Quad q) {
    final veil = _veil(q.n, q.centre);
    if (veil == null) return;
    final path = Path()
      ..addPolygon([for (final p in q.points) _project(p)], true);
    final color = Color.alphaBlend(veil, q.color);
    canvas.drawPath(path, _paint..color = color);
    // Hairline in the same colour hides seams between strips.
    canvas.drawPath(path, _seam..color = color);
  }

  void _drawParts(Canvas canvas, Matrix4 view, List<_Part> parts,
      {bool? behind}) {
    final sorted = [for (final p in parts) (_rot(p.at).z, p)]
      ..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (depth, part) in sorted) {
      if (behind != null && (depth > 0) != behind) continue;
      for (final f in part.faces) {
        _drawFace(canvas, view, f);
      }
    }
  }

  static Path _rect(double l, double t, double r, double b, [double rad = 0]) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

  /// The visible faces of a small box (wheels, handles). [sideRound]
  /// rounds the faces seen from the sides, e.g. to make a wheel; [sideDecor]
  /// paints on them.
  static List<_Face> _box(_V c, double x, double y, double z, Color color,
      {double round = 1,
      double sideRound = 1,
      void Function(Canvas canvas)? sideDecor}) {
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
          color: color,
          decor: sideDecor),
      _Face(
          o: c + _V(-x, 0, 0),
          a: const _V(0, 0, -1),
          b: const _V(0, 1, 0),
          n: const _V(-1, 0, 0),
          shape: _rect(-z, -y, z, y, sideRound),
          color: color,
          decor: sideDecor),
      _Face(
          o: c + _V(0, -y, 0),
          a: const _V(1, 0, 0),
          b: const _V(0, 0, 1),
          n: const _V(0, -1, 0),
          shape: _rect(-x, -z, x, z, round),
          color: color),
    ];
  }

  // ---- The model, built once per painter ----

  /// Moulded ribs across a face [half] wide, [n] of them: a dark groove
  /// with a lit edge beside it.
  static (Path, Path) _ribs(int n, {double from = -hh + c + 4}) {
    final groove = Path(), edge = Path();
    for (var i = 0; i < n; i++) {
      final x = (i - (n - 1) / 2) * 4.4;
      groove
        ..moveTo(x, from)
        ..lineTo(x, hh - 5);
      edge
        ..moveTo(x + 0.8, from)
        ..lineTo(x + 0.8, hh - 5);
    }
    return (groove, edge);
  }

  static final _frontRibs = _ribs(7);
  static final _backRibs = _ribs(3, from: -hh + c + 9);

  static final _groovePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.3
    ..color = _dark;
  static final _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.5
    ..color = _lite.withValues(alpha: 0.7);

  /// Matt metal has no gloss: only a faint falloff toward the floor.
  static final _gloss = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0, -hh),
      const Offset(0, hh),
      const [Color(0x00000000), Color(0x00000000), Color(0x1F000000)],
      const [0, 0.5, 1],
    );

  static final _frameRail = Paint()
    ..strokeWidth = 2
    ..color = _steelDark;
  static final _frameGap = Paint()
    ..strokeWidth = 0.4
    ..color = _dark;

  /// The metal frame where the two half shells close, along local x = 0.
  static void _frame(Canvas canvas, double from, double to) {
    canvas.drawLine(Offset(0, from), Offset(0, to), _frameRail);
    canvas.drawLine(Offset(0, from), Offset(0, to), _frameGap);
  }

  void _strapBand(Canvas canvas, double half) {
    final band = _band;
    if (band == null) return;
    canvas.drawRect(Rect.fromLTRB(-half - 1, band.$1, half + 1, band.$2),
        _paint..color = BrandColors.coral);
  }

  late final List<_Face> _shell = [
    // Front.
    _Face(
      o: const _V(0, 0, -hd),
      a: const _V(1, 0, 0),
      b: const _V(0, 1, 0),
      n: const _V(0, 0, -1),
      shape: _rect(-hw + r, -hh + c, hw - r, hh),
      color: _navy,
      decor: (canvas) {
        canvas.drawPath(_frontRibs.$1, _groovePaint);
        canvas.drawPath(_frontRibs.$2, _edgePaint);
        canvas.drawPaint(_gloss);
        // Maker's plate.
        canvas.drawRRect(
            RRect.fromLTRBR(-3, -25.2, 3, -23, const Radius.circular(0.7)),
            _paint..color = _steel);
        _strapBand(canvas, hw - r);
        _frontDecor(canvas);
      },
    ),
    // Back: the two rails the telescopic handle slides in.
    _Face(
      o: const _V(0, 0, hd),
      a: const _V(-1, 0, 0),
      b: const _V(0, 1, 0),
      n: const _V(0, 0, 1),
      shape: _rect(-hw + r, -hh + c, hw - r, hh),
      color: _navy,
      decor: (canvas) {
        for (final x in const [-10.0, 10.0]) {
          canvas.drawRRect(
              RRect.fromLTRBR(
                  x - 2, -hh, x + 2, hh - 8, const Radius.circular(2)),
              _paint..color = _dark);
          canvas.drawLine(
              Offset(x + 2.4, -hh + 4), Offset(x + 2.4, hh - 10), _edgePaint);
        }
        canvas.drawPath(_backRibs.$1, _groovePaint);
        canvas.drawPath(_backRibs.$2, _edgePaint);
        canvas.drawPaint(_gloss);
        _strapBand(canvas, hw - r);
      },
    ),
    // Sides: the frame, a latch on the right and a carry handle on the left.
    for (final s in const [-1.0, 1.0])
      _Face(
        o: _V(s * hw, 0, 0),
        a: _V(0, 0, s),
        b: const _V(0, 1, 0),
        n: _V(s, 0, 0),
        shape: _rect(-hd + r, -hh + c, hd - r, hh),
        color: _navy,
        decor: (canvas) {
          canvas.drawPaint(_gloss);
          _frame(canvas, -hh, hh);
          _strapBand(canvas, hd - r);
          if (s > 0) {
            // Latch.
            canvas.drawRRect(
                RRect.fromLTRBR(-2.8, -17, 2.8, -10, const Radius.circular(1)),
                _paint..color = _dark);
            canvas.drawRRect(
                RRect.fromLTRBR(
                    -1.9, -16.2, 1.9, -13.6, const Radius.circular(0.5)),
                _paint..color = _steel);
            canvas.drawCircle(
                const Offset(0, -11.6), 0.9, _paint..color = _steelDark);
          } else {
            // Long grab handle on the back half, between two mounts.
            canvas.drawRRect(
                RRect.fromLTRBR(
                    -5.6, -10, -2.6, 10, const Radius.circular(1.5)),
                _paint..color = _dark);
            canvas.drawRRect(
                RRect.fromLTRBR(
                    -4.9, -6.5, -3.3, 6.5, const Radius.circular(0.8)),
                _paint..color = _lite);
          }
        },
      ),
    // Top.
    _Face(
      o: const _V(0, -hh, 0),
      a: const _V(1, 0, 0),
      b: const _V(0, 0, 1),
      n: const _V(0, -1, 0),
      shape: _rect(-hw + c, -hd + c, hw - c, hd - c, r - c),
      color: _navy,
      decor: (canvas) {
        canvas.save();
        canvas.rotate(math.pi / 2);
        _frame(canvas, -hw, hw);
        canvas.restore();
        // Bezel of the telescopic handle and its two sockets.
        canvas.drawRRect(
            RRect.fromLTRBR(
                -13, hd - 6.6, 13, hd - 2.6, const Radius.circular(2)),
            _paint..color = _dark);
        for (final x in const [-10.0, 10.0]) {
          canvas.drawCircle(Offset(x, hd - 4.6), 1.5, _paint..color = _lite);
        }
        // Mounts of the carry handle.
        for (final x in const [-7.5, 7.5]) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: Offset(x, -5), width: 3.6, height: 4.6),
                  const Radius.circular(1)),
              _paint..color = _dark);
        }
      },
    ),
    // Bevel between the top and the four sides.
    for (final (d, a, half, dist) in const [
      (_V(0, 0, -1), _V(1, 0, 0), hw - r, hd),
      (_V(0, 0, 1), _V(-1, 0, 0), hw - r, hd),
      (_V(1, 0, 0), _V(0, 0, 1), hd - r, hw),
      (_V(-1, 0, 0), _V(0, 0, -1), hd - r, hw),
    ])
      _Face(
        o: d * (dist - c / 2) + const _V(0, -hh + c / 2, 0),
        a: a,
        b: (d + const _V(0, 1, 0)) * _s2,
        n: (d + const _V(0, -1, 0)) * _s2,
        shape: _rect(-half, -c * _s2, half, c * _s2),
        color: _navy,
        decor: d.x != 0 ? (canvas) => _frame(canvas, -c, c) : null,
      ),
  ];

  /// The rounded vertical corners with their bevel on top, as strips.
  late final List<_Quad> _corners = [
    for (final (sx, sz, from) in const [
      (1.0, 1.0, 0.0),
      (1.0, -1.0, -0.5),
      (-1.0, 1.0, 0.5),
      (-1.0, -1.0, 1.0),
    ])
      for (var i = 0; i < 4; i++)
        ..._cornerStrip(
            sx, sz, (from + i / 8) * math.pi, (from + (i + 1) / 8) * math.pi),
  ];

  /// One segment of a rounded corner: guards at both ends, the strap
  /// around the middle, and the bevel up to the top.
  List<_Quad> _cornerStrip(double sx, double sz, double t0, double t1) {
    final cx = sx * (hw - r), cz = sz * (hd - r);
    _V at(double t, double y, [double rad = r]) =>
        _V(cx + rad * math.cos(t), y, cz + rad * math.sin(t));
    final tm = (t0 + t1) / 2;
    final n = _V(math.cos(tm), 0, math.sin(tm));
    const top = -hh + c;
    final band = _band;
    final spans = [
      (top, top + 5.5, _steelDark),
      if (band == null)
        (top + 5.5, hh - 7, _navy)
      else ...[
        (top + 5.5, band.$1, _navy),
        (band.$1, band.$2, BrandColors.coral),
        (band.$2, hh - 7, _navy),
      ],
      (hh - 7, hh, _steelDark),
    ];
    return [
      _Quad(
        [at(t0, -hh, r - c), at(t1, -hh, r - c), at(t1, top), at(t0, top)],
        (n + const _V(0, -1, 0)) * _s2,
        _steelDark,
      ),
      for (final (y0, y1, color) in spans)
        _Quad([at(t0, y0), at(t1, y0), at(t1, y1), at(t0, y1)], n, color),
    ];
  }

  /// A caster under each corner: housing, fork and a double wheel.
  late final List<_Part> _wheels = () {
    final gold = extras.contains(SuitcaseExtra.goldWheels);
    final tyre = gold ? BrandColors.amber : _dark;
    final hub = _paint;
    void hubcap(Canvas canvas) {
      canvas.drawCircle(Offset.zero, 2.1, hub..color = gold ? _navy : _lite);
      canvas.drawCircle(Offset.zero, 0.9, hub..color = _steel);
    }

    return [
      for (final sx in const [-1.0, 1.0])
        for (final sz in const [-1.0, 1.0])
          () {
            final at = _V(sx * (hw - 5), hh + 5.2, sz * (hd - 5));
            return _Part(at, [
              ..._box(_V(at.x, hh + 1.2, at.z), 4, 1.5, 3.6, _dark, round: 1.4),
              ..._box(_V(at.x, hh + 3.6, at.z), 0.5, 2, 1.6, _steelDark),
              // The wheel toward the middle first: the outer one covers it.
              for (final side in [-sx, sx])
                ..._box(at + _V(side * 2, 0, 0), 1.5, 3.6, 3.6, tyre,
                    round: 1.3, sideRound: 3.6, sideDecor: hubcap),
            ]);
          }(),
    ];
  }();

  /// Telescopic handle (sleeves, rods, grip with its release button) and
  /// the carry handle on top.
  late final List<_Part> _handles = () {
    final grip =
        extras.contains(SuitcaseExtra.goldHandle) ? BrandColors.amber : _dark;
    const z = hd - 4.6;
    return [
      for (final x in const [-10.0, 10.0]) ...[
        _Part(_V(x, -hh - 3, z),
            _box(_V(x, -hh - 3, z), 1.3, 3, 1.3, _steelDark, round: 0.6)),
        _Part(_V(x, -hh - 11, z),
            _box(_V(x, -hh - 11, z), 0.8, 5, 0.8, _steel, round: 0.4)),
      ],
      _Part(const _V(0, -hh - 17.5, z), [
        ..._box(const _V(0, -hh - 17.5, z), 13, 1.8, 2, grip, round: 1.6),
        ..._box(const _V(0, -hh - 19.5, z), 2.6, 0.3, 1.1, _steel, round: 0.3),
      ]),
      _Part(const _V(0, -hh - 1.6, -5),
          _box(const _V(0, -hh - 1.6, -5), 9, 1.5, 1.7, _dark, round: 1.4)),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final yaw = this.yaw.value;
    _cy = math.cos(yaw);
    _sy = math.sin(yaw);
    _cp = math.cos(_pitch);
    _sp = math.sin(_pitch);
    _u = size.shortestSide / 98;
    _center = Offset(size.width / 2, size.height / 2 + 5.5 * _u);
    final view = _view;

    // Ground shadow on the floor plane under the wheels: a soft gradient,
    // cheaper than a blur.
    canvas.save();
    canvas.transform(view
        .multiplied(
            Matrix4(1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, hh + 8.9, 0, 1))
        .storage);
    canvas.scale(1, (hd + 8) / (hw + 8));
    canvas.drawCircle(Offset.zero, hw + 8, _shadow);
    canvas.restore();

    _drawParts(canvas, view, _wheels, behind: true);
    for (final f in _shell) {
      _drawFace(canvas, view, f);
    }
    for (final q in _corners) {
      _drawQuad(canvas, q);
    }
    _drawParts(canvas, view, _wheels, behind: false);
    _drawParts(canvas, view, _handles);
  }

  static final _shadow = Paint()
    ..shader = ui.Gradient.radial(
      Offset.zero,
      hw + 8,
      const [Color(0x47000000), Color(0x24000000), Color(0x00000000)],
      const [0, 0.55, 1],
    );

  static const _spots = [
    (0.0, 3.0, -0.08),
    (-8.0, -15.0, -0.16),
    (8.0, -13.5, 0.12),
    (-8.0, 19.0, 0.1),
    (8.0, 18.0, -0.12),
    (1.0, -9.0, 0.05),
  ];
  static const _palette = [
    BrandColors.coral,
    BrandColors.amber,
    BrandColors.sky,
    Color(0xFF8FE3BF),
    Color(0xFFFFFFFF),
    Color(0xFFC9B6FF),
  ];

  late final List<SuitcaseSticker> _shown = stickers.length > _spots.length
      ? stickers.sublist(stickers.length - _spots.length)
      : stickers;

  /// Laid out once, not on every frame.
  late final List<TextPainter> _labels = [
    for (final s in _shown)
      TextPainter(
        text: TextSpan(
          text: s.label,
          style: TextStyle(
            fontSize: 5.8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            color: BrandColors.navy.withValues(alpha: s.faded ? 0.5 : 1),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
  ];

  /// Stickers, strap buckle and luggage tag on the front, in front-face
  /// coordinates (origin at the centre of the shell).
  void _frontDecor(Canvas canvas) {
    final fill = _paint;
    if (_strap) {
      final buckle = RRect.fromLTRBR(-5, -6, 5, 2, const Radius.circular(1.5));
      canvas.drawRRect(buckle, fill..color = BrandColors.amber);
      canvas.drawRRect(buckle.deflate(1.8), fill..color = BrandColors.coral);
    }
    for (final (i, s) in _shown.indexed) {
      final (x, y, tilt) = _spots[i];
      final alpha = s.faded ? 0.5 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tilt + ((s.seed >> 4) % 7 - 3) * 0.03);
      canvas.scale(0.85);
      fill.color = _palette[s.seed % _palette.length].withValues(alpha: alpha);
      if ((s.seed >> 8).isEven) {
        canvas.drawCircle(Offset.zero, 8.5, fill);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(-9.5, -7, 19, 14),
                const Radius.circular(3)),
            fill);
      }
      final label = _labels[i];
      label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
      canvas.restore();
    }
    if (extras.contains(SuitcaseExtra.tag)) {
      canvas.drawLine(
        const Offset(3, -hh + c),
        const Offset(8, -hh + 7),
        Paint()
          ..color = BrandColors.amber
          ..strokeWidth = 1,
      );
      canvas.save();
      canvas.translate(10, -hh + 10);
      canvas.rotate(0.35);
      final tag = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, -4, 11, 8), const Radius.circular(2));
      canvas.drawRRect(tag, fill..color = BrandColors.amber);
      canvas.drawCircle(const Offset(-2.6, 0), 1, fill..color = _dark);
      fill.color = _navy;
      canvas.drawRect(const Rect.fromLTWH(-0.5, -1.6, 5, 0.8), fill);
      canvas.drawRect(const Rect.fromLTWH(-0.5, 0.6, 3.4, 0.8), fill);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SuitcaseModelPainter old) =>
      old.yaw != yaw || old.stickers != stickers || old.extras != extras;
}
