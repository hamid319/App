import 'package:flutter/material.dart';
import '../../core/constants/typography.dart';
import 'swipe_pin_mark.dart';

/// SwipeTrip logo: the swipe-pin mark followed by the "swipetrip" logotype
/// (ink + brand orange, in the display font).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24, this.showMark = true});

  final double size;

  /// False shows the logotype alone.
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppTypography.display(size: size, color: scheme.onSurface);
    return Semantics(
      label: 'SwipeTrip',
      header: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMark) ...[
              SwipePinMark(size: size * 1.35),
              SizedBox(width: size * 0.35),
            ],
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'swipe'),
                  TextSpan(
                    text: 'trip',
                    style: TextStyle(color: scheme.primary),
                  ),
                ],
              ),
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
