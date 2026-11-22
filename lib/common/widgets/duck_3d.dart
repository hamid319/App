import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../utils/suitcase_progress.dart';
import 'duck_3d_model.dart';
import 'suitcase_view.dart';

/// The Out We Go duck as a lit 3D character the user can spin and poke.
/// It grows with the traveller: a duckling with a tuft at level 1, then a
/// backpack, the rolled-up mattress, a bucket hat and a camera; the extras
/// add a luggage tag, a scarf, golden feet and sunglasses, and every city
/// stamp puts a sticker on the backpack.
///
/// Alive while idle: it breathes, blinks, looks around, now and then right
/// at you, and wags its tail. Its eyes follow your finger. A tap makes it
/// hop, wave, spin or quack (anticipation, squash and stretch, overlapping
/// head and loose parts); a fast spin leaves it dizzy. With reduced motion
/// it only turns when dragged.
class Duck3D extends StatefulWidget {
  const Duck3D({
    super.key,
    required this.level,
    required this.extras,
    this.stickers = const [],
    this.size = 180,
    this.semanticLabel,
  });

  /// 0 (duckling) to 4, as [SuitcaseProgress.level].
  final int level;
  final Set<SuitcaseExtra> extras;
  final List<SuitcaseSticker> stickers;
  final double size;
  final String? semanticLabel;

  @override
  State<Duck3D> createState() => _Duck3DState();
}

/// Resting view: three quarters, the bill to the right and toward you.
const _restYaw = -0.62;

/// Faces the viewer.
const _towardViewer = -math.pi / 2;

/// A damped spring for one value.
class _Spring {
  double x = 0, v = 0;

  void step(double target, double dt, {double k = 90, double c = 12}) {
    v += (-k * (x - target) - c * v) * dt;
    x += v * dt;
  }
}

enum _Act { hop, wave, spin, quack }

