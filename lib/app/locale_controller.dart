import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/preferences_service.dart';

/// Language codes the app ships translations for. English is the fallback.
const supportedLanguageCodes = ['en', 'de'];
const fallbackLanguageCode = 'en';

/// The language the user picked in the app, or null to follow the device.
final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  bool _userChose = false;

  @override
  Locale? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    try {
      final code = await PreferencesService.getLanguageCode();
      // A choice made while this was loading wins over the stored one.
      if (_userChose) return;
      if (code != null && supportedLanguageCodes.contains(code)) {
        state = Locale(code);
      }
    } catch (e) {
      debugPrint('Could not restore language: $e');
    }
  }

  /// [code] is a supported language code, or null for the device language.
  Future<void> setLanguage(String? code) async {
    _userChose = true;
    state = code == null ? null : Locale(code);
    await PreferencesService.setLanguageCode(code);
  }
}

/// Picks the first device language the app supports, else English.
/// Flutter's default would fall back to the first supported locale, which is
/// German because the generated list is sorted alphabetically.
Locale resolveAppLocale(List<Locale>? deviceLocales) {
  for (final locale in deviceLocales ?? const <Locale>[]) {
    if (supportedLanguageCodes.contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
  }
  return const Locale(fallbackLanguageCode);
}
