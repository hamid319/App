import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
import '../core/constants/sizes.dart';
import '../core/constants/typography.dart';

/// Swipe and ticket colours that Material's ColorScheme has no slot for.
/// Read with `Theme.of(context).extension<SwipeColors>()!` or the
/// `context.swipeColors` shortcut below, never with `Colors.green`.
@immutable
class SwipeColors extends ThemeExtension<SwipeColors> {
  const SwipeColors({
    required this.like,
    required this.nope,
    required this.gold,
    required this.edge,
    required this.mint,
    required this.peach,
    required this.sky,
  });

  final Color like;
  final Color nope;
  final Color gold;

  /// Ink outline of tickets, buttons and stamps.
  final Color edge;

  /// Pastel chip fills; text on them uses `colorScheme.onSurface`.
  final Color mint, peach, sky;

  @override
  SwipeColors copyWith({
    Color? like,
    Color? nope,
    Color? gold,
    Color? edge,
    Color? mint,
    Color? peach,
    Color? sky,
  }) =>
      SwipeColors(
        like: like ?? this.like,
        nope: nope ?? this.nope,
        gold: gold ?? this.gold,
        edge: edge ?? this.edge,
        mint: mint ?? this.mint,
        peach: peach ?? this.peach,
        sky: sky ?? this.sky,
      );

  @override
  SwipeColors lerp(ThemeExtension<SwipeColors>? other, double t) {
    if (other is! SwipeColors) return this;
    return SwipeColors(
      like: Color.lerp(like, other.like, t)!,
      nope: Color.lerp(nope, other.nope, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      edge: Color.lerp(edge, other.edge, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      peach: Color.lerp(peach, other.peach, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
    );
  }
}

extension SwipeColorsContext on BuildContext {
  SwipeColors get swipeColors => Theme.of(this).extension<SwipeColors>()!;
}

class AppTheme {
  static final ThemeData light = _build(AppPalette.light);
  static final ThemeData dark = _build(AppPalette.dark);

  /// One builder for both modes, so light and dark cannot drift apart.
  ///
  /// "Ticket und Stempel": cream paper, ink outlines, one orange accent per
  /// screen. Primary buttons are orange with an ink rim, secondary buttons
  /// are ink outlines, selected states are filled with ink.
  static ThemeData _build(AppPalette p) {
    // Ink text on orange reads far better than white (WCAG AA).
    final onPrimary = p.brightness == Brightness.light ? p.ink : p.bg;
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: onPrimary,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.ink,
      secondary: p.ink,
      onSecondary: p.bg,
      // Selected states (NavigationBar pill, SegmentedButton) are ink.
      secondaryContainer: p.ink,
      onSecondaryContainer: p.bg,
      tertiary: p.gold,
      onTertiary: AppPalette.light.ink,
      error: p.danger,
      onError: Colors.white,
      errorContainer: Color.alphaBlend(
        p.danger.withValues(alpha: 0.14),
        p.surface,
      ),
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.ink2,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.bg,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface2,
      surfaceContainerHighest: p.surface2,
      outline: p.edge,
      outlineVariant: p.line,
      inverseSurface: p.ink,
      onInverseSurface: p.bg,
    );
    final textTheme = AppTypography.textTheme(p.ink, p.ink2);
    const stadium = StadiumBorder();
    final edge = BorderSide(color: p.edge, width: AppSizes.edge);
    const buttonText = TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );
    OutlineInputBorder field(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        titleTextStyle: textTheme.headlineSmall,
      ),
      // One back arrow everywhere (iOS showed "<" on some screens).
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(Icons.arrow_back_rounded),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: StadiumBorder(side: edge),
          elevation: 0,
          backgroundColor: p.primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: p.surface2,
          disabledForegroundColor: p.ink3,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: stadium,
          backgroundColor: p.ink,
          foregroundColor: p.bg,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: stadium,
          foregroundColor: p.ink,
          side: edge,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.ink,
          textStyle: buttonText.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.ink),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: StadiumBorder(side: edge),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusTicket),
          side: edge,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.ink,
        textColor: p.ink,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: p.ink2),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: p.edge)),
        side: BorderSide(color: p.edge),
        backgroundColor: p.surface,
        selectedColor: p.ink,
        checkmarkColor: p.bg,
        labelStyle: textTheme.labelLarge?.copyWith(color: p.ink),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: p.bg),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: edge,
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(p.bg),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(p.ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.bg : p.ink2,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : p.surface2,
        ),
        trackOutlineColor: WidgetStatePropertyAll(p.edge),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          side: edge,
          foregroundColor: p.ink,
          selectedForegroundColor: p.bg,
          selectedBackgroundColor: p.ink,
          textStyle: textTheme.labelLarge,
          visualDensity: VisualDensity.compact,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surface2,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.ink,
        inactiveTrackColor: p.surface2,
        thumbColor: p.primary,
        overlayColor: p.primary.withValues(alpha: 0.12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: field(p.edge, AppSizes.edge),
        enabledBorder: field(p.edge, AppSizes.edge),
        focusedBorder: field(p.primary, 2),
        errorBorder: field(p.danger, AppSizes.edge),
        focusedErrorBorder: field(p.danger, 2),
        labelStyle: TextStyle(color: p.ink2),
        hintStyle: TextStyle(color: p.ink3),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.ink,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.bg : p.ink2,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? p.ink : p.ink2,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.bg,
        selectedItemColor: p.ink,
        unselectedItemColor: p.ink2,
        elevation: 0,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: p.primary,
        textColor: onPrimary,
      ),
      dividerTheme: DividerThemeData(color: p.line, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.bg),
        actionTextColor: p.gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.ink3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusLg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          side: edge,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          side: edge,
        ),
      ),
      extensions: [
        SwipeColors(
          like: p.like,
          nope: p.nope,
          gold: p.gold,
          edge: p.edge,
          mint: p.mint,
          peach: p.peach,
          sky: p.sky,
        ),
      ],
    );
  }
}
