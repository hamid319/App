import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/widgets/suitcase_view.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../l10n/l10n.dart';

/// Full-screen "Bags packed!" moment after a new trip: the suitcase rolls
/// in, rocks to a stop, pulls out its handle with a click, a light sweeps
/// over the grooves and the city sticker is slapped on.
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

class _TripCreatedState extends State<_TripCreated>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  // Timeline (fractions of the whole): roll in, rock to a stop, handle
  // out, light sweep, sticker.
  late final _roll = CurvedAnimation(
      parent: _c, curve: const Interval(0, 0.32, curve: Curves.easeOutCubic));
  late final _rock =
      CurvedAnimation(parent: _c, curve: const Interval(0.32, 0.48));
  late final _handle = CurvedAnimation(
      parent: _c, curve: const Interval(0.48, 0.62, curve: Curves.easeOutBack));
  late final _shine = CurvedAnimation(
      parent: _c, curve: const Interval(0.62, 0.82, curve: Curves.easeInOut));
  late final _sticker = CurvedAnimation(
      parent: _c, curve: const Interval(0.84, 0.96, curve: Curves.easeOutBack));
  late final _text = CurvedAnimation(
      parent: _c, curve: const Interval(0.55, 0.75, curve: Curves.easeOut));

  bool _clicked = false, _stuck = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_clicked && _c.value >= 0.6) {
        _clicked = true;
        HapticFeedback.lightImpact();
      }
      if (!_stuck && _c.value >= 0.9) {
        _stuck = true;
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
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

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space24),
          child: Column(
            children: [
              const Spacer(),
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final c = _c.value;
                  final r = _rock.value;
                  return _Art(
                    roll: _roll.value,
                    // Leans back while pulled in, then rocks on its wheels.
                    tilt: c < 0.32
                        ? -0.07 * _roll.value
                        : -0.07 * math.cos(r * math.pi * 3) * (1 - r),
                    handleOut: _handle.value,
                    shine: c > 0.62 && c < 0.82 ? _shine.value : null,
                    sticker: sticker,
                    stickerScale: c < 0.84 ? 0 : 2.4 - 1.4 * _sticker.value,
                  );
                },
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

/// The suitcase rolling in, with its shadow.
class _Art extends StatelessWidget {
  const _Art({
    required this.roll,
    required this.tilt,
    required this.handleOut,
    required this.shine,
    required this.sticker,
    required this.stickerScale,
  });

  /// 0 = off screen on the left, 1 = in place.
  final double roll;
  final double tilt, handleOut, stickerScale;
  final double? shine;
  final SuitcaseSticker sticker;

  static const double _size = 220;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dx = -(width / 2 + _size / 2) * (1 - roll);
    // Wheel radius on screen: 3.6 grid units of the 220 px box.
    const wheelRadius = _size * 0.036;
    return Transform.translate(
      offset: Offset(dx, 0),
      child: SizedBox(
        width: _size,
        height: _size + 12,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: _size * 0.945,
              child: Container(
                width: _size * 0.5,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Transform.rotate(
              angle: tilt,
              alignment: const Alignment(0, 0.9),
              child: SizedBox.square(
                dimension: _size,
                child: CustomPaint(
                  painter: SuitcasePainter(
                    handleOut: handleOut,
                    wheelTurn: -dx / wheelRadius,
                    shine: shine,
                    stickers: stickerScale > 0 ? [sticker] : const [],
                    lastStickerScale: stickerScale,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
