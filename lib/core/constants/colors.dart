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

  // Apple HIG grouped look: grey page, white inset groups, one tint.
  // Secondary text is a little darker than iOS's own grey so it passes
  // WCAG AA on both the page and the cards.
  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE5E5EA),
    ink: Color(0xFF000000),
    ink2: Color(0xFF6E6E73),
    ink3: Color(0xFFAEAEB2),
    line: Color(0xFFD1D1D6),
    edge: Color(0xFFD1D1D6),
    primary: Color(0xFFC2410C),
    primarySoft: Color(0xFFFFEDD5),
    like: Color(0xFFC2410C),
    nope: Color(0xFF1C1C1E),
    gold: Color(0xFFFFCC00),
    danger: Color(0xFFD70015),
    mint: Color(0xFFD1FAE5),
    peach: Color(0xFFFFEDD5),
    sky: Color(0xFFDBEAFE),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surface2: Color(0xFF2C2C2E),
    ink: Color(0xFFFFFFFF),
    ink2: Color(0xFF98989F),
    ink3: Color(0xFF636366),
    line: Color(0xFF38383A),
    edge: Color(0xFF38383A),
    primary: Color(0xFFFF7A45),
    primarySoft: Color(0xFF3D1F12),
    like: Color(0xFFFF7A45),
    nope: Color(0xFFFFFFFF),
    gold: Color(0xFFFFD60A),
    danger: Color(0xFFFF6961),
    mint: Color(0xFF0F2E22),
    peach: Color(0xFF3D1F12),
    sky: Color(0xFF0F2440),
  );
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
