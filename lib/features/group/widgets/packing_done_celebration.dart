import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/utils/suitcase_progress.dart';
import '../../../common/widgets/suitcase_view.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../l10n/l10n.dart';

/// "All packed!" when the last thing is ticked off: the handle slides in
/// with a click, the suitcase hops, a light sweeps over the shell and the
/// miles pop up.
Future<void> showPackingDoneCelebration(
  BuildContext context, {
  required String cityName,
}) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, __) => _PackingDone(
      cityName: cityName,
      onDone: () => Navigator.of(dialogContext).pop(),
    ),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _PackingDone extends StatefulWidget {
  const _PackingDone({required this.cityName, required this.onDone});

  final String cityName;
  final VoidCallback onDone;

  @override
  State<_PackingDone> createState() => _PackingDoneState();
}

class _PackingDoneState extends State<_PackingDone>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  // Handle in, hop, light sweep, miles badge, text.
  late final _handle = CurvedAnimation(
      parent: _c, curve: const Interval(0.05, 0.3, curve: Curves.easeInBack));
  late final _hop =
      CurvedAnimation(parent: _c, curve: const Interval(0.3, 0.55));
  late final _shine = CurvedAnimation(
      parent: _c, curve: const Interval(0.5, 0.75, curve: Curves.easeInOut));
  late final _miles = CurvedAnimation(
      parent: _c, curve: const Interval(0.62, 0.8, curve: Curves.easeOutBack));
  late final _text = CurvedAnimation(
      parent: _c, curve: const Interval(0.4, 0.65, curve: Curves.easeOut));

  bool _clicked = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_clicked && _c.value >= 0.3) {
        _clicked = true;
        HapticFeedback.heavyImpact();
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
    const size = 200.0;

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
                  // One hop up and a squash on landing.
                  final hop = math.sin(_hop.value * math.pi);
                  final squash = c > 0.5 && c < 0.6 ? 1 - (0.6 - c) * 0.6 : 1.0;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Transform.translate(
                        offset: Offset(0, -28 * hop),
                        child: Transform.scale(
                          scaleY: squash,
                          alignment: Alignment.bottomCenter,
                          child: SizedBox.square(
                            dimension: size,
                            child: CustomPaint(
                              painter: SuitcasePainter(
                                handleOut: 1 - _handle.value,
                                shine:
                                    c > 0.5 && c < 0.75 ? _shine.value : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: -18,
                        child: Transform.scale(
                          scale: _miles.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: BrandColors.amber,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              l10n.packingDoneMiles(milesPerPackedTrip),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: BrandColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSizes.space32),
              FadeTransition(
                opacity: _text,
                child: Column(
                  children: [
                    Text(
                      l10n.packingDoneTitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.display(
                          size: 38, color: scheme.onSurface),
                    ),
                    const SizedBox(height: AppSizes.space12),
                    Text(
                      l10n.packingDoneBody(widget.cityName),
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
                    child: Text(l10n.packingDoneClose),
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
