import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    required this.sheet,
    required this.darkTabs,
  });

  final Color like;
  final Color nope;
  final Color gold;

  /// Hairline for controls that need an outline.
  final Color edge;

  /// Pastel chip fills; text on them uses `colorScheme.onSurface`.
  final Color mint, peach, sky;

  /// Sheets and page-like panels. Unlike `scaffoldBackgroundColor` it is
  /// never dark, also when a sheet opens from a [DarkTabPage].
  final Color sheet;

  /// See [AppPalette.darkTabs].
  final bool darkTabs;

  @override
  SwipeColors copyWith({
    Color? like,
    Color? nope,
    Color? gold,
    Color? edge,
    Color? mint,
    Color? peach,
    Color? sky,
    Color? sheet,
    bool? darkTabs,
  }) =>
      SwipeColors(
        like: like ?? this.like,
        nope: nope ?? this.nope,
        gold: gold ?? this.gold,
        edge: edge ?? this.edge,
        mint: mint ?? this.mint,
        peach: peach ?? this.peach,
        sky: sky ?? this.sky,
        sheet: sheet ?? this.sheet,
        darkTabs: darkTabs ?? this.darkTabs,
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
      sheet: Color.lerp(sheet, other.sheet, t)!,
      darkTabs: t < 0.5 ? darkTabs : other.darkTabs,
    );
  }
}

extension SwipeColorsContext on BuildContext {
  SwipeColors get swipeColors => Theme.of(this).extension<SwipeColors>()!;

  bool get _onDarkTab =>
      (Theme.of(this).extension<SwipeColors>()?.darkTabs ?? false) &&
      dependOnInheritedWidgetOfExactType<_DarkTabMarker>() != null;

  /// Text straight on the page (titles, section headers), not on a card.
  Color get onBg =>
      _onDarkTab ? AppPalette.onTabPage : Theme.of(this).colorScheme.onSurface;

  /// Secondary text straight on the page.
  Color get onBg2 => _onDarkTab
      ? AppPalette.onTabPage2
      : Theme.of(this).colorScheme.onSurfaceVariant;

  /// Whether this is a main tab page in dark mode (dark page behind it).
  bool get isDarkTabPage => _onDarkTab;

  /// Subtle fill (icon tiles) and hairlines straight on the page.
  Color get pageFill => _onDarkTab
      ? AppPalette.tabFill
      : Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get pageLine => _onDarkTab
      ? AppPalette.tabLine
      : Theme.of(this).colorScheme.outlineVariant;

  /// Links and icons straight on the page.
  Color get pageTint =>
      _onDarkTab ? BrandColors.lime : Theme.of(this).colorScheme.primary;
}

/// A main tab page (trips, discover, profile, settings). In dark mode its
/// page goes dark behind the cream cards; text on the page then reads
/// [SwipeColorsContext.onBg]. Sheets opened from it stay cream: they take
/// `swipeColors.sheet`, and the marker below is not passed on to them.
class DarkTabPage extends StatelessWidget {
  const DarkTabPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!context.swipeColors.darkTabs) return child;
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: AppPalette.tabPage,
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: AppPalette.tabPage,
          foregroundColor: AppPalette.onTabPage,
          titleTextStyle: theme.appBarTheme.titleTextStyle
              ?.copyWith(color: AppPalette.onTabPage),
          iconTheme: const IconThemeData(color: BrandColors.lime),
          actionsIconTheme: const IconThemeData(color: BrandColors.lime),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: _DarkTabMarker(child: child),
      ),
    );
  }
}

class _DarkTabMarker extends InheritedWidget {
  const _DarkTabMarker({required super.child});

  @override
  bool updateShouldNotify(_DarkTabMarker oldWidget) => false;
}

class AppTheme {
  static final ThemeData light = _build(AppPalette.light);
  static final ThemeData dark = _build(AppPalette.dark);

