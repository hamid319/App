import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "swipetrip" logotype: ink + brand orange, in the display font.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.04 * size,
      color: scheme.onSurface,
    );
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
