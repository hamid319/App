import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/place_model.dart';
import '../../../common/utils/opening_hours_format.dart';
import '../../../core/config/app_config.dart';
import '../../../main_providers.dart';
import '../../swipe/logic/discover_preferences_controller.dart';

/// The themed rows of the home feed; [slug] is the `/collection/:theme`
/// path segment.
enum HomeCollection {
  mustSees('must-sees'),
  tonight('tonight'),
  hiddenGems('hidden-gems');

  const HomeCollection(this.slug);

  final String slug;

  static HomeCollection? fromSlug(String? slug) {
    for (final c in values) {
      if (c.slug == slug) return c;
    }
    return null;
  }
}

/// Everything the home feed shows for one place (a city or "near me").
@immutable
class HomeFeed {
  const HomeFeed({
    required this.sightCount,
    required this.mustSees,
    required this.tonight,
    required this.hiddenGems,
    required this.hasVenues,
  });

  /// Sights available to swipe in this place.
  final int sightCount;
  final List<PlaceModel> mustSees;
  final List<PlaceModel> tonight;
  final List<PlaceModel> hiddenGems;

  /// False until the venue import has reached this city (or in GPS mode):
  /// the "Tonight" row then shows a "coming soon" ticket.
  final bool hasVenues;

  List<PlaceModel> places(HomeCollection collection) => switch (collection) {
        HomeCollection.mustSees => mustSees,
        HomeCollection.tonight => tonight,
        HomeCollection.hiddenGems => hiddenGems,
      };
}

/// How many sights count as must-sees; hidden gems start below the top
/// [hiddenGemsFrom].
const mustSeeCount = 10;
const hiddenGemsFrom = 20;

/// "Tonight" means open at some point in this window (minutes of the day).
const tonightFrom = 18 * 60;
const tonightTo = 23 * 60;

