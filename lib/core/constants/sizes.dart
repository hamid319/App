/// Spacing, radii and motion tokens. Spacing follows a 4 px grid.
class AppSizes {
  // Spacing
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  /// Distance from the screen edge to content.
  static const double screenEdge = 16;

  /// Inset of the swipe card inside its area.
  static const double cardInset = 12;

  /// Gap between unrelated groups of content.
  static const double groupGap = 24;

  // Radii
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusCard = 28;

  // Motion
  static const Duration snapBack = Duration(milliseconds: 320);
  static const Duration cardOut = Duration(milliseconds: 260);
  static const Duration nextCardUp = Duration(milliseconds: 220);

  /// Scale of the card waiting behind the current one.
  static const double backCardScale = 0.94;
}
