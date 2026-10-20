import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/preferences_service.dart';

/// Light, dark, or following the device (the default). Persisted locally.
final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  bool _userChose = false;

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final stored = await PreferencesService.getThemeMode();
      // A choice made while this was loading wins over the stored one.
      if (_userChose) return;
      state = _fromName(stored);
    } catch (e) {
      debugPrint('Could not restore theme mode: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _userChose = true;
    state = mode;
    await PreferencesService.setThemeMode(
      mode == ThemeMode.system ? null : mode.name,
    );
  }

  static ThemeMode _fromName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
