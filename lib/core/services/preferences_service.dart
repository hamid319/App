import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyOnboardingShown = 'onboarding_shown';
  static const String _keyGuestFavoriteHintShown = 'guest_favorite_hint_shown';
  static const String _keyLanguageCode = 'language_code';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyDiscoverPreferences = 'discover_preferences';

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

  /// 'light', 'dark', or null to follow the device.
  static Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode);
  }

  static Future<void> setThemeMode(String? mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == null) {
      await prefs.remove(_keyThemeMode);
    } else {
      await prefs.setString(_keyThemeMode, mode);
    }
  }

  /// Discover filters (place, interests, radius) as a JSON string.
  static Future<String?> getDiscoverPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDiscoverPreferences);
  }

  static Future<void> setDiscoverPreferences(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDiscoverPreferences, json);
  }

  /// Passport stamps (city ids) whose stamping animation [uid] has seen.
  static Future<Set<String>> getSeenStamps(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('passport_seen_$uid') ?? const []).toSet();
  }

  static Future<void> setSeenStamps(String uid, Set<String> cityIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('passport_seen_$uid', cityIds.toList());
  }
}
