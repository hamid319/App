import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/widgets/suitcase_view.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../l10n/l10n.dart';

/// Full-screen "Bags packed!" moment after a new trip: things drop into the
/// open suitcase, the lid shuts, it spins once and gets the city sticker.
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
    duration: const Duration(milliseconds: 2600),
  );

  static const _openLid = -1.95;

  // Timeline (fractions of the whole): pop in, items drop, lid shuts,
  // spin, sticker.
  late final _pop = CurvedAnimation(
      parent: _c, curve: const Interval(0, 0.12, curve: Curves.easeOutBack));
  late final _close = CurvedAnimation(
      parent: _c, curve: const Interval(0.46, 0.58, curve: Curves.easeInCubic));
  late final _spin = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.6, 0.86, curve: Curves.easeInOutCubic));
  late final _sticker = CurvedAnimation(
      parent: _c, curve: const Interval(0.88, 1, curve: Curves.easeOutBack));
  late final _text = CurvedAnimation(
      parent: _c, curve: const Interval(0.62, 0.8, curve: Curves.easeOut));

  bool _shut = false, _stuck = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_shut && _c.value >= 0.58) {
        _shut = true;
        HapticFeedback.lightImpact();
      }
      if (!_stuck && _c.value >= 0.94) {
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
                builder: (context, _) => _Art(
                  pop: _pop.value,
                  progress: _c.value,
                  lidAngle: _openLid * (1 - _close.value),
                  spin: _spin.value,
                  sticker: sticker,
                  stickerScale:
                      _c.value < 0.88 ? 0 : 2.4 - 1.4 * _sticker.value,
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

/// The suitcase with the items dropping in and its shadow.
class _Art extends StatelessWidget {
  const _Art({
    required this.pop,
    required this.progress,
    required this.lidAngle,
    required this.spin,
    required this.sticker,
    required this.stickerScale,
  });

  final double pop, progress, lidAngle, spin, stickerScale;
  final SuitcaseSticker sticker;

  static const double _size = 220;

  // Items: icon, colour, x offset, start of its drop (fraction).
  static const _items = [
    (Icons.checkroom_rounded, BrandColors.coral, -34.0, 0.10),
    (Icons.photo_camera_rounded, BrandColors.amber, 24.0, 0.18),
    (Icons.wb_sunny_rounded, BrandColors.sky, -8.0, 0.26),
    (Icons.map_rounded, Color(0xFF8FE3BF), 36.0, 0.34),
  ];

  @override
  Widget build(BuildContext context) {
    // The suitcase's opening (grid y 45) sits at this height in the box.
    const opening = _size * 0.45;
    return SizedBox(
      width: _size,
      height: _size + 20,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Shadow, narrower while the suitcase is side-on.
          Positioned(
            top: _size * 0.9,
            child: Container(
              width: _size *
                  0.62 *
                  (0.35 + 0.65 * math.cos(spin * 2 * math.pi).abs()),
              height: 14,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Items drop behind the shell, so they vanish into it.
          for (final (icon, color, dx, start) in _items)
            if (progress > start && progress < start + 0.2)
              Positioned(
                left: _size / 2 + dx - 18,
                top: -60 +
                    (opening + 30 + 60) *
                        Curves.easeIn.transform(
                            ((progress - start) / 0.2).clamp(0.0, 1.0)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: BrandColors.navy),
                ),
              ),
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(spin * 2 * math.pi)
              ..scaleByDouble(0.6 + 0.4 * pop, 0.6 + 0.4 * pop, 1, 1),
            child: SizedBox.square(
              dimension: _size,
              child: CustomPaint(
                painter: SuitcasePainter(
                  lidAngle: lidAngle,
                  stickers: stickerScale > 0 ? [sticker] : const [],
                  lastStickerScale: stickerScale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