  /// One builder for both modes, so light and dark cannot drift apart.
  ///
  /// Apple HIG look: grey grouped page, white inset groups without borders,
  /// system font, one tint. Primary buttons are filled tint pills, secondary
  /// buttons are grey fills, selected states use the tint or ink.
  static ThemeData _build(AppPalette p) {
    final onPrimary =
        ThemeData.estimateBrightnessForColor(p.primary) == Brightness.dark
            ? Colors.white
            : Colors.black;
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: onPrimary,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.ink,
      secondary: p.ink,
      onSecondary: p.bg,
      secondaryContainer: p.primarySoft,
      onSecondaryContainer: p.ink,
      tertiary: p.gold,
      onTertiary: p.ink,
      error: p.danger,
      onError: Colors.white,
      errorContainer: Color.alphaBlend(
        p.danger.withValues(alpha: 0.12),
        p.surface,
      ),
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.ink2,
      surfaceContainerLowest: p.sheet,
      surfaceContainerLow: p.sheet,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface2,
      surfaceContainerHighest: p.surface2,
      outline: p.ink3,
      outlineVariant: p.line,
      inverseSurface: p.ink,
      onInverseSurface: p.bg,
      shadow: Colors.black,
    );
    final textTheme = AppTypography.textTheme(p.ink, p.ink2);
    // Filled actions: warm orange with ink on it (white on it is too weak).
    const accent = BrandColors.orange;
    const stadium = StadiumBorder();
    const buttonText = TextStyle(fontWeight: FontWeight.w600, fontSize: 17);
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
      // iOS has no ink ripples; a quick highlight reads more native.
      splashFactory: NoSplash.splashFactory,
      highlightColor: p.ink.withValues(alpha: 0.06),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: IconThemeData(color: p.primary),
        actionsIconTheme: IconThemeData(color: p.primary),
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 54),
          shape: stadium,
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: p.ink,
          disabledBackgroundColor: p.surface2,
          disabledForegroundColor: p.ink3,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: stadium,
          backgroundColor: accent,
          foregroundColor: p.ink,
          textStyle: buttonText,
        ),
      ),
      // Secondary buttons: grey fill, no outline (iOS "gray" button style).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: stadium,
          backgroundColor: p.surface2,
          foregroundColor: p.ink,
          side: BorderSide.none,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: p.ink,
        elevation: 2,
        highlightElevation: 2,
        shape: const StadiumBorder(),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.primary,
        textColor: p.ink,
        tileColor: p.surface,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: p.ink2),
        minVerticalPadding: 10,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: p.surface2,
        // Tinted selection: readable for FilterChip and ChoiceChip alike.
        selectedColor: p.primarySoft,
        checkmarkColor: p.primary,
        labelStyle: textTheme.labelLarge?.copyWith(color: p.ink),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: p.ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: p.ink3, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? p.primary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(p.primary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFF34C759)
              : p.surface2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          side: BorderSide.none,
          backgroundColor: p.surface2,
          foregroundColor: p.ink,
          selectedForegroundColor: p.ink,
          selectedBackgroundColor: p.surface,
          textStyle: textTheme.labelLarge,
          visualDensity: VisualDensity.compact,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: p.surface2,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: p.surface2,
        thumbColor: Colors.white,
        overlayColor: p.primary.withValues(alpha: 0.12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: field(p.line, 1),
        enabledBorder: field(p.line, 1),
        focusedBorder: field(p.primary, 1.5),
        errorBorder: field(p.danger, 1),
        focusedErrorBorder: field(p.danger, 1.5),
        labelStyle: TextStyle(color: p.ink2),
        hintStyle: TextStyle(color: p.ink3),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        // No pill: the selected tab is told by its tint and weight.
        indicatorColor: Colors.transparent,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.primary : p.ink2,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? p.primary : p.ink2,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.ink2,
        elevation: 0,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: p.danger,
        textColor: Colors.white,
      ),
      dividerTheme: DividerThemeData(color: p.line, space: 0.5, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: BrandColors.lime,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.sheet,
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
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
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
          sheet: p.sheet,
          darkTabs: p.darkTabs,
        ),
      ],
    );
  }
}
