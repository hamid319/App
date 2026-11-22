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
    required this.sheet,
    required this.darkTabs,
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

  /// Tint of links, icons and selection: forest green, readable as text on white.
  /// Filled buttons and progress use [BrandColors.orange] instead (see the
  /// theme); orange is too light to carry text on white.
  final Color primary, primarySoft;

  /// Swipe outcomes. Used for like/nope only, never as general accents.
  final Color like, nope;

  /// Super-like, undo and ratings.
  final Color gold;

  /// Errors and destructive actions (nope is ink, so it cannot be the error).
  final Color danger;

  /// Pastel chip fills, picked by category; text on them is always [ink].
  final Color mint, peach, sky;

  /// Bottom sheet and page-like panel background.
  final Color sheet;

  /// Dark mode (owner's choice): everything stays cream as in light mode,
  /// only the main tab pages get a dark page behind their cards (see
  /// `DarkTabPage`), so nothing ever reads dark on dark.
  final bool darkTabs;

  // Out We Go look: warm sand page and cream cards, forest green
  // for text-like tints and orange for filled actions. Greys stay warm, and
  // secondary text passes WCAG AA on white.
  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF6F1EA),
    surface: Color(0xFFFFFDF7),
    surface2: Color(0xFFF5F1EB),
    ink: Color(0xFF141414),
    ink2: Color(0xFF6B6259),
    ink3: Color(0xFFB3A897),
    line: Color(0xFFEDE8E0),
    edge: Color(0xFFE3DDD4),
    primary: BrandColors.forest,
    primarySoft: Color(0xFFDCEBE3),
    like: BrandColors.heart,
    nope: Color(0xFF1E1A16),
    gold: BrandColors.amber,
    danger: Color(0xFFD70015),
    mint: Color(0xFFDDF3E4),
    peach: Color(0xFFFCE4D2),
    sky: Color(0xFFEEF3C4),
    sheet: Color(0xFFFFFDF7),
    darkTabs: false,
  );

  // Dark mode = the light colours plus dark main tab pages (see [darkTabs]).
  static const dark = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF6F1EA),
    surface: Color(0xFFFFFDF7),
    surface2: Color(0xFFF5F1EB),
    ink: Color(0xFF141414),
    ink2: Color(0xFF6B6259),
    ink3: Color(0xFFB3A897),
    line: Color(0xFFEDE8E0),
    edge: Color(0xFFE3DDD4),
    primary: BrandColors.forest,
    primarySoft: Color(0xFFDCEBE3),
    like: BrandColors.heart,
    nope: Color(0xFF1E1A16),
    gold: BrandColors.amber,
    danger: Color(0xFFD70015),
    mint: Color(0xFFDDF3E4),
    peach: Color(0xFFFCE4D2),
    sky: Color(0xFFEEF3C4),
    sheet: Color(0xFFFFFDF7),
    darkTabs: true,
  );

  /// The dark page behind the main tabs in dark mode, and what sits on it.
  static const tabPage = Color(0xFF141312);
  static const onTabPage = Color(0xFFFBF5EE);
  static const onTabPage2 = Color(0xFFB0A494);

  /// Icon tiles and hairlines straight on the dark tab page.
  static const tabFill = Color(0xFF23211F);
  static const tabLine = Color(0xFF2A2725);
}

/// Fill and text of the small status labels ("dates open", "done"), for a
/// light surface and for the dark tab page.
enum TagTone {
  open(
    Color(0xFFF5F1EB),
    Color(0xFF6B6259),
    Color(0xFF23211F),
    Color(0xFFB0A494),
  ),
  done(Color(0xFFE9F6EE), Color(0xFF1F6B43), Color(0xFF17301F),
      Color(0xFF86DBA8));

  const TagTone(this.fill, this.ink, this.darkFill, this.darkInk);

  final Color fill, ink, darkFill, darkInk;
}

/// Out We Go brand colours: the logo, wordmark, app icon and splash use these
/// directly; screens use the palette above (via the theme), which builds on
/// them.
class BrandColors {
  /// Forest green: the geese, "out" and "go", the tint in light mode.
  static const forest = Color(0xFF0B5A45);

  /// The shaded and the lit side of forest: gradients on green cards, the
  /// suitcase's trim and grooves.
  static const forestDeep = Color(0xFF084434);
  static const forestLight = Color(0xFF14704F);

  /// Mandarin: the dots in the wordmark, the lead goose, highlights.
  static const coral = Color(0xFFFF5A1F);

  /// Mandarin: filled buttons and progress, with ink text on it (white on it
  /// only for large text).
  static const orange = Color(0xFFFF5A1F);

  /// Red: hearts and likes, as people know them from other apps.
  static const heart = Color(0xFFE5484D);

  /// Lime: icon and splash ground, the tint in dark mode.
  static const lime = Color(0xFFE3EE6B);

  /// Amber: ratings.
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
