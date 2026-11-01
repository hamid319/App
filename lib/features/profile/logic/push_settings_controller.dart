import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/preferences_service.dart';
import '../../../main_providers.dart';

/// The settings switch for trip push notifications on this device.
class PushSettingsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => PreferencesService.isPushEnabled();

  Future<void> setEnabled(bool enabled, {required String languageCode}) async {
    state = AsyncData(enabled);
    await PreferencesService.setPushEnabled(enabled);
    final push = ref.read(pushServiceProvider);
    final account = ref.read(currentAccountProvider).value;
    if (!enabled) return push.unregister();
    if (account == null || account.isGuest) return;
    try {
      await push.register(account.uid, languageCode);
    } catch (e) {
      debugPrint('Push registration: $e');
    }
  }
}

final pushSettingsControllerProvider =
    AsyncNotifierProvider<PushSettingsController, bool>(
        PushSettingsController.new);
