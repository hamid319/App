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

  /// The ticket outline: the strong border around tickets, buttons and
  /// stamps that gives the "Ticket und Stempel" look its print feel.
  final Color edge;

  /// "Sunset" brand orange: the one accent per screen.
  final Color primary, primarySoft;

  /// Swipe outcomes. Used for like/nope only, never as general accents.
  final Color like, nope;

  /// Super-like, undo and ratings.
  final Color gold;

  /// Errors and destructive actions (nope is ink, so it cannot be the error).
  final Color danger;

  /// Pastel chip fills, picked by category; text on them is always [ink].
  final Color mint, peach, sky;

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFFF7EC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF7EBDA),
    ink: Color(0xFF221A14),
    ink2: Color(0xFF6B5D50),
    ink3: Color(0xFFA3958A),
    line: Color(0xFFEADCC8),
    edge: Color(0xFF221A14),
    primary: Color(0xFFFF5A36),
    primarySoft: Color(0xFFFFE3D9),
    like: Color(0xFFFF5A36),
    nope: Color(0xFF221A14),
    gold: Color(0xFFFFC93C),
    danger: Color(0xFFD7263D),
    mint: Color(0xFFDDF2D1),
    peach: Color(0xFFFFE3D9),
    sky: Color(0xFFDCEBFA),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF17120E),
    surface: Color(0xFF221B15),
    surface2: Color(0xFF2E251E),
    ink: Color(0xFFFFF3E4),
    ink2: Color(0xFFC9B8A6),
    ink3: Color(0xFF8C7B6B),
    line: Color(0xFF3A3027),
    edge: Color(0xFFE9D9C6),
    primary: Color(0xFFFF6A47),
    primarySoft: Color(0xFF45241A),
    like: Color(0xFFFF6A47),
    nope: Color(0xFFFFF3E4),
    gold: Color(0xFFFFCF52),
    danger: Color(0xFFFF5D6E),
    mint: Color(0xFF243A22),
    peach: Color(0xFF45241A),
    sky: Color(0xFF1E3044),
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
