import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/typography.dart';
import 'tripfam_mark.dart';

/// TripFam logo: the suitcase mark followed by the "tripfam" logotype
/// ("trip" in the tint, navy or sky in dark mode; "fam" in coral).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24, this.showMark = true});

  final double size;

  /// False shows the logotype alone.
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    // The logo sits on the page (see SwipeColors.onBg).
    final style = AppTypography.display(size: size, color: context.onBg);
    return Semantics(
      label: 'TripFam',
      header: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMark) ...[
              TripFamMark(size: size * 1.35),
              SizedBox(width: size * 0.35),
            ],
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'trip',
                    style: TextStyle(color: context.pageTint),
                  ),
                  const TextSpan(
                    text: 'fam',
                    style: TextStyle(color: BrandColors.coral),
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
