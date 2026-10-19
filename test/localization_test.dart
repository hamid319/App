import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipetrip/app/locale_controller.dart';
import 'package:swipetrip/core/services/preferences_service.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  group('translations', () {
    test('German has exactly the same keys as English', () {
      final en = _keys(_arb('app_en.arb'));
      final de = _keys(_arb('app_de.arb'));
      expect(en.difference(de), isEmpty, reason: 'missing in app_de.arb');
      expect(de.difference(en), isEmpty, reason: 'unknown in app_de.arb');
    });

    test('no German text is left empty', () {
      final de = _arb('app_de.arb');
      final empty = _keys(de).where((k) => (de[k] as String).trim().isEmpty);
      expect(empty, isEmpty);
    });
  });

  group('resolveAppLocale', () {
    test('uses a supported device language', () {
      expect(resolveAppLocale(const [Locale('de', 'DE')]), const Locale('de'));
      expect(resolveAppLocale(const [Locale('en', 'US')]), const Locale('en'));
    });

    test('picks the first supported language in the device list', () {
      expect(
        resolveAppLocale(const [Locale('fr'), Locale('de'), Locale('en')]),
        const Locale('de'),
      );
    });

    test('falls back to English, not to the first generated locale', () {
      expect(resolveAppLocale(const [Locale('fr')]), const Locale('en'));
      expect(resolveAppLocale(null), const Locale('en'));
    });
  });

  group('LocaleController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('follows the device until the user picks a language', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(localeControllerProvider), isNull);

      await container
          .read(localeControllerProvider.notifier)
          .setLanguage('de');
      expect(container.read(localeControllerProvider), const Locale('de'));
      expect(await PreferencesService.getLanguageCode(), 'de');
    });

    test('restores the saved language on start', () async {
      SharedPreferences.setMockInitialValues({'language_code': 'de'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(localeControllerProvider), const Locale('de'));
    });

    test('choosing "system default" clears the saved language', () async {
      SharedPreferences.setMockInitialValues({'language_code': 'de'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(localeControllerProvider.notifier).setLanguage(null);
      expect(container.read(localeControllerProvider), isNull);
      expect(await PreferencesService.getLanguageCode(), isNull);
    });
  });
}
