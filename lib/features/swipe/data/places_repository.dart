import 'package:flutter/foundation.dart';
import '../../../common/models/place_model.dart';
import '../../../common/models/place_search_entry.dart';
import '../../../common/models/swipe_result_model.dart';
import '../../../common/models/group_model.dart';
import '../../../common/utils/geo_utils.dart';
import '../../../common/utils/geohash.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swipetrip/core/constants/popular_cities.dart';

class PlacesRepository {
  final FirebaseFirestore _db;

  PlacesRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// How long a city's loaded places are reused. The home feed and the
  /// solo deck both need the same city on start; this makes it one query.
  static const cityCacheTtl = Duration(minutes: 10);

  /// A curated city counts as "near" when its centre lies within the
  /// search radius plus this much: a city's places spread around its
  /// centre, so a user in the suburbs still gets their city.
  static const cityReachKm = 30.0;

  final Map<String, ({DateTime at, Future<List<PlaceModel>> places})>
      _cityCache = {};

  /// Loaded place tiles (placeTiles/{cityId}_{geohash}), kept like cities.
  final Map<String, ({DateTime at, Future<List<PlaceModel>> places})>
      _tileCache = {};

  /// Curated places of a city from the batch import (tools/city-import):
  /// active ones only, best-known first. One bounded query per city (never
  /// the whole collection), reused for [cityCacheTtl]; [refresh] skips the
  /// cache. The returned list is unmodifiable.
  Future<List<PlaceModel>> loadCityPlaces(
    String cityId, {
    int limit = 150,
    bool refresh = false,
  }) {
    final key = '$cityId|$limit';
    final cached = _cityCache[key];
    if (!refresh &&
        cached != null &&
        DateTime.now().difference(cached.at) < cityCacheTtl) {
      return cached.places;
    }
    final future = _queryCityPlaces(cityId, limit);
    _cityCache[key] = (at: DateTime.now(), places: future);
    // A failed load is not kept, so the next call tries again.
    future.catchError((Object _) {
      if (identical(_cityCache[key]?.places, future)) _cityCache.remove(key);
      return const <PlaceModel>[];
    });
    return future;
  }

  /// Forgets the cached city places and tiles (pull to refresh).
  void clearCityCache() {
    _cityCache.clear();
    _tileCache.clear();
  }

  Future<List<PlaceModel>> _queryCityPlaces(String cityId, int limit) async {
    final snapshot = await _db
        .collection('places')
        .where('cityId', isEqualTo: cityId)
        .where('status', isEqualTo: 'active')
        .orderBy('popularity', descending: true)
        .limit(limit)
        .get();
    return List.unmodifiable(
        snapshot.docs.map((d) => PlaceModel.fromJson(d.data())));
  }

  /// Id of the curated city nearest to a position, if one is within
  /// [radiusKm] plus [cityReachKm].
  static String? nearestCityId(double lat, double lng,
          {required double radiusKm}) =>
      PopularCity.nearest(lat, lng, maxKm: radiusKm + cityReachKm)?.id;

