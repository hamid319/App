import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/interest.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../core/services/preferences_service.dart';

/// What the solo Discover deck shows: where, how far around it, and which
/// kinds of places. Group sessions ignore this; their pool is fixed.
@immutable
class DiscoverPreferences {
  const DiscoverPreferences({
    this.city,
    this.interests = const {},
    this.radiusKm = defaultRadiusKm,
  });

  static const int defaultRadiusKm = 50;
  static const radiusOptions = [10, 25, 50, 100];

  /// Null means "near me" (GPS, or the dev default location).
  final PopularCity? city;
  final Set<Interest> interests;
  final int radiusKm;

  /// Number of filters that differ from the defaults, for the badge.
  int get activeFilterCount =>
      interests.length + (radiusKm == defaultRadiusKm ? 0 : 1);

  DiscoverPreferences copyWith({
    PopularCity? city,
    bool clearCity = false,
    Set<Interest>? interests,
    int? radiusKm,
  }) =>
      DiscoverPreferences(
        city: clearCity ? null : (city ?? this.city),
        interests: interests ?? this.interests,
        radiusKm: radiusKm ?? this.radiusKm,
      );

  Map<String, dynamic> toJson() => {
        'cityId': city?.id,
        'interests': [for (final i in interests) i.name],
        'radiusKm': radiusKm,
      };

  factory DiscoverPreferences.fromJson(Map<String, dynamic> json) {
    final radius = (json['radiusKm'] as num?)?.toInt();
    return DiscoverPreferences(
      city: PopularCity.byId(json['cityId'] as String?),
      interests: {
        for (final name in (json['interests'] as List? ?? const []))
          if (Interest.byName(name.toString()) case final i?) i,
      },
      radiusKm: radiusOptions.contains(radius) ? radius! : defaultRadiusKm,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoverPreferences &&
      other.city?.id == city?.id &&
      setEquals(other.interests, interests) &&
      other.radiusKm == radiusKm;

  @override
  int get hashCode => Object.hash(
        city?.id,
        Object.hashAllUnordered(interests),
        radiusKm,
      );
}

final discoverPreferencesProvider =
    AsyncNotifierProvider<DiscoverPreferencesController, DiscoverPreferences>(
  DiscoverPreferencesController.new,
);

class DiscoverPreferencesController
    extends AsyncNotifier<DiscoverPreferences> {
  @override
  Future<DiscoverPreferences> build() async {
    try {
      final raw = await PreferencesService.getDiscoverPreferences();
      if (raw == null) return const DiscoverPreferences();
      return DiscoverPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Could not restore discover preferences: $e');
      return const DiscoverPreferences();
    }
  }

  DiscoverPreferences get _current =>
      state.value ?? const DiscoverPreferences();

  Future<void> _save(DiscoverPreferences next) async {
    if (next == _current) return;
    state = AsyncData(next);
    await PreferencesService.setDiscoverPreferences(jsonEncode(next.toJson()));
  }

  /// [city] null switches back to "near me".
  Future<void> setCity(PopularCity? city) => _save(
        city == null
            ? _current.copyWith(clearCity: true)
            : _current.copyWith(city: city),
      );

  Future<void> setFilters({
    required Set<Interest> interests,
    required int radiusKm,
  }) =>
      _save(_current.copyWith(interests: interests, radiusKm: radiusKm));

  /// Clears interests and radius; keeps the chosen place.
  Future<void> resetFilters() => _save(
        _current.copyWith(
          interests: const {},
          radiusKm: DiscoverPreferences.defaultRadiusKm,
        ),
      );
}
