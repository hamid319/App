import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../common/models/place_model.dart';
import '../../../common/models/swipe_result_model.dart';
import '../../../common/models/group_model.dart';
import '../../../common/models/place_cache_metadata.dart';
import '../../../common/utils/geo_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:swipetrip/core/config/env.dart';
import 'package:swipetrip/core/config/app_config.dart';
import 'package:swipetrip/core/constants/popular_cities.dart';

class PlacesRepository {
  final FirebaseFirestore _db;
  final http.Client _client;
  final FirebaseFunctions? _functions;

  PlacesRepository({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _client = httpClient ?? http.Client(),
        _functions = functions;

  FirebaseFunctions get _functionsInstance =>
      _functions ??
      FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  /// How long a city's loaded places are reused. The home feed and the
  /// solo deck both need the same city on start; this makes it one query.
  static const cityCacheTtl = Duration(minutes: 10);

  /// A curated city counts as "near" when its centre lies within the
  /// search radius plus this much: a city's places spread around its
  /// centre, so a user in the suburbs still gets their city.
  static const cityReachKm = 30.0;

  /// Upper bound for the legacy (Google cache) places read per city.
  static const legacyCityLimit = 150;

  final Map<String, ({DateTime at, Future<List<PlaceModel>> places})>
      _cityCache = {};

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

  /// Forgets the cached city places (pull to refresh).
  void clearCityCache() => _cityCache.clear();

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
  /// [radiusKm]. While a city has no curated places, its legacy Google
  /// cache is used. Empty when no curated city is near: the collection is
  /// never read as a whole.
  Future<List<PlaceModel>> loadPlacesAround({
    String? cityId,
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final id = cityId ?? nearestCityId(lat, lng, radiusKm: radiusKm);
    if (id == null) return const [];
    final places = await _loadCityOrLegacy(id);
    return places
        .where((p) => GeoUtils.isWithinRadius(lat, lng, p.lat, p.lng, radiusKm))
        .toList();
  }

  Future<List<PlaceModel>> _loadCityOrLegacy(String cityId) async {
    try {
      final curated = await loadCityPlaces(cityId);
      if (curated.isNotEmpty) return curated;
    } catch (e) {
      debugPrint('Loading curated places for $cityId failed: $e');
    }
    final legacyId = _legacyCityId(cityId);
    if (legacyId == null) return const [];
    final snapshot = await _db
        .collection('places')
        .where('cityId', isEqualTo: legacyId)
        .limit(legacyCityLimit)
        .get();
    return snapshot.docs.map((d) => PlaceModel.fromJson(d.data())).toList();
  }

  /// City id the legacy Google path ([fetchAndCachePlacesForCity]) stores
  /// ("PT_lisbon") for an app city id ("pt_lisbon").
  static String? _legacyCityId(String cityId) {
    final city = PopularCity.byId(cityId);
    if (city == null) return null;
    final prefix = '${city.countryCode.toLowerCase()}_';
    if (!cityId.startsWith(prefix)) return null;
    return '${city.countryCode}_${cityId.substring(prefix.length)}';
  }

  /// App city id ("pt_lisbon") of a group location ("PT", "lisbon").
  static String curatedCityId(GroupLocation location) =>
      '${location.countryCode.toLowerCase()}_${location.cityId}';

  /// Loads the place pool for a city.
  ///
  /// Uses the curated import when the city has one. Otherwise delegates to
  /// the `getCityPlaces` Cloud Function, which owns the Google
  /// API keys and caches photos in Cloud Storage, so no key ships in the app.
  /// Falls back to the legacy direct-HTTP path only when the Cloud Function is
  /// switched off in [AppConfig].
  Future<List<PlaceModel>> fetchPlacesForCity(
    GroupLocation location, {
    int limit = 20,
  }) async {
    if (limit <= 0) return [];
    try {
      // Sights only: the swipe decks do not show venues yet.
      final curated = (await loadCityPlaces(curatedCityId(location)))
          .where((p) => !p.isVenue)
          .toList();
      if (curated.isNotEmpty) {
        // A mix of the best-known places, different for every session.
        final top = curated.take(limit * 2).toList()..shuffle();
        return top.take(limit).toList();
      }
    } catch (e) {
      debugPrint('Curated places for ${location.cityName} failed: $e');
    }
    if (!AppConfig.usePlacesCloudFunction) {
      return fetchAndCachePlacesForCity(location, limit: limit);
    }

    final restrictedLimit = limit.clamp(1, AppConfig.maxPlacesLimit);

    try {
      final callable = _functionsInstance.httpsCallable('getCityPlaces');
      final response = await callable.call<Map<String, dynamic>>({
        'countryCode': location.countryCode,
        'cityId': location.cityId,
        'cityName': location.cityName,
        'lat': location.lat,
        'lng': location.lng,
        'limit': restrictedLimit,
      });

      final placeIds = List<String>.from(
        (response.data['placeIds'] as List?) ?? const <String>[],
      );
      if (placeIds.isEmpty) return [];
      return loadPlacesByIds(placeIds);
    } on FirebaseFunctionsException catch (e) {
      if (AppConfig.useDevPlacesFallback &&
          const {'not-found', 'unavailable', 'internal'}.contains(e.code)) {
        debugPrint('getCityPlaces unavailable (${e.code}); '
            'using Firestore places near ${location.cityName}.');
        final nearby = await loadNearbyPlaces(location.lat, location.lng);
        return nearby.take(restrictedLimit).toList();
      }
      throw Exception(e.message ?? 'Could not load places for this city.');
    }
  }

  Future<List<PlaceModel>> fetchAndCachePlacesForCity(
    GroupLocation location, {
    int limit = 20,
  }) async {
    if (limit <= 0) return [];
    final restrictedLimit = limit.clamp(1, AppConfig.maxPlacesLimit);
    final cityId = '${location.countryCode}_${location.cityId}';

    // 1. Check Firestore cache first
    final cached = await _db
        .collection('places')
        .where('cityId', isEqualTo: cityId)
        .limit(restrictedLimit)
        .get();

    final cachedPlaces =
        cached.docs.map((d) => PlaceModel.fromJson(d.data())).toList();
    if (cachedPlaces.length >= restrictedLimit) {
      return cachedPlaces;
    }

    final metadataDocument =
        await _db.collection('placeCacheMetadata').doc(cityId).get();
    final metadata = PlaceCacheMetadata.tryFromJson(
      metadataDocument.data(),
      expectedCityId: cityId,
    );
    if (metadata != null &&
        metadata.isExhausted &&
        metadata.isConsistentWithCache(cachedPlaces.length)) {
      return cachedPlaces;
    }

    // 2. Cache miss — call Nearby Search (New)
    if (!AppConfig.enableRealPlacesAPI) {
      throw Exception(
          'Real Google Places API calls are currently disabled in AppConfig to prevent charges.');
    }

    final apiKey = Env.googlePlacesApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Google Places API key not configured in .env');
    }
    final geminiKey = Env.geminiApiKey;

    final url =
        Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.location,places.photos,places.types,places.formattedAddress',
      },
      body: json.encode({
        // Nearby Search (New) only accepts Table A place types here.
        // 'landmark' and 'food' are Table B and make the request fail with
        // INVALID_ARGUMENT, so Table A equivalents are used instead.
        'includedTypes': [
          'tourist_attraction',
          'museum',
          'church',
          'art_gallery',
          'historical_landmark',
          'cultural_landmark',
          'monument',
          'national_park',
          'sculpture',
        ],
        'excludedTypes': ['restaurant', 'cafe', 'bar'],
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': location.lat,
              'longitude': location.lng,
            },
            'radius': 15000.0,
          },
        },
        'maxResultCount': restrictedLimit,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Nearby Search failed with status ${response.statusCode}');
    }

