import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bricolage Grotesque for titles, Figtree for everything else.
/// Fonts load through google_fonts; they can be bundled as assets later so
/// the app does not need a network connection for them.
class AppTypography {
  static TextTheme textTheme(Color ink, Color ink2) {
    final body = GoogleFonts.figtreeTextTheme();
    TextStyle display(double size, double height, FontWeight weight) =>
        GoogleFonts.bricolageGrotesque(
          fontSize: size,
          height: height,
          fontWeight: weight,
          letterSpacing: -0.5,
        );

    return body
        .copyWith(
          displaySmall: display(34, 38 / 34, FontWeight.w800),
          headlineMedium: display(28, 32 / 28, FontWeight.w800),
          headlineSmall: display(24, 28 / 24, FontWeight.w800),
          titleLarge: display(22, 26 / 22, FontWeight.w800),
          titleMedium: body.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 24 / 16),
          bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 20 / 14),
          labelLarge: body.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: body.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.66,
          ),
        )
        .apply(bodyColor: ink, displayColor: ink);
  }

  /// Big place name on a swipe card, always white on a photo.
  static TextStyle cardTitle() => GoogleFonts.bricolageGrotesque(
        fontSize: 28,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: Colors.white,
      );

  /// LIKE / NOPE stamp.
  static TextStyle stamp(Color color) => GoogleFonts.bricolageGrotesque(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: color,
      );
}
