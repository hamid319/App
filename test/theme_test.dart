import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipetrip/app/theme_mode_controller.dart';
import 'package:swipetrip/core/constants/colors.dart';
import 'package:swipetrip/core/services/preferences_service.dart';

void main() {
  group('ThemeModeController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('follows the device by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
    });

    test('saves an explicit choice and clears it for "system"', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(themeModeControllerProvider.notifier);

      await ctrl.setThemeMode(ThemeMode.dark);
      expect(container.read(themeModeControllerProvider), ThemeMode.dark);
      expect(await PreferencesService.getThemeMode(), 'dark');

      await ctrl.setThemeMode(ThemeMode.system);
      expect(await PreferencesService.getThemeMode(), isNull);
    });

    test('restores the saved mode on start', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeControllerProvider), ThemeMode.light);
    });
  });

  group('palette', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final (name, p) in [
      ('light', AppPalette.light),
      ('dark', AppPalette.dark),
    ]) {
      test('$name text meets WCAG AA contrast on its surfaces', () {
        expect(contrast(p.ink, p.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.ink, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.ink2, p.surface), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