/// Best-known first; places without a popularity go last. Stable, so the
/// query order breaks ties.
List<PlaceModel> rankByPopularity(Iterable<PlaceModel> places) {
  final indexed = places.toList().asMap().entries.toList()
    ..sort((a, b) {
      final pa = a.value.popularity, pb = b.value.popularity;
      if (pa != pb) {
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pb.compareTo(pa);
      }
      return a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// The top [mustSeeCount] sights by popularity.
List<PlaceModel> selectMustSees(Iterable<PlaceModel> sights) =>
    rankByPopularity(sights).take(mustSeeCount).toList();

/// Same value for the whole calendar day of [day], different per [salt]
/// (the city), so the hidden gems change daily but not on every rebuild.
int dailySeed(DateTime day, [String salt = '']) {
  var seed = day.year * 10000 + day.month * 100 + day.day;
  for (final unit in salt.codeUnits) {
    seed = (seed * 31 + unit) & 0x7fffffff;
  }
  return seed;
}

/// Sights ranked below the top [hiddenGemsFrom] (or, in a smaller city,
/// its bottom third), never a must-see, shuffled with [dailySeed].
List<PlaceModel> selectHiddenGems(
  Iterable<PlaceModel> sights, {
  required DateTime day,
  String salt = '',
}) {
  final ranked = rankByPopularity(sights);
  final mustSeeIds = ranked.take(mustSeeCount).map((p) => p.id).toSet();
  final start = ranked.length > hiddenGemsFrom
      ? hiddenGemsFrom
      : ranked.length - (ranked.length / 3).ceil();
  final pool =
      ranked.skip(start).where((p) => !mustSeeIds.contains(p.id)).toList();
  return pool..shuffle(math.Random(dailySeed(day, salt)));
}

/// Venues worth suggesting for tonight: those open at some point between
/// [tonightFrom] and [tonightTo] on [now]'s day first, then those whose
/// hours are unknown or unreadable; venues known to be closed are left out.
/// Keeps the given (popularity) order within each group.
List<PlaceModel> selectTonight(Iterable<PlaceModel> venues,
    {required DateTime now}) {
  final open = <PlaceModel>[], unknown = <PlaceModel>[];
  for (final venue in venues) {
    switch (isOpenBetween(
      venue.openingHours,
      day: now,
      fromMinutes: tonightFrom,
      toMinutes: tonightTo,
    )) {
      case true:
        open.add(venue);
      case null:
        unknown.add(venue);
      case false:
        break;
    }
  }
  return [...open, ...unknown];
}

/// Builds the feed from loaded [sights] and [venues] (null: venues are not
/// available here, e.g. in GPS mode).
HomeFeed buildHomeFeed({
  required List<PlaceModel> sights,
  required List<PlaceModel>? venues,
  required DateTime now,
  String salt = '',
}) {
  final onlySights = sights.where((p) => !p.isVenue).toList();
  return HomeFeed(
    sightCount: onlySights.length,
    mustSees: selectMustSees(onlySights),
    hiddenGems: selectHiddenGems(onlySights, day: now, salt: salt),
    tonight: selectTonight(
      rankByPopularity(venues ?? const []),
      now: now,
    ),
    hasVenues: venues != null && venues.isNotEmpty,
  );
}

/// /places needs a signed-in (guest) session; wait briefly for it so the
/// first load right after app start does not fail on the rules.
Future<void> _awaitSession(Ref ref) async {
  final auth = ref.read(authServiceProvider);
  if (auth.currentUser != null) return;
  try {
    await auth
        .authStateChanges()
        .firstWhere((user) => user != null)
        .timeout(const Duration(seconds: 10));
  } catch (_) {}
}

/// Sights of a curated city, best-known first. Cached per city for the
/// app session, refreshed by invalidating it. The query itself is shared
/// with the solo deck (PlacesRepository caches it), so both load one city
/// with one read.
final citySightsProvider =
    FutureProvider.family<List<PlaceModel>, String>((ref, cityId) async {
  await _awaitSession(ref);
  final places =
      await ref.read(placesRepositoryProvider).loadCityPlaces(cityId);
  return rankByPopularity(places.where((p) => !p.isVenue));
});

/// Venues of a curated city; empty when there are none yet or the query
/// fails, so the feed shows its placeholder instead of an error.
final cityVenuesProvider =
    FutureProvider.family<List<PlaceModel>, String>((ref, cityId) async {
  await _awaitSession(ref);
  try {
    return await ref.read(placesRepositoryProvider).loadCityVenues(cityId);
  } catch (e) {
    debugPrint('Loading venues for $cityId failed: $e');
    return const [];
  }
});

/// Sights around the user's position ("near me"), within [radiusKm]: the
/// same lookup as the solo deck (nearest curated city, else nearby).
final nearbySightsProvider =
    FutureProvider.family<List<PlaceModel>, int>((ref, radiusKm) async {
  var lat = AppConfig.defaultLat, lng = AppConfig.defaultLng;
  try {
    final position =
        await ref.read(locationServiceProvider).getCurrentLocation();
    lat = position.latitude;
    lng = position.longitude;
  } catch (_) {}
  await _awaitSession(ref);
  final places = await ref.read(placesRepositoryProvider).loadPlacesAround(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm.toDouble(),
      );
  return rankByPopularity(places.where((p) => !p.isVenue));
});

/// The home feed for the place chosen on Discover. Follows the city picker;
/// the loaded places stay cached per city in the providers above.
final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final prefs = await ref.watch(discoverPreferencesProvider.future);
  final city = prefs.city;
  final now = DateTime.now();
  if (city == null) {
    final sights = await ref.watch(nearbySightsProvider(prefs.radiusKm).future);
    return buildHomeFeed(sights: sights, venues: null, now: now);
  }
  final sights = ref.watch(citySightsProvider(city.id).future);
  final venues = ref.watch(cityVenuesProvider(city.id).future);
  return buildHomeFeed(
    sights: await sights,
    venues: await venues,
    now: now,
    salt: city.id,
  );
});

/// Reloads the feed of the current place from Firestore (pull to refresh).
void refreshHomeFeed(WidgetRef ref) {
  // The repository reuses loaded cities for a while; a refresh re-reads.
  ref.read(placesRepositoryProvider).clearCityCache();
  final city = ref.read(discoverPreferencesProvider).value?.city;
  if (city == null) {
    ref.invalidate(nearbySightsProvider);
  } else {
    ref.invalidate(citySightsProvider(city.id));
    ref.invalidate(cityVenuesProvider(city.id));
  }
  ref.invalidate(homeFeedProvider);
}
