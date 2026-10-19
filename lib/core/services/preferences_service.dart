import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyOnboardingShown = 'onboarding_shown';
  static const String _keyGuestFavoriteHintShown = 'guest_favorite_hint_shown';
  static const String _keyLanguageCode = 'language_code';

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingShown) ?? false;
  }

  static Future<void> setOnboardingShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingShown, true);
  }

  static Future<bool> hasSeenGuestFavoriteHint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGuestFavoriteHintShown) ?? false;
  }

  static Future<void> setGuestFavoriteHintShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGuestFavoriteHintShown, true);
  }

  /// The language the user picked in the app, or null to follow the device.
  static Future<String?> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguageCode);
  }

  static Future<void> setLanguageCode(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_keyLanguageCode);
    } else {
      await prefs.setString(_keyLanguageCode, code);
    }
  }
}
