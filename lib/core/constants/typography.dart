import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The platform's system font everywhere (San Francisco on iOS, Roboto on
/// Android), as Apple's HIG asks: `null` families let Flutter pick it.
/// Titles get iOS's large-title weights and tight tracking.
class AppTypography {
  static const String? bodyFamily = null;
  static const String? displayFamily = null;

  static TextStyle _display(double size, double height, FontWeight weight) =>
      TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: -0.02 * size,
      );

  static TextTheme textTheme(Color ink, Color ink2) {
    final base = Typography.material2021(platform: defaultTargetPlatform)
        .englishLike
        .merge(Typography.material2021(platform: defaultTargetPlatform).black);

    return base
        .copyWith(
          displaySmall: _display(34, 41 / 34, FontWeight.w700),
          headlineMedium: _display(28, 34 / 28, FontWeight.w700),
          headlineSmall: _display(22, 28 / 22, FontWeight.w700),
          titleLarge: _display(20, 25 / 20, FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            fontSize: 17,
            height: 22 / 17,
            letterSpacing: -0.4,
          ),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, height: 20 / 15),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        )
        .apply(bodyColor: ink, displayColor: ink);
  }

  /// Big place name on a swipe card.
  static TextStyle cardTitle() => const TextStyle(
        fontFamily: displayFamily,
        fontSize: 26,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Colors.white,
      );

  /// Answer line of a prompt tile.
  static TextStyle prompt(Color color) => TextStyle(
        fontFamily: displayFamily,
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: color,
      );

  /// LIKE / NOPE stamp.
  static TextStyle stamp(Color color) => TextStyle(
        fontFamily: displayFamily,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: color,
      );

  /// Logotype and celebration headlines.
  static TextStyle display({
    required double size,
    required Color color,
    double height = 1,
  }) =>
      TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: height,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * size,
        color: color,
      );
}
