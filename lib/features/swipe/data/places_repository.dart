import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../common/models/place_model.dart';
import '../../../common/models/swipe_result_model.dart';
import '../../../common/models/group_model.dart';
import '../../../common/models/place_cache_metadata.dart';
import '../../../common/utils/geo_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobileapp/core/config/env.dart';
import 'package:mobileapp/core/config/app_config.dart';

class PlacesRepository {
  final FirebaseFirestore _db;
  final http.Client _client;

  PlacesRepository({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _client = httpClient ?? http.Client();

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
        'includedTypes': [
          'tourist_attraction',
          'museum',
          'landmark',
          'church',
          'art_gallery',
          'historical_landmark',
          'national_park',
          'sculpture',
        ],
        'excludedTypes': ['restaurant', 'cafe', 'bar', 'food'],
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
        id: p['id'] as String? ?? '',
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

  Future<List<PlaceModel>> loadNearbyPlaces(
    double lat,
    double lng, {
    double radiusKm = 50.0,
    List<String>? tags,
  }) async {
    final query = await _db.collection('places').get();
    return query.docs
        .map((doc) => PlaceModel.fromJson(doc.data()))
        .where((place) {
      final isWithinRadius = GeoUtils.isWithinRadius(
        lat,
        lng,
        place.lat,
        place.lng,
        radiusKm,
      );
      final matchesTags =
          tags == null || tags.every((t) => place.types.contains(t));
      return isWithinRadius && matchesTags;
    }).toList();
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