  /// Venues of a city (restaurants, cafés, bars from the OpenStreetMap
  /// import), best-known first. Returns an empty list while the composite
  /// index (cityId, kind, status, popularity) is not deployed yet, so the
  /// app shows its "coming soon" placeholder instead of an error.
  Future<List<PlaceModel>> loadCityVenues(
    String cityId, {
    int limit = 30,
  }) async {
    try {
      final snapshot = await _db
          .collection('places')
          .where('cityId', isEqualTo: cityId)
          .where('kind', isEqualTo: 'venue')
          .where('status', isEqualTo: 'active')
          .orderBy('popularity', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((d) => PlaceModel.fromJson(d.data())).toList();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      debugPrint('Venue index for $cityId not ready yet: ${e.message}');
      return const [];
    }
  }

  /// Places for solo discovery around a position: the curated places of
  /// [cityId] (or of the nearest curated city, see [nearestCityId]) within
  /// [radiusKm]. Empty when no curated city is near: the collection is
  /// never read as a whole.
  ///
  /// Near the user ([cityId] null) this adds the place tiles around the
  /// position (sights and venues of the area, 9 reads) and ranks by
  /// [rankByRelevance], so a user anywhere in a big city gets what is
  /// close to them, not the same city-wide top list.
  Future<List<PlaceModel>> loadPlacesAround({
    String? cityId,
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final id = cityId ?? nearestCityId(lat, lng, radiusKm: radiusKm);
    if (id == null) return const [];
    final city = await _loadCity(id);
    final tiles = cityId == null
        ? await _loadTilesAround(id, lat, lng)
        : const <PlaceModel>[];
    // Full documents win over the compact tile entries.
    final byId = {
      for (final p in tiles) p.id: p,
      for (final p in city) p.id: p,
    };
    final inRange = byId.values
        .where((p) => GeoUtils.isWithinRadius(lat, lng, p.lat, p.lng, radiusKm))
        .toList();
    return cityId == null ? rankByRelevance(inRange, lat, lng) : inRange;
  }

  Future<List<PlaceModel>> _loadTilesAround(
      String cityId, double lat, double lng) async {
    final tiles = await Future.wait([
      for (final cell in geohashesAround(lat, lng))
        _loadTile('${cityId}_$cell'),
    ]);
    return [for (final tile in tiles) ...tile];
  }

  /// One tile; a missing or failed tile is empty (and retried next time).
  Future<List<PlaceModel>> _loadTile(String tileId) {
    final cached = _tileCache[tileId];
    if (cached != null && DateTime.now().difference(cached.at) < cityCacheTtl) {
      return cached.places;
    }
    // Runs after the cache entry below is set, so a failure can drop it.
    final future = Future(() async {
      try {
        final doc = await _db.collection('placeTiles').doc(tileId).get();
        final entries = doc.data()?['places'];
        if (entries is! List) return const <PlaceModel>[];
        return [
          for (final entry in entries)
            if (entry is Map)
              PlaceModel.fromJson(Map<String, dynamic>.from(entry)),
        ];
      } catch (e) {
        debugPrint('Loading place tile $tileId failed: $e');
        _tileCache.remove(tileId);
        return const <PlaceModel>[];
      }
    });
    _tileCache[tileId] = (at: DateTime.now(), places: future);
    return future;
  }

  Future<List<PlaceModel>> _loadCity(String cityId) async {
    try {
      return await loadCityPlaces(cityId);
    } catch (e) {
      debugPrint('Loading curated places for $cityId failed: $e');
      return const [];
    }
  }

  /// App city id ("pt_lisbon") of a group location ("PT", "lisbon").
  static String curatedCityId(GroupLocation location) =>
      '${location.countryCode.toLowerCase()}_${location.cityId}';

  /// Loads the place pool for a city: the best-known curated places,
  /// a different mix every time. Sights only: the decks show no venues.
  /// Empty while the city has no curated import (tools/city-import).
  Future<List<PlaceModel>> fetchPlacesForCity(
    GroupLocation location, {
    int limit = 20,
  }) async {
    if (limit <= 0) return [];
    final curated = (await _loadCity(curatedCityId(location)))
        .where((p) => !p.isVenue)
        .toList();
    final top = curated.take(limit * 2).toList()..shuffle();
    return top.take(limit).toList();
  }

  /// Places within [radiusKm] of a position (optionally with all [tags]),
  /// taken from the nearest curated city; see [loadPlacesAround].
  Future<List<PlaceModel>> loadNearbyPlaces(
    double lat,
    double lng, {
    double radiusKm = 50.0,
    List<String>? tags,
  }) async {
    final places =
        await loadPlacesAround(lat: lat, lng: lng, radiusKm: radiusKm);
    if (tags == null) return places;
    return places.where((p) => tags.every((t) => p.types.contains(t))).toList();
  }

  /// Search indexes per city, kept for the app session (they change only
  /// with an import).
  final Map<String, Future<List<PlaceSearchEntry>>> _searchCache = {};

  /// Every active place of a city by name, best-known first: 1-3 reads of
  /// placeSearch/{cityId}_{part}. Empty when the city has no index yet.
  Future<List<PlaceSearchEntry>> loadSearchIndex(String cityId) {
    final cached = _searchCache[cityId];
    if (cached != null) return cached;
    final future = _querySearchIndex(cityId);
    _searchCache[cityId] = future;
    // A failed load is not kept, so the next call tries again.
    future.catchError((Object _) {
      if (identical(_searchCache[cityId], future)) _searchCache.remove(cityId);
      return const <PlaceSearchEntry>[];
    });
    return future;
  }

  Future<List<PlaceSearchEntry>> _querySearchIndex(String cityId) async {
    final col = _db.collection('placeSearch');
    final first = await col.doc('${cityId}_0').get();
    final data = first.data();
    if (data == null) return const [];
    final parts = (data['parts'] as num?)?.toInt() ?? 1;
    final rest = await Future.wait(
        [for (var i = 1; i < parts; i++) col.doc('${cityId}_$i').get()]);
    return List.unmodifiable([
      for (final doc in [first, ...rest])
        for (final e in (doc.data()?['entries'] as List? ?? const []))
          PlaceSearchEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ]);
  }

  Future<PlaceModel?> getPlaceById(String id) async {
    try {
      final doc = await _db.collection('places').doc(id).get();
      if (doc.exists) {
        return PlaceModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<PlaceModel>> loadPlacesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final places = <PlaceModel>[];
    final seen = <String>{};
    for (final id in ids) {
      if (id.isEmpty || !seen.add(id)) continue;

      final place = await getPlaceById(id);
      if (place != null) {
        places.add(place);
      }
    }

    return places;
  }

  Future<void> recordSwipe({
    required String userId,
    required String placeId,
    required bool liked,
  }) async {
    final docId = '${userId}_$placeId';
    final swipeResult = SwipeResultModel(
      id: docId,
      userId: userId,
      placeId: placeId,
      liked: liked,
      timestamp: DateTime.now(),
    );
    await _db.collection('swipeResults').doc(docId).set(swipeResult.toJson());
  }

  /// Removes one swipe again (undo), so the place counts as unseen.
  Future<void> deleteSwipe({
    required String userId,
    required String placeId,
  }) async {
    await _db.collection('swipeResults').doc('${userId}_$placeId').delete();
  }

  Future<List<SwipeResultModel>> getUserSwipes(String userId) async {
    final query = await _db
        .collection('swipeResults')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

    return query.docs
        .map((doc) => SwipeResultModel.fromJson(doc.data()))
        .toList();
  }

  Future<Set<String>> getSwipedPlaceIds(String userId) async {
    final swipes = await getUserSwipes(userId);
    return swipes.map((s) => s.placeId).toSet();
  }

  Future<void> clearSwipedPlaces(String userId) async {
    final query = await _db
        .collection('swipeResults')
        .where('userId', isEqualTo: userId)
        .get();
    final batch = _db.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<List<String>> getUserLikedPlaceIds(String userId) async {
    final query = await _db
        .collection('swipeResults')
        .where('userId', isEqualTo: userId)
        .where('liked', isEqualTo: true)
        .get();

    return query.docs.map((doc) => doc.data()['placeId'] as String).toList();
  }
}

/// Nearby and well-known first: popularity divided by (1 + distance / 2 km),
/// so a good bar around the corner beats a famous sight across town.
List<PlaceModel> rankByRelevance(
    Iterable<PlaceModel> places, double lat, double lng) {
  double score(PlaceModel p) =>
      (p.popularity ?? 0) /
      (1 + GeoUtils.calculateDistance(lat, lng, p.lat, p.lng) / 2);
  final scored = [for (final p in places) (place: p, score: score(p))]
    ..sort((a, b) => b.score.compareTo(a.score));
  return [for (final s in scored) s.place];
}
