import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../common/widgets/duck_3d_model.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../l10n/l10n.dart';

/// Full-screen "You're in!" moment after joining a trip: three ducks, each
/// with a different mattress on its pack, run across from left to right.
Future<void> showTripJoinedCelebration(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, _, __) =>
        _TripJoined(onDone: () => Navigator.of(dialogContext).pop()),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

// One run across the screen, in seconds; it repeats until the button.
const double _lap = 3.2;
const double _box = 150, _gap = 105;
// Orange, lime and the avatars' blue: three friends, three bedrolls.
const _mattresses = [
  BrandColors.orange,
  BrandColors.lime,
  Color(0xFF3B6FD6),
];

class _TripJoined extends StatefulWidget {
  const _TripJoined({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_TripJoined> createState() => _TripJoinedState();
}

class _TripJoinedState extends State<_TripJoined>
    with TickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  final _renderers = [for (final _ in _mattresses) DuckRenderer()];
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.of(context).disableAnimations;
    if (_still) {
      _c.stop();
      _fade.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat();
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _fade.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: context.swipeColors.sheet,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space24),
          child: Column(
            children: [
              const Spacer(),
              ExcludeSemantics(
                child: SizedBox(
                  height: _box,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => CustomPaint(
                      painter: _ParadePainter(
                          _renderers, _still ? null : _c.value * _lap),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.space32),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text(
                      l10n.tripJoinedTitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.display(
                          size: 38, color: scheme.onSurface),
                    ),
                    const SizedBox(height: AppSizes.space12),
                    Text(
                      l10n.tripJoinedBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _fade,
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

/// A running duck, [phase] in radians of its stride.
@visibleForTesting
DuckPose tripJoinedDuckPose(double phase) {
  final s = math.sin(phase), c = math.cos(phase);
  return DuckPose()
    ..footL = 9 * math.max(0, s)
    ..footR = 9 * math.max(0, -s)
    ..strideL = 13 * c
    ..strideR = -13 * c
    ..hop = 5 * s.abs()
    ..lean = -0.2
    ..wingL = 0.45 + 0.35 * s
    ..wingR = 0.45 - 0.35 * s
    ..tail = 0.3 * s
    ..swing = 0.6 * s
    ..headPitch = 0.05 * math.sin(2 * phase)
    ..lid = 0;
}

class _ParadePainter extends CustomPainter {
  _ParadePainter(this.renderers, this.t);

  final List<DuckRenderer> renderers;

  /// Seconds into the lap; null stands the three still in a row.
  final double? t;

  @override
  void paint(Canvas canvas, Size size) {
    final t = this.t;
    // The whole row enters on the left and leaves on the right, the
    // leader first; the screen is wider than the padded box.
    final span = size.width + 2 * _gap + 2 * _box;
    final lead =
        t == null ? size.width / 2 + _gap : -_box / 2 - 48 + span * (t / _lap);
    for (var i = 0; i < renderers.length; i++) {
      final x = lead - i * _gap;
      final pose = t == null
          ? (DuckPose()..yaw = -0.45)
          // Each runs a touch out of step, so they don't look cloned.
          : tripJoinedDuckPose(2 * math.pi * 3.4 * t + i * 2.1);
      canvas
        ..save()
        ..translate(x - _box / 2, 0);
      renderers[i].paint(canvas, const Size(_box, _box), pose,
          level: 2,
          extras: const {},
          stickers: const [],
          mattress: _mattresses[i]);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParadePainter old) => true;
}
