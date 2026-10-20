import 'package:flutter/material.dart';

/// Bricolage Grotesque for titles, Figtree for everything else. Both are
/// bundled under assets/fonts (SIL OFL 1.1) and declared in pubspec.yaml
/// with one file per weight, so `fontWeight` picks the real cut instead of
/// a synthesized bold, and no font is fetched from the network.
class AppTypography {
  static const bodyFamily = 'Figtree';
  static const displayFamily = 'BricolageGrotesque';

  static TextStyle _display(double size, double height, FontWeight weight) =>
      TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: -0.5,
      );

  static TextTheme textTheme(Color ink, Color ink2) {
    final base = Typography.material2021()
        .englishLike
        .merge(Typography.material2021().black)
        .apply(fontFamily: bodyFamily);

    return base
        .copyWith(
          displaySmall: _display(34, 38 / 34, FontWeight.w800),
          headlineMedium: _display(28, 32 / 28, FontWeight.w800),
          headlineSmall: _display(24, 28 / 24, FontWeight.w800),
          titleLarge: _display(22, 26 / 22, FontWeight.w800),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 24 / 16),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 20 / 14),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.66,
          ),
        )
        .apply(bodyColor: ink, displayColor: ink);
  }

  /// Big place name on a swipe card, always white on a photo.
  static TextStyle cardTitle() => const TextStyle(
        fontFamily: displayFamily,
        fontSize: 28,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: Colors.white,
      );

  /// Answer line of a prompt tile.
  static TextStyle prompt(Color color) => TextStyle(
        fontFamily: displayFamily,
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: color,
      );

  /// LIKE / NOPE stamp.
  static TextStyle stamp(Color color) => TextStyle(
        fontFamily: displayFamily,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
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
        fontWeight: FontWeight.w800,
        letterSpacing: -0.04 * size,
        color: color,
      );
}
