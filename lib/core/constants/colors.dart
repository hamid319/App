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
    required this.primary,
    required this.primarySoft,
    required this.like,
    required this.nope,
    required this.gold,
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

  /// Hairlines and borders.
  final Color line;

  /// "Sunset" brand orange: the one accent per screen.
  final Color primary, primarySoft;

  /// Swipe outcomes. Used for like/nope only, never as general accents.
  final Color like, nope;

  /// Secondary actions such as undo, and ratings.
  final Color gold;

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF0F3),
    ink: Color(0xFF15171C),
    ink2: Color(0xFF5B616E),
    ink3: Color(0xFF9097A3),
    line: Color(0xFFE7E9EE),
    primary: Color(0xFFFF5A36),
    primarySoft: Color(0xFFFFECE6),
    like: Color(0xFF12B886),
    nope: Color(0xFFF03E5A),
    gold: Color(0xFFF5A524),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0E0F12),
    surface: Color(0xFF17191E),
    surface2: Color(0xFF20232A),
    ink: Color(0xFFF2F3F5),
    ink2: Color(0xFFA9AFBB),
    ink3: Color(0xFF6B7280),
    line: Color(0xFF2A2E37),
    primary: Color(0xFFFF6B4A),
    primarySoft: Color(0xFF3A1E17),
    like: Color(0xFF2BD4A4),
    nope: Color(0xFFFF5C74),
    gold: Color(0xFFF7B955),
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
