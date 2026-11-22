import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/constants/colors.dart';
import '../utils/suitcase_progress.dart';
import 'suitcase_view.dart';

// A tiny software 3D renderer for the profile duck: smooth meshes built from
// parametric surfaces, lit per vertex (key, fill, sky, rim and specular
// light), sorted back to front and drawn with one Canvas.drawVertices call.
// Model units: the duck stands on y = 0, about 150 tall; x points along the
// bill, z to the duck's right.

typedef P3 = (double, double, double);

double _ss(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

extension on P3 {
  P3 sub(P3 o) => ($1 - o.$1, $2 - o.$2, $3 - o.$3);
}

double _sp(double a, double e) => a.sign * math.pow(a.abs(), e).toDouble();

/// Unit sphere direction for u (around, 0–1) and v (top to bottom, 0–1).
P3 _dir(double u, double v) {
  final t = 2 * math.pi * u, p = math.pi * v;
  return (math.sin(p) * math.cos(t), math.cos(p), math.sin(p) * math.sin(t));
}

/// An affine transform, row-major 3 × 4.
class _Xf {
  _Xf(this.m);
  final Float64List m;

  factory _Xf.of(List<double> v) => _Xf(Float64List.fromList(v));
  static final identity = _Xf.of([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]);
  factory _Xf.t(double x, double y, double z) =>
      _Xf.of([1, 0, 0, x, 0, 1, 0, y, 0, 0, 1, z]);
  factory _Xf.p(P3 p) => _Xf.t(p.$1, p.$2, p.$3);
  factory _Xf.s(double x, double y, double z) =>
      _Xf.of([x, 0, 0, 0, 0, y, 0, 0, 0, 0, z, 0]);
  factory _Xf.rx(double a) {
    final c = math.cos(a), s = math.sin(a);
    return _Xf.of([1, 0, 0, 0, 0, c, -s, 0, 0, s, c, 0]);
  }
  factory _Xf.ry(double a) {
    final c = math.cos(a), s = math.sin(a);
    return _Xf.of([c, 0, s, 0, 0, 1, 0, 0, -s, 0, c, 0]);
  }
  factory _Xf.rz(double a) {
    final c = math.cos(a), s = math.sin(a);
    return _Xf.of([c, -s, 0, 0, s, c, 0, 0, 0, 0, 1, 0]);
  }

  /// [r] applied about the pivot [p].
  static _Xf about(P3 p, _Xf r) => _Xf.p(p) * r * _Xf.t(-p.$1, -p.$2, -p.$3);

  _Xf operator *(_Xf o) {
    final a = m, b = o.m, r = Float64List(12);
    for (var i = 0; i < 12; i += 4) {
      final a0 = a[i], a1 = a[i + 1], a2 = a[i + 2];
      r[i] = a0 * b[0] + a1 * b[4] + a2 * b[8];
      r[i + 1] = a0 * b[1] + a1 * b[5] + a2 * b[9];
      r[i + 2] = a0 * b[2] + a1 * b[6] + a2 * b[10];
      r[i + 3] = a0 * b[3] + a1 * b[7] + a2 * b[11] + a[i + 3];
    }
    return _Xf(r);
  }

  P3 apply(P3 p) => (
        m[0] * p.$1 + m[1] * p.$2 + m[2] * p.$3 + m[3],
        m[4] * p.$1 + m[5] * p.$2 + m[6] * p.$3 + m[7],
        m[8] * p.$1 + m[9] * p.$2 + m[10] * p.$3 + m[11],
      );

  /// Cofactor matrix: turns normals correctly under scaling (up to length).
  Float64List normals() {
    final a = m;
    return Float64List.fromList([
      a[5] * a[10] - a[6] * a[9],
      a[6] * a[8] - a[4] * a[10],
      a[4] * a[9] - a[5] * a[8],
      a[2] * a[9] - a[1] * a[10],
      a[0] * a[10] - a[2] * a[8],
      a[1] * a[8] - a[0] * a[9],
      a[1] * a[6] - a[2] * a[5],
      a[2] * a[4] - a[0] * a[6],
      a[0] * a[5] - a[1] * a[4],
    ]);
  }
}

/// How a surface takes light.
class _Mat {
  const _Mat(this.spec, this.shine, this.rim, {this.metal = false});
  final double spec, shine, rim;

  /// Tints the highlight with the surface colour (gold).
  final bool metal;

  static const feather = _Mat(0.10, 14, 0.38);
  static const head = _Mat(0.28, 26, 0.32);
  static const bill = _Mat(0.32, 30, 0.22);
  static const eye = _Mat(0.55, 70, 0.08);
  static const iris = _Mat(0.9, 110, 0.05);
  static const fabric = _Mat(0.05, 8, 0.28);
  static const plastic = _Mat(0.45, 48, 0.2);
  static const glass = _Mat(1.1, 140, 0.45);
  static const gold = _Mat(0.95, 36, 0.3, metal: true);
}

typedef _Surf = P3 Function(double u, double v);
typedef _Paint = Color Function(double u, double v, P3 p);

class _Mesh {
  _Mesh._(this.pos, this.nrm, this.col, this.tri, this.mat);
  final Float32List pos, nrm, col;
  final Uint16List tri;
  final _Mat mat;

  int get count => pos.length ~/ 3;

  /// A closed (or tube-like) surface sampled on an [nu] × [nv] grid;
  /// [paint] colours it in its own coordinates, [place] then moves it.
  factory _Mesh.grid(int nu, int nv, _Surf f, _Mat mat, Color color,
      {_Paint? paint, _Xf? place}) {
    final n = (nu + 1) * (nv + 1);
    final pos = Float32List(n * 3), nrm = Float32List(n * 3);
    final col = Float32List(n * 3);
    var k = 0;
    double cx = 0, cy = 0, cz = 0;
    for (var j = 0; j <= nv; j++) {
      final v = j / nv;
      final vv = v.clamp(0.015, 0.985);
      for (var i = 0; i <= nu; i++) {
        final u = i / nu;
        final p = f(u, v);
        const e = 1e-3;
        final a = f(u + e, vv), b = f(u - e, vv);
        final c = f(u, vv + e), d = f(u, vv - e);
        final ux = a.$1 - b.$1, uy = a.$2 - b.$2, uz = a.$3 - b.$3;
        final wx = c.$1 - d.$1, wy = c.$2 - d.$2, wz = c.$3 - d.$3;
        var nx = uy * wz - uz * wy, ny = uz * wx - ux * wz;
        var nz = ux * wy - uy * wx;
        final l = math.sqrt(nx * nx + ny * ny + nz * nz);
        if (l > 1e-12) {
          nx /= l;
          ny /= l;
          nz /= l;
        } else {
          (nx, ny, nz) = (0, 1, 0);
        }
        final cc = paint?.call(u, v, p) ?? color;
        pos
          ..[k * 3] = p.$1
          ..[k * 3 + 1] = p.$2
          ..[k * 3 + 2] = p.$3;
        nrm
          ..[k * 3] = nx
          ..[k * 3 + 1] = ny
          ..[k * 3 + 2] = nz;
        col
          ..[k * 3] = cc.r
          ..[k * 3 + 1] = cc.g
          ..[k * 3 + 2] = cc.b;
        cx += p.$1;
        cy += p.$2;
        cz += p.$3;
        k++;
      }
    }
    // Normals point outward whichever way the surface was parametrised.
    cx /= n;
    cy /= n;
    cz /= n;
    var out = 0.0;
    for (var i = 0; i < n; i++) {
      out += nrm[i * 3] * (pos[i * 3] - cx) +
          nrm[i * 3 + 1] * (pos[i * 3 + 1] - cy) +
          nrm[i * 3 + 2] * (pos[i * 3 + 2] - cz);
    }
    if (out < 0) {
      for (var i = 0; i < nrm.length; i++) {
        nrm[i] = -nrm[i];
      }
    }
    final tri = Uint16List(nu * nv * 6);
    var t = 0;
    for (var j = 0; j < nv; j++) {
      for (var i = 0; i < nu; i++) {
        final a = j * (nu + 1) + i, b = a + 1, c = a + nu + 1, d = c + 1;
        tri
          ..[t++] = a
          ..[t++] = c
          ..[t++] = b
          ..[t++] = b
          ..[t++] = c
          ..[t++] = d;
      }
    }
    final mesh = _Mesh._(pos, nrm, col, tri, mat);
    if (place != null) mesh._transform(place);
    return mesh;
  }

  /// An ellipsoid, optionally reshaped by [shape] (gets the unit direction).
  factory _Mesh.blob(P3 c, P3 r, _Mat mat, Color color,
      {int nu = 28,
      int nv = 18,
      P3 Function(P3 s)? shape,
      _Paint? paint,
      _Xf? place}) {
    return _Mesh.grid(nu, nv, (u, v) {
      final s = _dir(u, v);
      final q = shape?.call(s) ?? (s.$1 * r.$1, s.$2 * r.$2, s.$3 * r.$3);
      return (c.$1 + q.$1, c.$2 + q.$2, c.$3 + q.$3);
    }, mat, color, paint: paint, place: place);
  }

  /// A rounded box (superellipsoid); [e1] squares it along y, [e2] around y.
  factory _Mesh.box(P3 c, P3 r, double e1, double e2, _Mat mat, Color color,
      {int nu = 28, int nv = 18, _Paint? paint, _Xf? place}) {
    return _Mesh.grid(nu, nv, (u, v) {
      final t = 2 * math.pi * u, p = math.pi * v;
      final sp = _sp(math.sin(p), e1);
      return (
        c.$1 + r.$1 * sp * _sp(math.cos(t), e2),
        c.$2 + r.$2 * _sp(math.cos(p), e1),
        c.$3 + r.$3 * sp * _sp(math.sin(t), e2),
      );
    }, mat, color, paint: paint, place: place);
  }

  /// A tube along the curve [c] (v 0–1) with radius [r]; [flat] squashes
  /// its cross-section (a ribbon).
  factory _Mesh.tube(P3 Function(double v) c, double Function(double v) r,
      _Mat mat, Color color,
      {int nu = 12, int nv = 16, double flat = 1, _Paint? paint}) {
    return _Mesh.grid(nu, nv, (u, v) {
      final p = c(v);
      final a = c((v + 0.01).clamp(0, 1)), b = c((v - 0.01).clamp(0, 1));
      var tx = a.$1 - b.$1, ty = a.$2 - b.$2, tz = a.$3 - b.$3;
      final tl = math.sqrt(tx * tx + ty * ty + tz * tz);
      tx /= tl;
      ty /= tl;
      tz /= tl;
      // Frame: side vector from the tangent and z (or y for curves along z).
      var (ux, uy, uz) = tz.abs() > 0.9 ? (0.0, 1.0, 0.0) : (0.0, 0.0, 1.0);
      var nx = ty * uz - tz * uy,
          ny = tz * ux - tx * uz,
          nz = tx * uy - ty * ux;
      final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
      nx /= nl;
      ny /= nl;
      nz /= nl;
      final bx = ty * nz - tz * ny,
          by = tz * nx - tx * nz,
          bz = tx * ny - ty * nx;
      // Round caps: the radius closes at both ends.
      final rr = r(v) * math.pow(math.sin(math.pi * v), 0.35);
      final ct = math.cos(2 * math.pi * u) * rr;
      final st = math.sin(2 * math.pi * u) * rr * flat;
      return (
        p.$1 + nx * ct + bx * st,
        p.$2 + ny * ct + by * st,
        p.$3 + nz * ct + bz * st,
      );
    }, mat, color, paint: paint);
  }

  /// A ring of radius [big] round the y axis, tube radius [small].
  factory _Mesh.torus(double big, double small, _Mat mat, Color color,
      {int nu = 36, int nv = 10, _Paint? paint, _Xf? place}) {
    return _Mesh.grid(nu, nv, (u, v) {
      final t = 2 * math.pi * u, p = 2 * math.pi * v;
      final rr = big + small * math.cos(p);
      return (rr * math.cos(t), small * math.sin(p), rr * math.sin(t));
    }, mat, color, paint: paint, place: place);
  }

  void _transform(_Xf x) {
    final n = x.normals(), m = x.m;
    for (var i = 0; i < pos.length; i += 3) {
      final px = pos[i], py = pos[i + 1], pz = pos[i + 2];
      pos[i] = m[0] * px + m[1] * py + m[2] * pz + m[3];
      pos[i + 1] = m[4] * px + m[5] * py + m[6] * pz + m[7];
      pos[i + 2] = m[8] * px + m[9] * py + m[10] * pz + m[11];
      final qx = nrm[i], qy = nrm[i + 1], qz = nrm[i + 2];
      var ax = n[0] * qx + n[1] * qy + n[2] * qz;
      var ay = n[3] * qx + n[4] * qy + n[5] * qz;
      var az = n[6] * qx + n[7] * qy + n[8] * qz;
      final l = math.sqrt(ax * ax + ay * ay + az * az);
      if (l > 0) {
        ax /= l;
        ay /= l;
        az /= l;
      }
      nrm[i] = ax;
      nrm[i + 1] = ay;
      nrm[i + 2] = az;
    }
  }

  /// Darkens creases and the parts near the ground (ambient occlusion,
  /// baked once).
  void occlude(double Function(double x, double y, double z) ao) {
    for (var i = 0; i < pos.length; i += 3) {
      final k = ao(pos[i], pos[i + 1], pos[i + 2]);
      col[i] *= k;
      col[i + 1] *= k;
      col[i + 2] *= k;
    }
  }
}

/// The joints the animation moves.
enum _Bone {
  root,
  body,
  head,
  billLow,
  eyeL,
  eyeR,
  pupilL,
  pupilR,
  lidL,
  lidR,
  browL,
  browR,
  wingL,
  wingR,
  footL,
  footR,
  tail,
  tuft,
  scarf,
  tag,
  shades,
  pack,
}

class _Part {
  const _Part(this.mesh, this.bone, [this.bias = 0, this.face]);
  final _Mesh mesh;
  final _Bone bone;

  /// Nudges the draw order of surfaces lying on others (eyes, stickers).
  final double bias;

  /// The bias only counts while this direction (in bone space) faces the
  /// viewer, so a far eye or wing never jumps in front of the head or body.
  final P3? face;
}

/// Everything the animation sets for one frame.
class DuckPose {
  /// Turn of the whole duck; −π/2 faces the viewer, 0 looks right.
  double yaw = 0;

  /// Where the duck stands along the ground (model units, + is right).
  double x = 0;
  double hop = 0;

  /// Squash (< 1) and stretch (> 1), volume kept.
  double squash = 1;
  double lean = 0, roll = 0;

  /// −1 to 1, the breath cycle.
  double breathe = 0;
  double headYaw = 0, headPitch = 0, headRoll = 0;

  /// Where the pupils look, −1 to 1.
  double eyeX = 0, eyeY = 0;

  /// How far the lids are closed, 0 to 1.
  double lid = 0.12;

  /// Brows raised (0 to 1) and tilted (worried < 0 < cross).
  double brow = 0, browTilt = 0;

  /// Bill opened, 0 to 1.
  double bill = 0;
  double wingL = 0, wingR = 0;

  /// The right wing raised to wave, 0 to about 2.
  double wave = 0;

  /// Sun lenses flipped up, 0 (down) to 1 (up).
  double shades = 0;

  /// Feet lifted (up) and stepped forward (stride, along the bill).
  double footL = 0, footR = 0;
  double strideL = 0, strideR = 0;

  /// The backpack on the back (1), or carried in the right wing (0).
  double pack = 1;

  /// The backpack lying on the ground (1) at [dropX], or lifted into the
  /// right wing (0). While above 0 the pack ignores the duck's own moves.
  double drop = 0, dropX = 0;
  double tail = 0;

  /// Secondary motion of loose parts (tuft, scarf end, tag).
  double swing = 0;
}

// Head and eye placement shared by the model and the rig.
const _headC = (18.0, 112.0, 0.0);
const _headR = 34.0;
const _eyeAz = 0.5, _eyeEl = 0.2;

/// Eyeball radii: depth, height, width.
const _eyeR = (5.0, 14.5, 12.0);
const _neck = (12.0, 84.0, 0.0);
const _billHinge = (47.0, 102.0, 0.0);

_Xf _eyeFrame(double side) {
  final d = (
    math.cos(_eyeEl) * math.cos(_eyeAz),
    math.sin(_eyeEl),
    side * math.cos(_eyeEl) * math.sin(_eyeAz),
  );
  const k = _headR * 0.93;
  return _Xf.t(
          _headC.$1 + d.$1 * k, _headC.$2 + d.$2 * k, _headC.$3 + d.$3 * k) *
      _Xf.ry(-side * _eyeAz) *
      _Xf.rz(_eyeEl);
}

_Xf _eyeFrameInv(double side) {
  final f = _eyeFrame(side).m;
  return _Xf.rz(-_eyeEl) * _Xf.ry(side * _eyeAz) * _Xf.t(-f[3], -f[7], -f[11]);
}

/// Where the sun lenses hinge: across the top of the glasses.
final P3 _shadesHinge = (() {
  final a = _eyeFrame(-1).apply((10.5, 14.5, 0));
  return (a.$1, a.$2, 0.0);
})();

P3 _shoulder(double side) => (8.0, 68.0, side * 36);
const _tailBase = (-40.0, 70.0, 0.0);
const _tuftBase = (16.0, 144.0, 0.0);

class _Look {
  const _Look(this.level, this.extras, this.stickers, this.mattress);
  final int level;
  final Color mattress;
  final Set<SuitcaseExtra> extras;
  final List<SuitcaseSticker> stickers;

  @override
  bool operator ==(Object o) =>
      o is _Look &&
      o.level == level &&
      o.mattress == mattress &&
      o.extras.length == extras.length &&
      o.extras.containsAll(extras) &&
      o.stickers.length == stickers.length &&
      [
        for (var i = 0; i < stickers.length; i++)
          o.stickers[i].seed == stickers[i].seed &&
              o.stickers[i].faded == stickers[i].faded
      ].every((e) => e);

  @override
  int get hashCode =>
      Object.hash(level, mattress, extras.length, stickers.length);
}

const _ink = Color(0xFF141414);
const _cream = Color(0xFFFBF4E6);
const _creamShade = Color(0xFFEADFC9);
const _wingCol = Color(0xFFEDE3D0);
const _wingTip = Color(0xFFCDBB9C);
const _goldCol = Color(0xFFF2B705);

const _stickerColors = [
  BrandColors.orange,
  BrandColors.amber,
  BrandColors.lime,
  Color(0xFF8FE3BF),
  Color(0xFFC9B6FF),
  Color(0xFFFFFFFF),
];

/// The duck's meshes for one level, its extras and stickers.
List<_Part> _buildDuck(_Look look) {
  final level = look.level, extras = look.extras;
  final parts = <_Part>[];
  final orange = BrandColors.orange;
  final feet = extras.contains(SuitcaseExtra.goldWheels) ? _goldCol : orange;
  final feetMat =
      extras.contains(SuitcaseExtra.goldWheels) ? _Mat.gold : _Mat.bill;

  double groundAo(double x, double y, double z) => 0.62 + 0.38 * _ss(2, 32, y);

  // Body: a pear, wider below, with a tail swept up at the back.
  final body = _Mesh.blob((0, 50, 0), (46, 42, 40), _Mat.feather, _cream,
      nu: 40,
      nv: 28,
      shape: (s) {
        final w = 1 + 0.1 * -s.$2;
        var x = s.$1 * 46 * w, y = s.$2 * 42, z = s.$3 * 40 * w;
        if (s.$2 < 0) y *= 0.86;
        x += 5 * math.max(0, s.$1) * (1 - (s.$2 + 0.1).abs()).clamp(0, 1);
        final t = math.pow(math.max(0, -s.$1), 3) * _ss(-0.3, 0.7, s.$2);
        x -= 10 * t;
        y += 12 * t;
        z *= 1 - 0.35 * t;
        return (x, y, z);
      },
      paint: (u, v, p) =>
          Color.lerp(_cream, _creamShade, _ss(10, -46, p.$1) * 0.7)!)
    ..occlude((x, y, z) {
      // Under the chin and near the ground.
      final dx = x - _headC.$1, dy = y - _headC.$2;
      final d = math.sqrt(dx * dx + dy * dy + z * z);
      return groundAo(x, y, z) * (0.72 + 0.28 * _ss(32, 50, d));
    });
  parts.add(_Part(body, _Bone.body));

  // Tail feathers.
  for (final (z, len, r) in [
    (-7.0, 11.0, 7.0),
    (0.0, 14.0, 8.5),
    (7.0, 11.0, 7.0)
  ]) {
    parts.add(_Part(
        _Mesh.tube(
            (v) => (
                  -36 - len * v,
                  70 + 10 * v + 8 * v * v,
                  z * (1 + 0.6 * v),
                ),
            (v) => r * (1 - 0.55 * v),
            _Mat.feather,
            _cream,
            paint: (u, v, p) => Color.lerp(_cream, _wingTip, v * 0.7)!),
        _Bone.tail));
  }

  // Head: forest green, lighter on top, a touch of cheek.
  parts.add(_Part(
      _Mesh.blob(_headC, (_headR, _headR * 0.96, _headR), _Mat.head,
          BrandColors.forest,
          nu: 36,
          nv: 26,
          shape: (s) => (
                s.$1 * _headR * (1 + 0.04 * math.max(0, s.$1)),
                s.$2 * _headR * 0.96,
                s.$3 * _headR * (1 + 0.06 * math.max(0, -s.$2)),
              ),
          paint: (u, v, p) => Color.lerp(BrandColors.forestLight,
              BrandColors.forestDeep, _ss(0.1, 1, v) * 0.85)!),
      _Bone.head));

  // Mouth inside, seen when the bill opens.
  parts.add(_Part(
      _Mesh.blob((50, 103, 0), (9, 4, 9), _Mat.fabric, const Color(0xFF5A1E14),
          nu: 14, nv: 8),
      _Bone.head));

  // Bill: wider toward the tip, a smile at the corners, two nostrils.
  P3 billShape(P3 s, double len, double h, double hLow, double w) {
    final wide = w * (0.74 + 0.34 * (s.$1 + 1) / 2);
    final y = s.$2 >= 0 ? h * s.$2 : hLow * s.$2;
    final smile = 2.4 * s.$3 * s.$3 * (1 - s.$1) / 2 +
        2.2 * math.pow(math.max(0, s.$1), 3);
    return (s.$1 * len, y + smile, s.$3 * wide);
  }

  parts.add(_Part(
      _Mesh.blob((64, 106, 0), (18, 6.5, 13), _Mat.bill, orange,
          nu: 30,
          nv: 18,
          shape: (s) => billShape(s, 18, 6.5, 2.6, 13),
          paint: (u, v, p) {
            final nose = math.min(
              (p.$1 - 58).abs() + ((p.$3).abs() - 4.2).abs() * 1.2,
              99.0,
            );
            if (p.$2 > 110.5 && nose < 2.4) return const Color(0xFFB8400F);
            return Color.lerp(
                const Color(0xFFFF7A3D), orange, _ss(112, 104, p.$2))!;
          }),
      _Bone.head));
  parts.add(_Part(
      _Mesh.blob((61, 100.5, 0), (15, 3.6, 11), _Mat.bill,
          Color.lerp(orange, _ink, 0.14)!,
          nu: 24, nv: 12, shape: (s) => billShape(s, 15, 3.6, 3.6, 11)),
      _Bone.billLow));

  // Eyes: white, a warm dark iris with a pupil, lids and brows.
  final shades = extras.contains(SuitcaseExtra.goldHandle);
  for (final side in [-1.0, 1.0]) {
    final frame = _eyeFrame(side);
    final left = side < 0;
    // Built on a unit sphere; the eye bones scale it to the eye's shape,
    // so iris and lids slide along the eyeball when they move.
    parts.add(_Part(
        _Mesh.blob((0, 0, 0), (1, 1, 1), _Mat.eye, const Color(0xFFFFFFFF),
            nu: 24, nv: 18),
        left ? _Bone.eyeL : _Bone.eyeR,
        3,
        (1, 0, 0)));
    parts.add(_Part(
        _Mesh.blob((0.6, 0, 0), (0.44, 0.64, 0.64), _Mat.iris, _ink,
            nu: 22, nv: 16, paint: (u, v, p) {
          final r = math.sqrt(p.$2 * p.$2 + p.$3 * p.$3) / 0.64;
          if (r < 0.5) return const Color(0xFF0B0908);
          return Color.lerp(const Color(0xFF2A1D14), const Color(0xFF8A5E36),
              _ss(0.3, -0.6, p.$2))!;
        }),
        left ? _Bone.pupilL : _Bone.pupilR,
        4,
        (1, 0, 0)));
    parts.add(_Part(
        _Mesh.grid(26, 10, (u, v) {
          final t = 2 * math.pi * u, p = math.pi / 2 * v;
          return (
            1.1 * math.sin(p) * math.cos(t),
            1.08 * math.cos(p),
            1.08 * math.sin(p) * math.sin(t),
          );
        }, _Mat.head,
            Color.lerp(BrandColors.forestLight, BrandColors.forest, 0.45)!,
            paint: (u, v, p) => v > 0.9
                ? Color.lerp(BrandColors.forest, _ink, 0.45)!
                : Color.lerp(
                    BrandColors.forestLight, BrandColors.forest, 0.45)!),
        left ? _Bone.lidL : _Bone.lidR,
        5,
        (1, 0, 0)));
    parts.add(_Part(
        _Mesh.tube(
            (v) => (
                  1.5 + 2 * math.sin(math.pi * v),
                  19 + 2.6 * math.sin(math.pi * v) - 1.5 * v,
                  side * (-9 + 18 * v),
                ),
            (v) => 1.9 * (0.5 + 0.5 * math.sin(math.pi * v)),
            _Mat.fabric,
            const Color(0xFF0A2A20),
            nu: 8,
            nv: 10)
          .._transform(frame),
        left ? _Bone.browL : _Bone.browR,
        4,
        frame.apply((1, 0, 0)).sub(frame.apply((0, 0, 0)))));
  }

  // Wings: flattened teardrops with three feather tips.
  for (final side in [-1.0, 1.0]) {
    parts.add(_Part(
        _Mesh.blob((0, 0, 0), (27, 14, 6), _Mat.feather, _wingCol,
            nu: 30,
            nv: 14,
            shape: (s) {
              final a = math.atan2(s.$2, s.$1);
              final tips = 1 +
                  0.2 *
                      math.pow(math.max(0, -s.$1), 2) *
                      (0.5 + 0.5 * math.cos(6 * a));
              return (s.$1 * 27 * tips, s.$2 * 14 * tips, s.$3 * 6);
            },
            paint: (u, v, p) =>
                Color.lerp(_wingCol, _wingTip, _ss(0, -32, p.$1))!,
            place:
                _Xf.t(-8, 58, side * 38.5) * _Xf.ry(side * 0.12) * _Xf.rz(-0.3))
          ..occlude(groundAo),
        side < 0 ? _Bone.wingL : _Bone.wingR,
        2,
        (0, 0, side)));
  }

  // Legs and webbed feet with three toes.
  for (final side in [-1.0, 1.0]) {
    final bone = side < 0 ? _Bone.footL : _Bone.footR;
    parts.add(_Part(
        _Mesh.tube((v) => (8 - 3 * v, 3 + 17 * v, side * 15), (v) => 3.6,
            _Mat.bill, Color.lerp(feet, _ink, 0.1)!,
            nu: 10, nv: 6),
        bone));
    parts.add(_Part(
        _Mesh.blob((0, 0, 0), (13, 2.8, 9.5), feetMat, feet, nu: 28, nv: 10,
            shape: (s) {
          final b = math.atan2(s.$3, s.$1);
          final toes = s.$1 > 0
              ? 0.24 *
                  math.pow(math.max(0, math.cos(b)), 1.5) *
                  (0.5 + 0.5 * math.cos(6 * b))
              : 0.0;
          return (
            s.$1 * 13 * (1 + toes),
            s.$2 * 2.8 + (s.$2 > 0 ? 1.2 * (1 - s.$1.abs()) : 0),
            s.$3 * 9.5 * (1 + toes * 0.6),
          );
        }, place: _Xf.t(13, 2.8, side * 15) * _Xf.ry(-side * 0.28)),
        bone));
  }

  if (level == 0) {
    // Duckling: a tuft of three curls on the head.
    for (final (z, h, lean) in [
      (-5.0, 12.0, -0.3),
      (0.0, 16.0, 0.0),
      (5.0, 11.0, 0.3)
    ]) {
      parts.add(_Part(
          _Mesh.tube(
              (v) => (
                    _tuftBase.$1 + 6 * v - 8 * v * v,
                    _tuftBase.$2 - 2 + h * v,
                    z + lean * 8 * v,
                  ),
              (v) => 3.4 * (1 - 0.8 * v),
              _Mat.head,
              BrandColors.forestLight,
              nu: 8,
              nv: 10),
          _Bone.tuft));
    }
  }

  if (level >= 1) {
    // Backpack with flap and pocket.
    const pack = BrandColors.forest;
    final packAt = _Xf.t(-50, 66, 0) * _Xf.rz(0.1);
    parts.add(_Part(
        _Mesh.box((0, 0, 0), (13, 30, 27), 0.35, 0.35, _Mat.fabric, pack,
            place: packAt),
        _Bone.pack));
    parts.add(_Part(
        _Mesh.box((
          -1,
          22,
          0
        ), (
          15.5,
          9,
          29.5
        ), 0.3, 0.35, _Mat.fabric, BrandColors.forestDeep, place: packAt),
        _Bone.pack,
        3));
    parts.add(_Part(
        _Mesh.box((
          -13,
          -8,
          0
        ), (
          5.5,
          13,
          19
        ), 0.35, 0.4, _Mat.fabric, BrandColors.forestLight, place: packAt),
        _Bone.pack,
        3));
    // City stickers: two on each side of the backpack, two on the pocket;
    // the side the viewer sees first.
    final spots = <_Xf>[
      for (final side in [1.0, -1.0])
        for (final dy in [8.0, -8.0])
          packAt * _Xf.t(1, dy, side * 27.4) * _Xf.rx(math.pi / 2),
      for (final dz in [-8.0, 8.0])
        packAt * _Xf.t(-18.9, -6, dz) * _Xf.rz(math.pi / 2),
    ];
    final facing = <P3>[
      (0, 0, 1),
      (0, 0, 1),
      (0, 0, -1),
      (0, 0, -1),
      (-1, 0, 0),
      (-1, 0, 0),
    ];
    for (final (i, st) in look.stickers.take(spots.length).indexed) {
      final c = _stickerColors[st.seed % _stickerColors.length];
      final color = st.faded ? Color.lerp(c, pack, 0.55)! : c;
      parts.add(_Part(
          _Mesh.box((0, 0, 0), (6, 0.9, 6), 0.6, 0.55, _Mat.plastic, color,
              nu: 16, nv: 8, place: spots[i]),
          _Bone.pack,
          5,
          facing[i]));
    }
    if (extras.contains(SuitcaseExtra.tag)) {
      parts.add(_Part(
          _Mesh.tube(
              (v) => (-58.0, 46 - 6 * v, 24.0), (v) => 0.8, _Mat.fabric, _ink,
              nu: 6, nv: 4),
          _Bone.tag,
          1));
      parts.add(_Part(
          _Mesh.box((
            -58,
            34,
            24
          ), (
            2,
            7,
            5
          ), 0.4, 0.4, _Mat.plastic, BrandColors.amber, nu: 14, nv: 10),
          _Bone.tag,
          1));
    }
  }

  if (level >= 2) {
    // Rolled-up mattress on top of the backpack, two straps round it.
    parts.add(_Part(
        _Mesh.box((0, 0, 0), (12, 34, 12), 0.22, 1, _Mat.fabric, look.mattress,
            nu: 24, nv: 30, paint: (u, v, p) {
          // The roll's ends a shade darker.
          if (p.$2.abs() > 33) return Color.lerp(look.mattress, _ink, 0.18)!;
          return look.mattress;
        }, place: _Xf.t(-50, 103, 0) * _Xf.rx(math.pi / 2)),
        _Bone.pack,
        0.6));
    for (final z in [-21.0, 21.0]) {
      parts.add(_Part(
          _Mesh.torus(12.3, 1.7, _Mat.fabric, BrandColors.forestDeep,
              nu: 28, nv: 6, place: _Xf.t(-50, 103, z) * _Xf.rx(math.pi / 2)),
          _Bone.pack,
          3));
    }
  }

  if (extras.contains(SuitcaseExtra.strap)) {
    // A knitted scarf round the neck, its end hanging over the chest.
    parts.add(_Part(
        _Mesh.torus(25, 6.5, _Mat.fabric, BrandColors.lime,
            paint: (u, v, p) => (u * 14).floor().isEven
                ? BrandColors.lime
                : Color.lerp(BrandColors.lime, BrandColors.forest, 0.18)!,
            place: _Xf.p(_neck) * _Xf.rz(-0.28)),
        _Bone.body,
        0.8));
    parts.add(_Part(
        _Mesh.tube((v) => (30 + 6 * v, 80 - 26 * v, -16 - 4 * v), (v) => 6,
            _Mat.fabric, BrandColors.lime,
            flat: 0.35,
            nu: 12,
            nv: 10,
            paint: (u, v, p) => v > 0.82
                ? Color.lerp(BrandColors.lime, BrandColors.forest, 0.25)!
                : BrandColors.lime),
        _Bone.scarf,
        1.2));
  }

  if (level >= 3) {
    // Bucket hat with a band.
    final hatAt = _Xf.t(16, 142, 0) * _Xf.rz(0.12);
    parts.add(_Part(
        _Mesh.box(
            (0, 0, 0), (42, 3.4, 42), 0.6, 1, _Mat.fabric, BrandColors.lime,
            nu: 36, nv: 10, place: hatAt),
        _Bone.head,
        0.6));
    parts.add(_Part(
        _Mesh.box(
            (-1, 12, 0), (24, 13, 24), 0.55, 1, _Mat.fabric, BrandColors.lime,
            nu: 32,
            nv: 16,
            paint: (u, v, p) =>
                p.$2 < 4.5 && p.$2 > 0 ? BrandColors.forest : BrandColors.lime,
            place: hatAt),
        _Bone.head,
        0.8));
  }

  if (level >= 4) {
    // Camera on a strap round the neck.
    parts.add(_Part(
        _Mesh.torus(26, 1.4, _Mat.fabric, _ink,
            nu: 32, nv: 6, place: _Xf.p(_neck) * _Xf.rz(-0.75)),
        _Bone.body,
        0.4));
    final camAt = _Xf.t(48, 50, 0) * _Xf.rz(-0.15);
    parts.add(_Part(
        _Mesh.box((0, 0, 0), (7, 10, 15), 0.3, 0.3, _Mat.plastic,
            const Color(0xFF2B2E33),
            nu: 20, nv: 12, place: camAt),
        _Bone.body,
        1.5));
    parts.add(_Part(
        _Mesh.box(
            (0, 0, 0), (7, 6, 7), 0.25, 1, _Mat.glass, const Color(0xFF5E636B),
            nu: 20,
            nv: 10,
            paint: (u, v, p) =>
                p.$2 > 5 ? const Color(0xFF121A2A) : const Color(0xFF8A8F99),
            place: camAt * _Xf.t(10, 0, 0) * _Xf.rz(-math.pi / 2)),
        _Bone.body,
        2));
    parts.add(_Part(
        _Mesh.blob((0, 11, 8), (2.6, 2, 2.6), _Mat.plastic, orange,
            nu: 10, nv: 6, place: camAt),
        _Bone.body,
        2));
  }

  if (shades) {
    // Gold-rimmed glasses with clip-on sun lenses that flip up (tap), so
    // the eyes can still be seen.
    const rim = Color(0xFFE2A400);
    for (final side in [-1.0, 1.0]) {
      final f = _eyeFrame(side);
      final out = f.apply((1, 0, 0)).sub(f.apply((0, 0, 0)));
      parts.add(_Part(
          _Mesh.torus(13, 1.25, _Mat.gold, rim,
              nu: 32,
              nv: 8,
              place: f *
                  _Xf.t(7.2, 0.5, 0) *
                  _Xf.rz(math.pi / 2) *
                  _Xf.s(1.04, 1, 1.08)),
          _Bone.head,
          6,
          out));
      parts.add(_Part(
          _Mesh.box((9.4, 0.5, 0), (1.1, 14.2, 14.8), 1, 0.5, _Mat.glass,
              const Color(0xFF15161A),
              nu: 22,
              nv: 14,
              paint: (u, v, p) => Color.lerp(const Color(0xFF0E0F14),
                  const Color(0xFF34406A), _ss(4, -12, p.$2))!,
              place: f),
          _Bone.shades,
          7,
          out));
    }
    final a = _eyeFrame(-1).apply((8, 3, 13.5)),
        b = _eyeFrame(1).apply((8, 3, -13.5));
    parts.add(_Part(
        _Mesh.tube(
            (v) => (
                  a.$1 + (b.$1 - a.$1) * v + 2.5 * math.sin(math.pi * v),
                  a.$2 + (b.$2 - a.$2) * v + 1.5 * math.sin(math.pi * v),
                  a.$3 + (b.$3 - a.$3) * v,
                ),
            (v) => 1.2,
            _Mat.gold,
            rim,
            nu: 6,
            nv: 10),
        _Bone.head,
        6,
        (1, 0, 0)));
  }
  return parts;
}

/// The backpack swung from the right wing (k 0, hanging at the side) over
/// the shoulder onto the back (k 1).
_Xf _packXf(double k) {
  if (k >= 1) return _Xf.identity;
  final e = 1 - k;
  // Back first, then down: the pack clears the head on its way over.
  return _Xf.t(64 * e * e, -26 * e + 90 * math.sin(math.pi * k), 50 * e) *
      _Xf.about((-50, 66, 0), _Xf.rz(-0.5 * e));
}

/// The backpack lifted off the ground (d 1, lying on its side in front of
/// the duck) into the right wing (d 0, same as [_packXf] at 0).
_Xf _dropXf(double d) =>
    _Xf.t(64, -26 - 24 * d + 16 * math.sin(math.pi * d), 50 + 10 * d) *
    _Xf.about((-50, 66, 0), _Xf.rz(-0.5 - 1.07 * d));

/// The pose → bone transforms.
List<_Xf> _rig(DuckPose p) {
  final b = List<_Xf>.filled(_Bone.values.length, _Xf.identity);
  final w = 1 / math.sqrt(p.squash);
  final root = _Xf.t(p.x, 0, 0) *
      _Xf.ry(p.yaw) *
      _Xf.t(0, p.hop, 0) *
      _Xf.rx(p.roll) *
      _Xf.rz(p.lean) *
      _Xf.s(w, p.squash, w);
  final body = root *
      _Xf.about(
          (0, 30, 0),
          _Xf.s(1 + p.breathe * 0.012, 1 + p.breathe * 0.022,
              1 + p.breathe * 0.012));
  final head = root *
      _Xf.t(0, p.breathe * 0.9, 0) *
      _Xf.about(
          _neck, _Xf.ry(p.headYaw) * _Xf.rz(p.headPitch) * _Xf.rx(p.headRoll));
  b[_Bone.root.index] = root;
  b[_Bone.body.index] = body;
  b[_Bone.head.index] = head;
  b[_Bone.billLow.index] = head * _Xf.about(_billHinge, _Xf.rz(-p.bill * 0.55));
  for (final side in [-1.0, 1.0]) {
    final left = side < 0;
    final f = _eyeFrame(side), fi = _eyeFrameInv(side);
    final ball = head * f * _Xf.s(_eyeR.$1, _eyeR.$2, _eyeR.$3);
    b[(left ? _Bone.eyeL : _Bone.eyeR).index] = ball;
    b[(left ? _Bone.pupilL : _Bone.pupilR).index] =
        ball * _Xf.ry(-p.eyeX * 0.5) * _Xf.rz(p.eyeY * 0.4);
    b[(left ? _Bone.lidL : _Bone.lidR).index] =
        ball * _Xf.rz((0.5 - p.lid) * math.pi);
    b[(left ? _Bone.browL : _Bone.browR).index] = head *
        f *
        _Xf.t(0, p.brow * 3.5, 0) *
        _Xf.rx(side * p.browTilt * 0.35) *
        fi;
    final flap = left ? p.wingL : p.wingR;
    b[(left ? _Bone.wingL : _Bone.wingR).index] = body *
        _Xf.about(_shoulder(side),
            _Xf.rx(-side * flap) * (left ? _Xf.identity : _Xf.rz(-p.wave)));
    b[(left ? _Bone.footL : _Bone.footR).index] =
        root * _Xf.t(left ? p.strideL : p.strideR, left ? p.footL : p.footR, 0);
  }
  b[_Bone.tail.index] = body * _Xf.about(_tailBase, _Xf.ry(p.tail));
  b[_Bone.tuft.index] = head * _Xf.about(_tuftBase, _Xf.rz(p.swing * 0.6));
  b[_Bone.scarf.index] = body *
      _Xf.about((30, 80, -16), _Xf.rz(p.swing * 0.5) * _Xf.rx(p.swing * 0.3));
  b[_Bone.pack.index] = p.drop > 0
      ? _Xf.t(p.dropX, 0, 0) * _dropXf(p.drop)
      : body * _packXf(p.pack);
  b[_Bone.tag.index] =
      b[_Bone.pack.index] * _Xf.about((-58, 46, 24), _Xf.rz(p.swing * 0.8));
  b[_Bone.shades.index] =
      head * _Xf.about(_shadesHinge, _Xf.rz(p.shades * 2.35));
  return b;
}

/// Builds the meshes once per look and draws poses of them.
class DuckRenderer {
  /// Where the head with the glasses was drawn last frame (for taps).
  Offset? glassesAt;
  double glassesRadius = 0;

  _Look? _look;
  List<_Part> _parts = const [];
  late Float64List _x, _y, _z, _nx, _ny, _nz;
  late Float32List _screen;
  late Int32List _colors;
  late Float64List _depth;
  late Uint16List _tri;

  void _prepare(_Look look) {
    if (look == _look) return;
    _look = look;
    _parts = _buildDuck(look);
    final n = _parts.fold(0, (a, p) => a + p.mesh.count);
    final t = _parts.fold(0, (a, p) => a + p.mesh.tri.length ~/ 3);
    _x = Float64List(n);
    _y = Float64List(n);
    _z = Float64List(n);
    _nx = Float64List(n);
    _ny = Float64List(n);
    _nz = Float64List(n);
    _screen = Float32List(n * 2);
    _colors = Int32List(n);
    _depth = Float64List(t);
    _tri = Uint16List(t * 3);
  }

  static const _pitch = 0.2;
  static const _focal = 900.0;

  void paint(Canvas canvas, Size size, DuckPose pose,
      {required int level,
      required Set<SuitcaseExtra> extras,
      required List<SuitcaseSticker> stickers,
      Color mattress = BrandColors.orange}) {
    _prepare(_Look(level, extras, stickers, mattress));
    final bones = _rig(pose);
    final cam = _Xf.rx(_pitch) * _Xf.t(0, -78, 0);
    final grow = 0.8 + 0.05 * level.clamp(0, 4);
    final scale = math.min(size.width, size.height) / 180 * grow;
    final cx = size.width / 2, cy = size.height / 2 + 6 * scale;

    Offset project(double x, double y, double z) {
      final k = _focal / (_focal - z) * scale;
      return Offset(cx + x * k, cy - y * k);
    }

    // Soft shadow on the ground, smaller while the duck is in the air.
    final g = cam.apply((pose.x, 0, 0));
    final gs = project(g.$1, g.$2, g.$3);
    final away = (1 - pose.hop / 70).clamp(0.4, 1.0);
    final sw = 118 * scale * away;
    canvas
      ..save()
      ..translate(gs.dx, gs.dy)
      ..scale(1, math.sin(_pitch) * 1.25)
      ..drawCircle(
        Offset.zero,
        sw / 2,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            sw / 2,
            [
              _ink.withValues(alpha: 0.24 * away),
              _ink.withValues(alpha: 0.10 * away),
              _ink.withValues(alpha: 0),
            ],
            [0, 0.55, 1],
          ),
      )
      ..restore();

    // Lights, fixed in view space: warm key from the upper left, cool fill
    // from the right, sky above, ground bounce below.
    const k1x = -0.52, k1y = 0.7, k1z = 0.49;
    const f1x = 0.85, f1y = 0.05, f1z = 0.52;

    var base = 0, tc = 0;
    for (final part in _parts) {
      final m = (cam * bones[part.bone.index]);
      final mm = m.m, nm = m.normals();
      var bias = part.bias;
      final face = part.face;
      if (face != null) {
        final fx = nm[0] * face.$1 + nm[1] * face.$2 + nm[2] * face.$3;
        final fy = nm[3] * face.$1 + nm[4] * face.$2 + nm[5] * face.$3;
        final fz = nm[6] * face.$1 + nm[7] * face.$2 + nm[8] * face.$3;
        final l = math.sqrt(fx * fx + fy * fy + fz * fz);
        bias *= (fz / l * 3).clamp(0.0, 1.0);
      }
      final mesh = part.mesh, mat = part.mesh.mat;
      final pos = mesh.pos, nrm = mesh.nrm, col = mesh.col;
      for (var i = 0; i < mesh.count; i++) {
        final px = pos[i * 3], py = pos[i * 3 + 1], pz = pos[i * 3 + 2];
        final x = mm[0] * px + mm[1] * py + mm[2] * pz + mm[3];
        final y = mm[4] * px + mm[5] * py + mm[6] * pz + mm[7];
        final z = mm[8] * px + mm[9] * py + mm[10] * pz + mm[11];
        final qx = nrm[i * 3], qy = nrm[i * 3 + 1], qz = nrm[i * 3 + 2];
        var nx = nm[0] * qx + nm[1] * qy + nm[2] * qz;
        var ny = nm[3] * qx + nm[4] * qy + nm[5] * qz;
        var nz = nm[6] * qx + nm[7] * qy + nm[8] * qz;
        final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        nx /= nl;
        ny /= nl;
        nz /= nl;
        final j = base + i;
        _x[j] = x;
        _y[j] = y;
        _z[j] = z;
        _nx[j] = nx;
        _ny[j] = ny;
        _nz[j] = nz;
        final k = _focal / (_focal - z) * scale;
        _screen[j * 2] = cx + x * k;
        _screen[j * 2 + 1] = cy - y * k;

        // View direction.
        var vx = -x, vy = -y, vz = _focal - z;
        final vl = math.sqrt(vx * vx + vy * vy + vz * vz);
        vx /= vl;
        vy /= vl;
        vz /= vl;
        final ndv = (nx * vx + ny * vy + nz * vz).clamp(0.0, 1.0);
        final d1 =
            math.max(0.0, (nx * k1x + ny * k1y + nz * k1z + 0.25) / 1.25);
        final d2 = math.max(0.0, nx * f1x + ny * f1y + nz * f1z);
        final hemi = 0.5 + 0.5 * ny;
        // Blinn highlight from the key light.
        var hx = k1x + vx, hy = k1y + vy, hz = k1z + vz;
        final hl = math.sqrt(hx * hx + hy * hy + hz * hz);
        hx /= hl;
        hy /= hl;
        hz /= hl;
        final spec = mat.spec *
            math.pow(math.max(0.0, nx * hx + ny * hy + nz * hz), mat.shine) *
            (d1 > 0 ? 1 : 0);
        final rim = mat.rim * math.pow(1 - ndv, 3) * (0.55 + 0.45 * hemi);
        final cr = col[i * 3], cg = col[i * 3 + 1], cb = col[i * 3 + 2];
        double ch(double c, double sky, double gnd, double key, double fill) {
          final amb = gnd + (sky - gnd) * hemi;
          final lit = c * (amb + d1 * key + d2 * fill);
          final s = mat.metal ? spec * (0.4 + c) : spec;
          return lit + s + rim * (0.6 + 0.4 * c);
        }

        final r = ch(cr, 0.42, 0.26, 0.78, 0.16);
        final gg = ch(cg, 0.44, 0.22, 0.74, 0.19);
        final bb = ch(cb, 0.50, 0.18, 0.68, 0.24);
        int to8(double c) =>
            (255 * (c / (1 + 0.12 * c)) * 1.12).round().clamp(0, 255);
        _colors[j] = (0xFF << 24) | (to8(r) << 16) | (to8(gg) << 8) | to8(bb);
      }

      // Visible triangles: facing the camera, depth of their centre.
      final tri = mesh.tri;
      for (var t = 0; t < tri.length; t += 3) {
        final a = base + tri[t], b = base + tri[t + 1], c = base + tri[t + 2];
        final mx = (_x[a] + _x[b] + _x[c]) / 3;
        final my = (_y[a] + _y[b] + _y[c]) / 3;
        final mz = (_z[a] + _z[b] + _z[c]) / 3;
        final fx = _nx[a] + _nx[b] + _nx[c];
        final fy = _ny[a] + _ny[b] + _ny[c];
        final fz = _nz[a] + _nz[b] + _nz[c];
        if (fx * -mx + fy * -my + fz * (_focal - mz) <= 0) continue;
        _depth[tc] = mz + bias;
        _tri[tc * 3] = a;
        _tri[tc * 3 + 1] = b;
        _tri[tc * 3 + 2] = c;
        tc++;
      }
      base += mesh.count;
    }

    // Back to front.
    final order = List<int>.generate(tc, (i) => i)
      ..sort((a, b) => _depth[a].compareTo(_depth[b]));
    final idx = Uint16List(tc * 3);
    for (var i = 0; i < tc; i++) {
      final t = order[i] * 3;
      idx[i * 3] = _tri[t];
      idx[i * 3 + 1] = _tri[t + 1];
      idx[i * 3 + 2] = _tri[t + 2];
    }
    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, _screen,
        colors: _colors, indices: idx);
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();

    glassesAt = null;
    if (extras.contains(SuitcaseExtra.goldHandle)) {
      // The whole head counts: it keeps moving, the glasses are small.
      final q = (cam * bones[_Bone.head.index]).apply(_headC);
      glassesAt = project(q.$1, q.$2, q.$3);
      glassesRadius = (_headR + 8) * scale;
    }

    // Catch lights in the eyes (crisper than the mesh could draw them).
    if ((!extras.contains(SuitcaseExtra.goldHandle) || pose.shades > 0.6) &&
        pose.lid < 0.4) {
      for (final side in [-1.0, 1.0]) {
        final m = cam * bones[(side < 0 ? _Bone.eyeL : _Bone.eyeR).index];
        final o = m.apply((0, 0, 0)), f = m.apply((1, 0, 0));
        final len = math.sqrt(math.pow(f.$1 - o.$1, 2) +
            math.pow(f.$2 - o.$2, 2) +
            math.pow(f.$3 - o.$3, 2));
        if (f.$3 - o.$3 < 0.3 * len) continue;
        final paint = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95)
          ..isAntiAlias = true;
        for (final (p, r) in [
          ((1.03, 0.4, -0.2), 2.6),
          ((1.03, -0.3, 0.2), 1.1)
        ]) {
          final q = m.apply(p);
          final k = _focal / (_focal - q.$3) * scale;
          canvas.drawCircle(project(q.$1, q.$2, q.$3), r * k, paint);
        }
      }
    }
  }
}
