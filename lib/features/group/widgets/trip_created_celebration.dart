import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import 'package:flutter/services.dart';

import '../../../common/widgets/duck_3d_model.dart';
import '../../../common/widgets/suitcase_view.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../l10n/l10n.dart';

/// Full-screen "Your trip is on!" moment after a new trip: the backpack
/// (with the new city sticker) lies on the ground, the duck dashes in, skids
/// to a stop, picks it up, balances on one leg while it swings the pack onto
/// its back, and runs off the screen.
Future<void> showTripCreatedCelebration(
  BuildContext context, {
  required String cityName,
  required int stickerSeed,
}) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, _, __) => _TripCreated(
      cityName: cityName,
      stickerSeed: stickerSeed,
      onDone: () => Navigator.of(dialogContext).pop(),
    ),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _TripCreated extends StatefulWidget {
  const _TripCreated({
    required this.cityName,
    required this.stickerSeed,
    required this.onDone,
  });

  final String cityName;
  final int stickerSeed;
  final VoidCallback onDone;

  @override
  State<_TripCreated> createState() => _TripCreatedState();
}

// The scene's length in seconds; the beats below are in seconds too.
const double _length = 4.0;
const double _skid = 0.75, _stop = 1.15, _go = 3.2, _gone = 3.9;
const double _bend = 1.4, _grab = 1.65, _lifted = 2.0;
const double _swingFrom = 2.2, _swingTo = 2.8;