class _Duck3DState extends State<Duck3D> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _pose = DuckPose();
  final _frame = ValueNotifier(0);
  final _rng = math.Random();
  final _renderer = DuckRenderer();

  Duration? _last;
  double _t = 0;
  bool _still = false;

  // Turning: drag, fling, spring back to the resting view.
  double _yaw = 0, _yawVel = 0, _dragVel = 0, _peakVel = 0;
  double? _target;
  bool _dragging = false;
  static const _perPixel = 0.014;

  final _headYaw = _Spring(), _headPitch = _Spring(), _headRoll = _Spring();
  final _eyeX = _Spring(), _eyeY = _Spring(), _roll = _Spring();
  final _swing = _Spring(), _lid = _Spring(), _brow = _Spring();

  // Where it looks: a finger, or an idle target (direction, pitch).
  Offset? _finger;
  double _lookDir = _restYaw, _lookPitch = 0, _nextLook = 1.5;

  double _nextBlink = 1.2, _blinkAt = -9;
  bool _doubleBlink = false;
  double _nextWag = 3, _wagAt = -9;
  double _dizzyAt = -9;

  _Act? _act;
  double _actAt = 0;
  int _nextAct = 0;
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _pose.yaw = _restYaw;
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.of(context).disableAnimations;
  }

  @override
  void didUpdateWidget(Duck3D old) {
    super.didUpdateWidget(old);
    // A new level is worth a jump.
    if (widget.level > old.level && !_still) _play(_Act.hop);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _play(_Act act) {
    _act = act;
    _actAt = _t;
    _landed = false;
    HapticFeedback.lightImpact();
  }

  /// Sun lenses up (eyes visible) or down.
  bool _shadesUp = false;
  final _shades = _Spring();

  void _tap(Offset at) {
    final g = _renderer.glassesAt;
    if (g != null && (at - g).distance < _renderer.glassesRadius) {
      HapticFeedback.lightImpact();
      _shadesUp = !_shadesUp;
      // Peeking over the glasses: brows up for a moment.
      _peekAt = _t;
      return;
    }
    if (_still) {
      HapticFeedback.selectionClick();
      return;
    }
    final busy = _act != null && _t - _actAt < _duration(_act!) * 0.75;
    if (busy) return;
    _play(_Act.values[_nextAct++ % _Act.values.length]);
  }

  static double _duration(_Act a) => switch (a) {
        _Act.hop => 1.15,
        _Act.wave => 1.7,
        _Act.spin => 1.3,
        _Act.quack => 1.0,
      };

  // --- Gestures -----------------------------------------------------------

  void _dragStart(DragStartDetails d) {
    _dragging = true;
    _target = null;
    _peakVel = 0;
    _finger = d.localPosition;
    HapticFeedback.selectionClick();
  }

  void _dragUpdate(DragUpdateDetails d) {
    final dy = d.delta.dx * _perPixel;
    _yaw += dy;
    _dragVel = _dragVel * 0.6 + dy * 60 * 0.4;
    _finger = d.localPosition;
  }

  void _dragEnd(DragEndDetails d) {
    _dragging = false;
    _finger = null;
    _yawVel = d.velocity.pixelsPerSecond.dx * _perPixel;
    _peakVel = _yawVel.abs();
    _dragVel = 0;
  }

  // --- Frame --------------------------------------------------------------

  void _tick(Duration elapsed) {
    final dt = _last == null
        ? 1 / 60
        : ((elapsed - _last!).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    _t += dt;
    _spin(dt);
    if (_still) {
      _pose
        ..yaw = _restYaw + _yaw
        ..lid = 0.12
        ..shades = _shadesUp ? 1 : 0;
    } else {
      _animate(dt);
    }
    _frame.value++;
  }

  void _spin(double dt) {
    if (_dragging) return;
    if (_yawVel.abs() > 1.4 && _target == null) {
      _yaw += _yawVel * dt;
      _yawVel *= math.exp(-1.7 * dt);
      return;
    }
    if (_target == null) {
      _target = (_yaw / (2 * math.pi)).round() * 2 * math.pi;
      if (_peakVel > 13 && !_still) _dizzyAt = _t;
      _peakVel = 0;
    }
    _yawVel += (-60 * (_yaw - _target!) - 10 * _yawVel) * dt;
    _yaw += _yawVel * dt;
    if ((_yaw - _target!).abs() < 1e-3 && _yawVel.abs() < 1e-2) {
      _yaw -= _target!;
      _target = 0;
    }
  }

  void _animate(double dt) {
    final t = _t, p = _pose;
    final vel = _dragging ? _dragVel : _yawVel;

    // Idle life: breath, a slow weight shift and sway.
    final settled = !_dragging && vel.abs() < 0.3;
    final sway = settled ? 0.07 * math.sin(t * 2 * math.pi / 7) : 0.0;
    var yaw = _restYaw + _yaw + sway;
    var hop = 0.0, squash = 1.0, lean = 0.0;
    var roll = 0.025 * math.sin(t * 2 * math.pi / 5);
    var lid = 0.12, brow = 0.0, browTilt = 0.0, bill = 0.0;
    var wingL = 0.04 * math.sin(t * 2 * math.pi / 3.2);
    var wingR = wingL;
    var footL = 0.0, footR = 0.0, wave = 0.0;
    var headPitch = 0.04 * math.sin(t * 2 * math.pi / 3.2);
    var headRoll = 0.0, kick = 0.0;
    double? lookOverride;

    // Where to look.
    final bodyDir = yaw;
    final finger = _finger;
    double lookDir, lookPitch;
    if (finger != null && !_dragging) {
      final nx = (finger.dx / widget.size - 0.5) * 2;
      final ny = (finger.dy / widget.size - 0.35) * 2;
      lookDir = _towardViewer + nx * 1.1;
      lookPitch = (-ny * 0.6).clamp(-0.5, 0.6);
    } else {
      if (t > _nextLook) {
        _nextLook = t + 1.8 + _rng.nextDouble() * 3.2;
        final r = _rng.nextDouble();
        // Most often it checks on you; otherwise glances around.
        _lookDir = r < 0.4
            ? _towardViewer
            : _restYaw + (_rng.nextDouble() - 0.5) * 1.4;
        _lookPitch = r > 0.85 ? 0.35 : (_rng.nextDouble() - 0.4) * 0.3;
      }
      lookDir = _dragging ? bodyDir : _lookDir;
      lookPitch = _dragging ? 0 : _lookPitch;
    }

    // Blinks, sometimes twice.
    if (t > _nextBlink) {
      _blinkAt = t;
      _doubleBlink = _rng.nextDouble() < 0.2;
      _nextBlink = t + 2.2 + _rng.nextDouble() * 3.5;
    }
    double blink(double since) =>
        since >= 0 && since < 0.16 ? math.sin(math.pi * since / 0.16) : 0;
    var closing = blink(t - _blinkAt);
    if (_doubleBlink) closing = math.max(closing, blink(t - _blinkAt - 0.24));

    // Tail wags in bursts.
    if (t > _nextWag) {
      _wagAt = t;
      _nextWag = t + 4 + _rng.nextDouble() * 5;
    }
    var tail = _burst(t - _wagAt, 0.7) * 0.4 * math.sin((t - _wagAt) * 28);

    // Dizzy after a wild spin: the head circles, the eyes roll.
    final dz = t - _dizzyAt;
    var eyeSwirl = 0.0;
    if (dz >= 0 && dz < 2.4 && settled) {
      final fade = 1 - dz / 2.4;
      headRoll += 0.16 * fade * math.sin(dz * 7);
      headPitch += 0.08 * fade * math.cos(dz * 7);
      eyeSwirl = fade;
      lid = 0.3;
      browTilt = -0.8 * fade;
    }

    // The current action.
    final act = _act;
    if (act != null) {
      final a = t - _actAt;
      final dur = _duration(act);
      if (a > dur) {
        _act = null;
      } else {
        switch (act) {
          case _Act.hop:
          case _Act.spin:
            final high = act == _Act.spin ? 38.0 : 30.0;
            final j = _jump(a, high);
            hop = j.hop;
            squash = j.squash;
            lean = j.lean;
            kick = j.kick;
            if (j.air) {
              final f = math.sin(a * 2 * math.pi * 6).abs();
              wingL = wingR = 0.25 + 0.9 * f;
              footL = footR = 3;
            }
            if (a > 0.1 && a < 0.36) {
              bill = math.sin(math.pi * (a - 0.1) / 0.26);
            }
            brow = a < 0.5 ? 1 : 0.5;
            lid = a < 0.2 ? 0 : 0.42; // surprise, then a happy squint
            if (act == _Act.spin) {
              yaw += 2 *
                  math.pi *
                  Curves.easeInOut.transform(((a - 0.14) / 0.48).clamp(0, 1));
            }
            if (!_landed && a > 0.56) {
              _landed = true;
              HapticFeedback.mediumImpact();
            }
            // Happy feet after landing.
            if (a > 0.66 && a < 1.0) {
              final s = math.sin((a - 0.66) * 26);
              footL = math.max(0, s) * 4;
              footR = math.max(0, -s) * 4;
              tail = 0.45 * math.sin(a * 30);
            }
          case _Act.wave:
            final up = _burst(a, dur);
            // Near wing up and waving; head tilts.
            wave = up * (2.1 + 0.35 * math.sin(a * 13));
            wingR = 0.45 * up;
            headRoll += -0.18 * up;
            lean = -0.06 * up;
            brow = 0.7 * up;
            lid = 0.12 + 0.3 * up;
            if (a > 0.15 && a < 0.45) {
              bill = math.sin(math.pi * (a - 0.15) / 0.3);
            }
            squash = 1 + 0.03 * math.sin(a * 9) * up;
            lookOverride = _towardViewer;
          case _Act.quack:
            for (final q in [0.1, 0.45]) {
              final s = a - q;
              if (s > 0 && s < 0.28) {
                final w = math.sin(math.pi * s / 0.28);
                bill = math.max(bill, w);
                headPitch += 0.22 * w;
                squash = 1 - 0.07 * w;
                kick = 0.6 * w;
              }
            }
            brow = 0.6;
            tail = 0.4 * math.sin(a * 24) * _burst(a, dur);
            lookOverride = _towardViewer;
        }
      }
    }

    // Head and eyes: the eyes lead, the head follows and lags behind turns.
    final want = (lookOverride ?? lookDir) - yaw;
    final headWant = (want * 0.7).clamp(-0.85, 0.85);
    _headYaw.step(headWant + (-0.1 * vel).clamp(-0.6, 0.6), dt, k: 70, c: 9);
    _headPitch.step(lookPitch * 0.55, dt, k: 70, c: 10);
    _headRoll.step(headRoll, dt, k: 120, c: 12);
    _eyeX.step((-(want - _headYaw.x) * 1.6).clamp(-1, 1), dt, k: 400, c: 34);
    _eyeY.step((lookPitch * 1.4).clamp(-1, 1), dt, k: 400, c: 34);
    _roll.step(roll + (0.025 * vel).clamp(-0.22, 0.22), dt, k: 120, c: 12);
    // Loose parts: kicked by turning, hopping and quacking.
    _swing.step(0, dt, k: 80, c: 5);
    _swing.v +=
        (-0.6 * (vel - _lastVel) / math.max(dt, 1e-3) * 0.02 + kick * 0.6) *
            dt *
            8;
    _lastVel = vel;
    _lid.step(lid - 0.06 * _eyeY.x, dt, k: 300, c: 30);
    _brow.step(brow, dt, k: 200, c: 18);

    // Lenses flip with a little bounce; the brows lift as they open.
    _shades.step(_shadesUp ? 1 : 0, dt, k: 160, c: 11);
    final peek = _burst(t - _peekAt, 0.6);
    _brow.x = math.max(_brow.x, peek * 0.9);

    p
      ..shades = _shades.x
      ..yaw = yaw
      ..hop = hop
      ..squash = squash
      ..lean = lean
      ..roll = _roll.x
      ..breathe = math.sin(t * 2 * math.pi / 3.2)
      ..headYaw = _headYaw.x
      ..headPitch = _headPitch.x + headPitch
      ..headRoll = _headRoll.x
      ..eyeX = eyeSwirl > 0 ? math.cos(t * 9) * eyeSwirl : _eyeX.x
      ..eyeY = eyeSwirl > 0 ? math.sin(t * 9) * eyeSwirl : _eyeY.x
      ..lid = math.max(_lid.x, closing).clamp(0.0, 1.0)
      ..brow = _brow.x
      ..browTilt = browTilt
      ..bill = bill
      ..wingL = wingL
      ..wingR = wingR
      ..wave = wave
      ..footL = footL
      ..footR = footR
      ..tail = tail
      ..swing = _swing.x;
  }

  double _lastVel = 0;
  double _peekAt = -9;

  /// 0 → 1 → 0 over [dur], quick in and out.
  static double _burst(double a, double dur) {
    if (a < 0 || a > dur) return 0;
    return math.sin(math.pi * a / dur).clamp(0.0, 1.0);
  }

  /// A jump with anticipation, stretch, airtime, a squash on landing and a
  /// springy settle.
  static ({double hop, double squash, double lean, double kick, bool air})
      _jump(double a, double high) {
    const crouch = 0.14, takeoff = 0.14, land = 0.56;
    if (a < crouch) {
      final k = Curves.easeOut.transform(a / crouch);
      return (
        hop: 0,
        squash: 1 - 0.16 * k,
        lean: -0.12 * k,
        kick: 0,
        air: false
      );
    }
    if (a < land) {
      final f = (a - takeoff) / (land - takeoff);
      final h = 4 * f * (1 - f);
      final stretch = f < 0.5 ? 1.14 - 0.24 * f : 1.02 + 0.08 * (f - 0.5);
      return (
        hop: high * h,
        squash: stretch,
        lean: 0.1 * (0.5 - f),
        kick: f < 0.2 ? 1.0 : 0.0,
        air: true,
      );
    }
    final s = a - land;
    return (
      hop: 0,
      squash: 1 - 0.2 * math.exp(-6 * s) * math.sin(14 * s + 0.6) * 1.2,
      lean: 0.04 * math.exp(-6 * s) * math.sin(14 * s),
      kick: s < 0.1 ? 1.0 : 0.0,
      air: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _finger = d.localPosition,
        onTapCancel: () => _finger = null,
        onTapUp: (d) {
          _tap(d.localPosition);
          Future.delayed(
              const Duration(milliseconds: 900), () => _finger = null);
        },
        onHorizontalDragStart: _dragStart,
        onHorizontalDragUpdate: _dragUpdate,
        onHorizontalDragEnd: _dragEnd,
        // Its own layer: a frame repaints the duck, not the card.
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _DuckPainter(this),
          ),
        ),
      ),
    );
  }
}

class _DuckPainter extends CustomPainter {
  _DuckPainter(this.state) : super(repaint: state._frame);
  final _Duck3DState state;

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.widget;
    state._renderer.paint(canvas, size, state._pose,
        level: w.level, extras: w.extras, stickers: w.stickers);
  }

  @override
  bool shouldRepaint(_DuckPainter old) => true;
}

/// Draws one still pose; for tests and generated images.
@visibleForTesting
void paintDuckForTest(Canvas canvas, Size size, DuckPose pose,
    {int level = 0,
    Set<SuitcaseExtra> extras = const {},
    List<SuitcaseSticker> stickers = const []}) {
  DuckRenderer().paint(canvas, size, pose,
      level: level, extras: extras, stickers: stickers);
}
