import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/preferences_service.dart';
import '../../../main_providers.dart';
import '../data/city_tip_repository.dart';

/// After a tip the banner rests this long; after "not now" a bit less.
const cityTipPauseAfterTip = Duration(days: 30);
const cityTipPauseAfterDismiss = Duration(days: 7);

final cityTipRepositoryProvider =
    Provider<CityTipRepository>((ref) => CityTipRepository());

/// Whether the "know a hidden gem in your city?" banner shows on the home
/// screen: only for real accounts (the rules need one), and not while it
/// is paused. The pause is stored on the device, so it costs no reads.
final cityTipBannerProvider = NotifierProvider<CityTipBannerController, bool>(
    CityTipBannerController.new);

/// Shown when nothing paused it, or the pause is over.
bool cityTipBannerDue(DateTime? pausedUntil, DateTime now) =>
    pausedUntil == null || !now.isBefore(pausedUntil);

class CityTipBannerController extends Notifier<bool> {
  @override
  bool build() {
    final account = ref.watch(currentAccountProvider).value;
    if (account == null || account.isGuest) return false;
    _restore();
    return false;
  }

  Future<void> _restore() async {
    try {
      final until = await PreferencesService.getCityTipBannerPausedUntil();
      state = cityTipBannerDue(until, DateTime.now());
    } catch (e) {
      debugPrint('Could not read the tip banner pause: $e');
    }
  }

  Future<void> _pause(Duration duration) async {
    state = false;
    await PreferencesService.setCityTipBannerPausedUntil(
        DateTime.now().add(duration));
  }

  /// "Not now".
  Future<void> dismiss() => _pause(cityTipPauseAfterDismiss);

  /// Saves the tip, then rests the banner for [cityTipPauseAfterTip].
  Future<void> submit({
    required String cityId,
    required String place,
    required String note,
    required String language,
  }) async {
    final account = ref.read(currentAccountProvider).value;
    if (account == null || account.isGuest) {
      throw StateError('A tip needs an account');
    }
    await ref.read(cityTipRepositoryProvider).submitTip(
          uid: account.uid,
          cityId: cityId,
          place: place,
          note: note,
          language: language,
        );
    await _pause(cityTipPauseAfterTip);
  }
}
