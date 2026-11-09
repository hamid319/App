import 'package:flutter/material.dart';

/// Raw colour tokens of the SwipeTrip design system. Widgets should not use
/// these directly: read `Theme.of(context).colorScheme` or the
/// `SwipeColors` theme extension instead, so light and dark both work.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.edge,
    required this.primary,
    required this.primarySoft,
    required this.like,
    required this.nope,
    required this.gold,
    required this.danger,
    required this.mint,
    required this.peach,
    required this.sky,
  });

  final Brightness brightness;

  /// Page background, behind cards and sheets.
  final Color bg;

  /// Cards, sheets, bars.
  final Color surface;

  /// Chips, inputs, subtle fills.
  final Color surface2;

  /// Primary, secondary and tertiary text.
  final Color ink, ink2, ink3;

  /// Hairlines and dividers.
  final Color line;

  /// Hairline around controls that need one (text fields, outlined chips).
  final Color edge;

  /// Tint: the one accent per screen (buttons, links, selection).
  final Color primary, primarySoft;

  /// Swipe outcomes. Used for like/nope only, never as general accents.
  final Color like, nope;

  /// Super-like, undo and ratings.
  final Color gold;

  /// Errors and destructive actions (nope is ink, so it cannot be the error).
  final Color danger;

  /// Pastel chip fills, picked by category; text on them is always [ink].
  final Color mint, peach, sky;

  // Grouped look on warm sand: cream cards on a sand page, one tint
  // (TripFam navy; sky in dark mode, where navy would vanish). Greys are
  // warm too, and secondary text passes WCAG AA on the page and the cards.
  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF8F3EC),
    surface: Color(0xFFFFFDF9),
    surface2: Color(0xFFEFE6DA),
    ink: Color(0xFF1E1A16),
    ink2: Color(0xFF736759),
    ink3: Color(0xFFB3A897),
    line: Color(0xFFE3D8CA),
    edge: Color(0xFFD9CCBC),
    primary: BrandColors.navy,
    primarySoft: Color(0xFFF6E3D6),
    like: BrandColors.coral,
    nope: Color(0xFF1E1A16),
    gold: BrandColors.amber,
    danger: Color(0xFFD70015),
    mint: Color(0xFFDDF3E4),
    peach: Color(0xFFFCE4D2),
    sky: Color(0xFFDCE6F7),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF14110F),
    surface: Color(0xFF221D19),
    surface2: Color(0xFF2F2823),
    ink: Color(0xFFFBF5EE),
    ink2: Color(0xFFA39787),
    ink3: Color(0xFF6B6157),
    line: Color(0xFF3A322B),
    edge: Color(0xFF3A322B),
    primary: BrandColors.sky,
    primarySoft: Color(0xFF2A2C45),
    like: Color(0xFFFF8A78),
    nope: Color(0xFFFBF5EE),
    gold: Color(0xFFFFD166),
    danger: Color(0xFFFF6961),
    mint: Color(0xFF15302A),
    peach: Color(0xFF3D2620),
    sky: Color(0xFF1A2640),
  );
}

/// TripFam brand colours: the logo, wordmark, app icon and splash use these
/// directly; screens use the palette above (via the theme), which builds on
/// them.
class BrandColors {
  /// Midnight navy: suitcase, "trip", the tint in light mode.
  static const navy = Color(0xFF1F2A6B);

  /// Coral: "fam", the heart sticker, likes and highlights.
  static const coral = Color(0xFFFF6F59);

  /// Sky: icon and splash ground, the tint in dark mode.
  static const sky = Color(0xFFA9C7FF);

  /// Amber: the pin sticker, ratings.
  static const amber = Color(0xFFFFC857);
}

/// Colours that sit on top of photos and look the same in light and dark.
class PhotoColors {
  /// Dark glass behind tag chips on a photo.
  static const chip = Color(0x6B0C0E12);
  static const chipBorder = Color(0x47FFFFFF);

  /// Bottom scrim that keeps white text readable on any photo.
  static const scrimTop = Color(0x2E000000);
  static const scrimBottom = Color(0xE6080A0E);

  /// Buttons floating on a photo.
  static const glass = Color(0xEBFFFFFF);
  static const onGlass = Color(0xFF15171C);
}

/// Identity colours for member avatars: the same person always gets the
/// same colour. White initials stay readable on all of them in both modes.
class AvatarColors {
  static const _palette = [
    Color(0xFF6E56CF),
    Color(0xFF0E9F7E),
    Color(0xFFD9822B),
    Color(0xFF3B6FD6),
    Color(0xFFD6336C),
    Color(0xFFE24A28),
  ];

  static Color forId(String id) =>
      _palette[id.codeUnits.fold(0, (a, c) => a + c) % _palette.length];
}
