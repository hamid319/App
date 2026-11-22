import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/constants/typography.dart';
import 'brand_mark.dart';

/// Out We Go logo: the duck mark followed by the "Out We Go" logotype in the
/// tint (forest, lime in dark mode).
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
      label: 'Out We Go',
      header: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMark) ...[
              BrandMark(size: size * 1.35),
              SizedBox(width: size * 0.35),
            ],
            Text(
              'Out We Go',
              style: style.copyWith(
                color: context.pageTint,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