class _TripCreatedState extends State<_TripCreated>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  );
  late final _text = CurvedAnimation(
      parent: _c, curve: const Interval(0.78, 0.92, curve: Curves.easeOut));
  final _renderer = DuckRenderer();
  bool _braked = false, _grabbed = false, _packed = false, _still = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final t = _c.value * _length;
      if (!_braked && t >= _skid) {
        _braked = true;
        HapticFeedback.lightImpact();
      }
      if (!_grabbed && t >= _grab) {
        _grabbed = true;
        HapticFeedback.selectionClick();
      }
      if (!_packed && t >= _swingTo) {
        _packed = true;
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.of(context).disableAnimations;
    if (_c.isAnimating || _c.isCompleted) return;
    if (_still) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sticker = SuitcaseSticker(
      label: cityStickerLabel(widget.cityName),
      seed: widget.stickerSeed,
    );
    final width = MediaQuery.sizeOf(context).width;

    return Material(
      color: context.swipeColors.sheet,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space24),
          child: Column(
            children: [
              const Spacer(),
              ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = _c.value * _length;
                    return SizedBox.square(
                      dimension: _box,
                      child: CustomPaint(
                        painter: _DuckPainter(
                          _renderer,
                          _still
                              ? (DuckPose()..yaw = -0.45)
                              : _pose(t, (width + _box) / 2 / _unit),
                          sticker,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSizes.space32),
              FadeTransition(
                opacity: _text,
                child: Column(
                  children: [
                    Text(
                      l10n.tripCreatedTitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.display(
                          size: 38, color: scheme.onSurface),
                    ),
                    const SizedBox(height: AppSizes.space12),
                    Text(
                      l10n.tripCreatedBody(widget.cityName),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _text,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onDone,
                    child: Text(l10n.tripCreatedOpen),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const double _box = 250;

/// Screen pixels per model unit at level 2 (see DuckRenderer.paint).
const double _unit = _box / 180 * 0.9;

/// Where the duck stops: the pack lies just in front of it, mid-screen.
const double _spot = -14;

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0, 1);
double _lerp(double a, double b, double k) => a + (b - a) * k;

/// Where the duck is along the ground; [off] is just out of view.
double _x(double t, double off) {
  if (t < _skid) return _lerp(-off, _spot - 30, t / _skid);
  if (t < _stop) {
    return _lerp(_spot - 30, _spot,
        Curves.easeOutCubic.transform(_seg(t, _skid, _stop)));
  }
  if (t < _go) return _spot;
  return _lerp(_spot, off, Curves.easeInCubic.transform(_seg(t, _go, _gone)));
}

/// The scene at [t] seconds, for tests.
@visibleForTesting
DuckPose tripCreatedDuckPose(double t) => _pose(t, 200);

/// One frame of the scene; the duck looks right (yaw 0) while it runs.
DuckPose _pose(double t, double off) {
  final p = DuckPose()
    ..x = _x(t, off)
    ..dropX = _spot;

  void run(double phase, double amount) {
    final s = math.sin(phase), c = math.cos(phase);
    p
      ..footL = 9 * math.max(0, s) * amount
      ..footR = 9 * math.max(0, -s) * amount
      ..strideL = 13 * c * amount
      ..strideR = -13 * c * amount
      ..hop = 5 * s.abs() * amount
      ..lean = -0.22 * amount
      ..wingL = (0.45 + 0.35 * s) * amount
      ..tail = 0.3 * s * amount
      ..swing = 0.6 * s * amount
      ..headPitch = 0.05 * math.sin(2 * phase) * amount;
  }

  if (t < _skid) {
    // Dashing in, both wings pumping; the pack waits on the ground.
    run(2 * math.pi * 3.2 * t, 1);
    final s = math.sin(2 * math.pi * 3.2 * t);
    p
      ..wingR = 0.45 - 0.35 * s
      ..pack = 0
      ..drop = 1
      ..lid = 0;
  } else if (t < _stop) {
    // Skid: lean back, feet planted ahead, wings out, "whoa".
    final b = _seg(t, _skid, _stop);
    final hump = math.sin(math.pi * b);
    run(2 * math.pi * 3.2 * t, 1 - _seg(b, 0, 0.25));
    final plant = Curves.easeOut.transform(_seg(b, 0, 0.25));
    p
      ..strideL = _lerp(p.strideL, 16 * (1 - b), plant)
      ..strideR = _lerp(p.strideR, 16 * (1 - b), plant)
      ..lean = _lerp(p.lean, 0.35 * hump, plant)
      ..squash = 1 - 0.1 * hump
      ..bill = 0.6 * hump
      ..brow = 0.8 * hump
      ..wingL = 1.0 * hump
      ..wingR = 1.0 * hump
      ..pack = 0
      ..drop = 1
      ..lid = 0;
  } else if (t < _lifted) {
    // Spots the pack, bends down, grabs it and straightens up with it.
    final look = Curves.easeInOut.transform(_seg(t, _stop, _bend));
    final down = Curves.easeInOut.transform(_seg(t, _bend, _grab)) -
        Curves.easeInOut.transform(_seg(t, _grab, _lifted));
    final lift = Curves.easeInOut.transform(_seg(t, _grab, _lifted));
    p
      ..squash = 1 - 0.08 * down
      ..lean = -0.45 * down
      ..headPitch = -0.35 * look * (1 - lift)
      ..eyeY = -0.7 * look * (1 - lift)
      ..brow = 0.5 * look * (1 - lift)
      ..wingR = 0.6 * down
      ..wingL = 0.3 * down
      ..pack = 0
      ..drop = 1 - lift
      ..lid = 0;
  } else if (t < _go) {
    // Stand on one leg, wobble, swing the pack onto the back.
    final settle = _seg(t, _lifted, _lifted + 0.3);
    final leg = _seg(t, _lifted + 0.15, _lifted + 0.3) -
        _seg(t, _swingTo + 0.05, _swingTo + 0.2);
    final s = _seg(t, _swingFrom, _swingTo);
    final k = Curves.easeInOutCubic.transform(s);
    final land = _seg(t, _swingTo, _swingTo + 0.3);
    final ready = _seg(t, _go - 0.15, _go);
    p
      ..yaw = -0.45 * Curves.easeInOut.transform(settle) * (1 - ready)
      ..squash =
          1 - 0.12 * math.sin(math.pi * land) - 0.08 * math.sin(math.pi * ready)
      ..footR = 18 * leg
      ..strideR = 10 * leg
      ..roll = 0.07 * math.sin(2 * math.pi * 2.2 * (t - _lifted)) * leg
      ..wingL = 0.7 * leg
      ..pack = k
      ..wave = 1.7 * math.sin(math.pi * s)
      ..wingR = 0.15 * (1 - k)
      ..headYaw = 0.35 * math.sin(math.pi * s)
      ..eyeX = -0.6 * math.sin(math.pi * s)
      ..lid = 0.55 * math.sin(math.pi * land)
      ..bill = 0.4 * math.sin(math.pi * land)
      ..lean = 0.15 * math.sin(math.pi * ready)
      ..swing = 0.4 * math.sin(math.pi * 2 * land);
  } else {
    // Off it runs, faster and faster.
    final a = _seg(t, _go, _go + 0.15);
    run(2 * math.pi * 3.6 * (t - _go), a);
    p.lid = 0;
  }
  return p;
}

class _DuckPainter extends CustomPainter {
  _DuckPainter(this.renderer, this.pose, this.sticker);

  final DuckRenderer renderer;
  final DuckPose pose;
  final SuitcaseSticker sticker;

  @override
  void paint(Canvas canvas, Size size) => renderer.paint(canvas, size, pose,
      level: 2, extras: const {}, stickers: [sticker]);

  @override
  bool shouldRepaint(_DuckPainter old) => true;
}
