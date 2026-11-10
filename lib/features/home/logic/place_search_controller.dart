import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/place_search_entry.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../main_providers.dart';
import '../../swipe/data/places_repository.dart';
import '../../swipe/logic/discover_preferences_controller.dart';
import 'home_feed_controller.dart';

/// The city the search looks in: the one chosen on Discover, else the
/// curated city near the user ("near me"); null when none is near.
final searchCityProvider = FutureProvider<PopularCity?>((ref) async {
  final prefs = await ref.watch(discoverPreferencesProvider.future);
  if (prefs.city != null) return prefs.city;
  try {
    final position =
        await ref.read(locationServiceProvider).getCurrentLocation();
    return PopularCity.byId(PlacesRepository.nearestCityId(
      position.latitude,
      position.longitude,
      radiusKm: prefs.radiusKm.toDouble(),
    ));
  } catch (_) {
    return null;
  }
});

/// A city's search index, loaded once per app session.
final placeSearchIndexProvider =
    FutureProvider.family<List<PlaceSearchEntry>, String>((ref, cityId) async {
  await awaitPlacesSession(ref);
  return ref.read(placesRepositoryProvider).loadSearchIndex(cityId);
});

/// Lower case without accents, so "Café" matches "cafe" and "Spöri" "spori".
/// shortcut: "ue"/"oe" spellings are not folded; add if users type them.
String normalizeForSearch(String s) {
  const fold = {
    'ä': 'a',
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'å': 'a',
    'ã': 'a',
    'ö': 'o',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ø': 'o',
    'ü': 'u',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ç': 'c',
    'ñ': 'n',
    'ß': 'ss',
  };
  final out = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    out.write(fold[ch] ?? ch);
  }
  return out.toString();
}

/// Entries whose name (English or German) contains every word of [query]:
/// names starting with it first, then names with a word starting with it,
/// then the rest; within each group the index order (best-known first).
List<PlaceSearchEntry> searchPlaces(
  List<PlaceSearchEntry> entries,
  String query, {
  int limit = 50,
}) {
  final words = normalizeForSearch(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];
  final whole = words.join(' ');
  final buckets = [
    <PlaceSearchEntry>[],
    <PlaceSearchEntry>[],
    <PlaceSearchEntry>[]
  ];
  for (final e in entries) {
    var best = 3;
    for (final raw in [e.name, if (e.nameDe != null) e.nameDe!]) {
      final name = normalizeForSearch(raw);
      if (!words.every(name.contains)) continue;
      final rank = name.startsWith(whole)
          ? 0
          : (name.contains(' $whole') || name.contains('-$whole'))
              ? 1
              : 2;
      if (rank < best) best = rank;
    }
    if (best < 3) buckets[best].add(e);
  }
  return buckets.expand((b) => b).take(limit).toList();
}
