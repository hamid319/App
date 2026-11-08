import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyOnboardingShown = 'onboarding_shown';
  static const String _keyGuestFavoriteHintShown = 'guest_favorite_hint_shown';
  static const String _keyLanguageCode = 'language_code';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyDiscoverPreferences = 'discover_preferences';
  static const String _keyPushEnabled = 'push_enabled';

  /// Trip push notifications on this device; on unless turned off.
  static Future<bool> isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPushEnabled) ?? true;
  }

  static Future<void> setPushEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushEnabled, enabled);
  }

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

  /// The user's home city (a PopularCity id), only stored on this device.
  static Future<String?> getHomeCityId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('home_city_id');
  }

  static Future<void> setHomeCityId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove('home_city_id');
    } else {
      await prefs.setString('home_city_id', id);
    }
  }

  /// When the home tip banner may show again (after a tip or "not now").
  static Future<DateTime?> getCityTipBannerPausedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('city_tip_paused_until');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> setCityTipBannerPausedUntil(DateTime until) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('city_tip_paused_until', until.millisecondsSinceEpoch);
  }
}
