import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
import '../core/constants/sizes.dart';
import '../core/constants/typography.dart';

/// Swipe-specific colours that Material's ColorScheme has no slot for.
/// Read with `Theme.of(context).extension<SwipeColors>()!` or the
/// `context.swipeColors` shortcut below, never with `Colors.green`.
@immutable
class SwipeColors extends ThemeExtension<SwipeColors> {
  const SwipeColors({
    required this.like,
    required this.nope,
    required this.gold,
  });

  final Color like;
  final Color nope;
  final Color gold;

  @override
  SwipeColors copyWith({Color? like, Color? nope, Color? gold}) => SwipeColors(
        like: like ?? this.like,
        nope: nope ?? this.nope,
        gold: gold ?? this.gold,
      );

  @override
  SwipeColors lerp(ThemeExtension<SwipeColors>? other, double t) {
    if (other is! SwipeColors) return this;
    return SwipeColors(
      like: Color.lerp(like, other.like, t)!,
      nope: Color.lerp(nope, other.nope, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
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
  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: Colors.white,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.primary,
      secondary: p.like,
      onSecondary: Colors.white,
      // Selected states (NavigationBar pill, SegmentedButton) use these.
      secondaryContainer: p.primarySoft,
      onSecondaryContainer: p.primary,
      error: p.nope,
      onError: Colors.white,
      errorContainer: Color.alphaBlend(
        p.nope.withValues(alpha: 0.14),
        p.surface,
      ),
      onErrorContainer: p.nope,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.ink2,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.bg,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface2,
      surfaceContainerHighest: p.surface2,
      outline: p.ink3,
      outlineVariant: p.line,
    );
    final textTheme = AppTypography.textTheme(p.ink, p.ink2);
    const stadium = StadiumBorder();
    const buttonText = TextStyle(fontWeight: FontWeight.w700, fontSize: 15);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        titleTextStyle: textTheme.headlineSmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: stadium,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: stadium,
          elevation: 0,
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: stadium,
          foregroundColor: p.ink,
          side: BorderSide(color: p.line, width: 1.5),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.ink,
          textStyle: buttonText.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          side: BorderSide(color: p.line),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: stadium,
        backgroundColor: p.surface2,
        side: BorderSide.none,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primarySoft,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.primary : p.ink3,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? p.ink : p.ink3,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.ink3,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: p.line, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusLg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),
      extensions: [
        SwipeColors(like: p.like, nope: p.nope, gold: p.gold),
      ],
    );
  }
}