    late final Map<String, dynamic> data;
    try {
      data = json.decode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const FormatException('Nearby Search returned malformed JSON');
    }
    final List results = (data['places'] as List?) ?? [];
    final boundedResults = results.take(restrictedLimit);

    final List<PlaceModel> places = [];
    for (final p in boundedResults) {
      // An empty id would become doc('') further down, which throws and aborts
      // the whole cache batch.
      final placeId = p['id'] as String?;
      if (placeId == null || placeId.isEmpty) continue;

      final photoName = (p['photos'] as List?)?.isNotEmpty == true
          ? p['photos'][0]['name'] as String?
          : null;

      final name = (p['displayName']?['text'] as String?) ?? 'Unknown';
      final address = p['formattedAddress'] as String?;
      final types = List<String>.from(p['types'] ?? []);
      final description = await _generateTravelSummary(
        geminiKey: geminiKey,
        placeName: name,
        cityName: location.cityName,
        address: address,
        types: types,
      );

      final place = PlaceModel(
        id: placeId,
        name: name,
        description: description,
        lat: (p['location']?['latitude'] as num?)?.toDouble() ?? 0.0,
        lng: (p['location']?['longitude'] as num?)?.toDouble() ?? 0.0,
        address: address,
        photoResourceNames:
            photoName == null ? const <String>[] : <String>[photoName],
        types: types,
        cityId: cityId,
      );

      places.add(place);
    }

    final cachedIds = cachedPlaces.map((place) => place.id).toSet();
    final resultingCacheCount =
        cachedIds.followedBy(places.map((place) => place.id)).toSet().length;
    final batch = _db.batch();
    for (final place in places) {
      batch.set(
        _db.collection('places').doc(place.id),
        place.toJson(),
        SetOptions(merge: true),
      );
    }
    batch.set(
      _db.collection('placeCacheMetadata').doc(cityId),
      PlaceCacheMetadata(
        cityId: cityId,
        fetchedCount: resultingCacheCount,
        requestedLimit: restrictedLimit,
        isExhausted: results.length < restrictedLimit,
        lastSyncedAt: DateTime.now().toUtc(),
      ).toJson(),
    );
    await batch.commit();

    return places;
  }

  Future<String?> _generateTravelSummary({
    required String geminiKey,
    required String placeName,
    required String cityName,
    required String? address,
    required List<String> types,
  }) async {
    if (geminiKey.isEmpty || placeName == 'Unknown') return null;

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${Uri.encodeComponent(Env.geminiModel)}:generateContent',
    );
    final prompt = StringBuffer()
      ..write('Write one concise, factual travel sentence for ')
      ..write(placeName)
      ..write(' in ')
      ..write(cityName);

    if (address != null && address.isNotEmpty) {
      prompt
        ..write(', located at ')
        ..write(address);
    }
    if (types.isNotEmpty) {
      prompt
        ..write('. Categories: ')
        ..write(types.join(', '));
    }
    prompt.write('.');

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': geminiKey,
        },
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt.toString()},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.4,
            'maxOutputTokens': 60,
          },
        }),
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      final text = parts.first['text'] as String?;
      final trimmed = text?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
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
