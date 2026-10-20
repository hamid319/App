import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipetrip/common/models/interest.dart';
import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/core/constants/popular_cities.dart';
import 'package:swipetrip/core/services/preferences_service.dart';
import 'package:swipetrip/features/swipe/logic/discover_preferences_controller.dart';

PlaceModel _place(List<String> types) => PlaceModel(
      id: types.join('-'),
      name: 'Test',
      lat: 0,
      lng: 0,
      types: types,
    );

void main() {
  group('placeMatchesInterests', () {
    test('no interests means no filter', () {
      expect(placeMatchesInterests(_place(['bar']), {}), isTrue);
    });

    test('matches if any type belongs to any selected interest', () {
      final museum = _place(['museum', 'point_of_interest']);
      expect(placeMatchesInterests(museum, {Interest.culture}), isTrue);
      expect(
        placeMatchesInterests(museum, {Interest.nature, Interest.culture}),
        isTrue,
      );
      expect(placeMatchesInterests(museum, {Interest.nature}), isFalse);
    });

    test('test-data tags map to interests too', () {
      expect(
        placeMatchesInterests(_place(['nature', 'outdoors']), {Interest.nature}),
        isTrue,
      );
    });

    test('a place without types never matches an active filter', () {
      expect(placeMatchesInterests(_place([]), {Interest.beach}), isFalse);
    });
  });

  group('DiscoverPreferences', () {
    test('survives a JSON round trip', () {
      final prefs = DiscoverPreferences(
        city: PopularCity.byId('pt_lisbon'),
        interests: const {Interest.views, Interest.history},
        radiusKm: 25,
      );
      final back = DiscoverPreferences.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(back, prefs);
    });

    test('ignores unknown interests and invalid radius', () {
      final p = DiscoverPreferences.fromJson({
        'cityId': 'nowhere',
        'interests': ['culture', 'teleportation'],
        'radiusKm': 7,
      });
      expect(p.city, isNull);
      expect(p.interests, {Interest.culture});
      expect(p.radiusKm, DiscoverPreferences.defaultRadiusKm);
    });

    test('counts active filters for the badge', () {
      expect(const DiscoverPreferences().activeFilterCount, 0);
      expect(
        const DiscoverPreferences(
          interests: {Interest.beach, Interest.family},
          radiusKm: 10,
        ).activeFilterCount,
        3,
      );
    });
  });

  group('DiscoverPreferencesController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves the city and filters and restores them', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(discoverPreferencesProvider.future);
      final ctrl = container.read(discoverPreferencesProvider.notifier);

      await ctrl.setCity(PopularCity.byId('de_hamburg'));
      await ctrl.setFilters(interests: {Interest.nature}, radiusKm: 10);

      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      final prefs = await restored.read(discoverPreferencesProvider.future);
      expect(prefs.city?.id, 'de_hamburg');
      expect(prefs.interests, {Interest.nature});
      expect(prefs.radiusKm, 10);
    });

    test('reset keeps the place but clears interests and radius', () async {
      await PreferencesService.setDiscoverPreferences(jsonEncode({
        'cityId': 'fr_paris',
        'interests': ['culture'],
        'radiusKm': 100,
      }));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(discoverPreferencesProvider.future);
      await container.read(discoverPreferencesProvider.notifier).resetFilters();

      final prefs = container.read(discoverPreferencesProvider).value!;
      expect(prefs.city?.id, 'fr_paris');
      expect(prefs.interests, isEmpty);
      expect(prefs.radiusKm, DiscoverPreferences.defaultRadiusKm);
    });

    test('"near me" clears the chosen city', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(discoverPreferencesProvider.future);
      final ctrl = container.read(discoverPreferencesProvider.notifier);
      await ctrl.setCity(PopularCity.byId('it_rome'));
      await ctrl.setCity(null);
      expect(container.read(discoverPreferencesProvider).value!.city, isNull);
    });
  });
}
