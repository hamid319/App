import 'package:flutter/material.dart';
import '../../core/constants/typography.dart';

/// "swipetrip" logotype: ink + brand orange, in the display font.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppTypography.display(size: size, color: scheme.onSurface);
    return Semantics(
      label: 'SwipeTrip',
      header: true,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'swipe'),
              TextSpan(text: 'trip', style: TextStyle(color: scheme.primary)),
            ],
          ),
          style: style,
        ),
      ),
    );
  }
}
