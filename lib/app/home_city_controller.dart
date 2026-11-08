import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/popular_cities.dart';
import '../core/services/preferences_service.dart';

/// The city the user lives in, if they told us (settings or the home tip
/// banner). Only stored on the device; used to ask locals for tips.
final homeCityProvider =
    NotifierProvider<HomeCityController, PopularCity?>(HomeCityController.new);

class HomeCityController extends Notifier<PopularCity?> {
  bool _userChose = false;

  @override
  PopularCity? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    try {
      final city = PopularCity.byId(await PreferencesService.getHomeCityId());
      // A choice made while this was loading wins over the stored one.
      if (!_userChose) state = city;
    } catch (e) {
      debugPrint('Could not restore home city: $e');
    }
  }

  /// [city] null clears it.
  Future<void> setCity(PopularCity? city) async {
    _userChose = true;
    state = city;
    await PreferencesService.setHomeCityId(city?.id);
  }
}
