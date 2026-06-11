import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../../common/models/place_model.dart';
import '../../../common/models/swipe_result_model.dart';
import '../../../common/models/group_model.dart';
import '../../../common/utils/geo_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlacesRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _googleApiKey =
      "YOUR_GOOGLE_PLACES_API_KEY"; // TODO: Move to .env

  PlacesRepository();

  Future<List<PlaceModel>> fetchExamplePlacesForLocation(
    GroupLocation location, {
    required int limit,
  }) async {
    if (limit <= 0) return [];

    final seedKey = '${location.countryCode}:${location.cityId}';
    final seed = _stableHash(seedKey);
    final random = math.Random(seed);
    final startIndex = seed % mockPlaces.length;

    final List<PlaceModel> generated = [];
    for (var i = 0; i < limit; i++) {
      final basePlace = mockPlaces[(startIndex + i) % mockPlaces.length];
      final placeId =
          '${location.countryCode}_${location.cityId}_${basePlace.id}';
      final baseLat = location.lat != 0.0 ? location.lat : basePlace.lat;
      final baseLng = location.lng != 0.0 ? location.lng : basePlace.lng;
      final place = basePlace.copyWith(
        id: placeId,
        lat: baseLat + _nextOffset(random),
        lng: baseLng + _nextOffset(random),
        address: '${location.cityName}, ${location.countryName}',
      );
      await _db
          .collection('places')
          .doc(place.id)
          .set(place.toJson(), SetOptions(merge: true));
      generated.add(place);
    }

    return generated;
  }

  Future<List<PlaceModel>> fetchPlacesFromGoogleAPI(String destination,
      {int limit = 20}) async {
    // This uses Google Places Text Search to find sights in a specific destination
    final url =
        Uri.parse('https://maps.googleapis.com/maps/api/place/textsearch/json'
            '?query=tourist+attractions+in+$destination'
            '&type=tourist_attraction'
            '&key=$_googleApiKey');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final List results = jsonResponse['results'] as List;

      List<PlaceModel> places = [];
      for (var p in results.take(limit)) {
        final photoReference = p['photos'] != null && p['photos'].isNotEmpty
            ? p['photos'][0]['photo_reference']
            : null;

        final imageUrl = photoReference != null
            ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoReference&key=$_googleApiKey'
            : ''; // Provide a fallback URL if preferred.

        final place = PlaceModel(
          id: p['place_id'],
          name: p['name'],
          address: p['formatted_address'],
          description:
              '', // Text Search doesn't return description easily, could omit or leave empty
          lat: p['geometry']['location']['lat'] as double,
          lng: p['geometry']['location']['lng'] as double,
          imageUrls: imageUrl.isNotEmpty ? [imageUrl] : [],
          averageRating:
              p['rating'] != null ? (p['rating'] as num).toDouble() : null,
          types: List<String>.from(p['types'] ?? []),
        );

        // Cache exactly what we get in the root "places" collection for fast retrieval later
        await _db
            .collection('places')
            .doc(place.id)
            .set(place.toJson(), SetOptions(merge: true));
        places.add(place);
      }
      return places;
    } else {
      throw Exception('Failed to load places from Google API');
    }
  }

  Future<List<PlaceModel>> loadNearbyPlaces(
    double lat,
    double lng, {
    double radiusKm = 50.0,
    List<String>? tags,
    bool useMock = false,
  }) async {
    if (useMock) return mockPlaces;

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

  Future<PlaceModel?> getPlaceById(String id, {bool useMock = false}) async {
    if (useMock) {
      try {
        return mockPlaces.firstWhere((place) => place.id == id);
      } catch (e) {
        return null;
      }
    }
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

  int _stableHash(String input) {
    final bytes = utf8.encode(input);
    var hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) & 0x7fffffff;
    }
    return hash;
  }

  double _nextOffset(math.Random random) {
    return (random.nextDouble() - 0.5) * 0.06;
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

  static const List<PlaceModel> mockPlaces = [
    PlaceModel(
      id: '1',
      name: 'Grand Park',
      description:
          'A beautiful green park perfect for picnics, jogging, and family outings. Features walking trails, playgrounds, and scenic views.',
      lat: 34.0522,
      lng: -118.2437,
      imageUrls: [
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e'
      ],
      types: ['nature', 'outdoors', 'park'],
    ),
    PlaceModel(
      id: '2',
      name: 'City Art Museum',
      description:
          'Modern and classic art exhibits featuring works from renowned artists. Perfect for art enthusiasts and cultural experiences.',
      lat: 34.0523,
      lng: -118.2438,
      imageUrls: [
        'https://images.unsplash.com/photo-1541961017774-22349e4a1262'
      ],
      types: ['art', 'museum', 'culture'],
    ),
    PlaceModel(
      id: '3',
      name: 'Sunset Beach',
      description:
          'Pristine sandy beach with crystal clear waters. Ideal for swimming, sunbathing, and watching beautiful sunsets.',
      lat: 34.0489,
      lng: -118.2440,
      imageUrls: [
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e'
      ],
      types: ['beach', 'outdoors', 'water'],
    ),
    PlaceModel(
      id: '4',
      name: 'Mountain Trail',
      description:
          'Challenging hiking trail with breathtaking mountain views. Perfect for adventure seekers and nature lovers.',
      lat: 34.0550,
      lng: -118.2420,
      imageUrls: [
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4'
      ],
      types: ['hiking', 'nature', 'adventure'],
    ),
    PlaceModel(
      id: '5',
      name: 'Historic Downtown',
      description:
          'Charming historic district with cobblestone streets, unique shops, cafes, and architectural landmarks from the 1800s.',
      lat: 34.0510,
      lng: -118.2450,
      imageUrls: [
        'https://images.unsplash.com/photo-1449824913935-59a10b8d2000'
      ],
      types: ['historic', 'shopping', 'culture'],
    ),
    PlaceModel(
      id: '6',
      name: 'Riverside Cafe',
      description:
          'Cozy cafe by the river serving artisanal coffee, fresh pastries, and light meals. Perfect spot for work or relaxation.',
      lat: 34.0530,
      lng: -118.2430,
      imageUrls: [
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb'
      ],
      types: ['cafe', 'food', 'relaxation'],
    ),
    PlaceModel(
      id: '7',
      name: 'Adventure Park',
      description:
          'Thrilling amusement park with roller coasters, water rides, and family-friendly attractions for all ages.',
      lat: 34.0490,
      lng: -118.2410,
      imageUrls: [
        'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3'
      ],
      types: ['amusement', 'family', 'adventure'],
    ),
    PlaceModel(
      id: '8',
      name: 'Botanical Gardens',
      description:
          'Lush botanical gardens featuring exotic plants, flower displays, and peaceful walking paths. A nature lover\'s paradise.',
      lat: 34.0540,
      lng: -118.2445,
      imageUrls: [
        'https://images.unsplash.com/photo-1416879595882-3373a0480b5b'
      ],
      types: ['nature', 'garden', 'relaxation'],
    ),
    PlaceModel(
      id: '9',
      name: 'Night Market',
      description:
          'Vibrant night market with street food vendors, local crafts, live music, and a lively atmosphere. Open every weekend.',
      lat: 34.0500,
      lng: -118.2425,
      imageUrls: ['https://images.unsplash.com/photo-1556911220-bff31c812dba'],
      types: ['food', 'shopping', 'nightlife'],
    ),
    PlaceModel(
      id: '10',
      name: 'Skyline Observatory',
      description:
          'Panoramic city views from the highest observation deck. Perfect for photography and experiencing the city from above.',
      lat: 34.0525,
      lng: -118.2435,
      imageUrls: [
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4'
      ],
      types: ['viewpoint', 'photography', 'city'],
    ),
    PlaceModel(
      id: '11',
      name: 'Ancient Temple Ruins',
      description:
          'Stunning ancient ruins dating back centuries. Walk among towering columns and learn about civilizations that shaped the world.',
      lat: 34.0560,
      lng: -118.2460,
      imageUrls: [
        'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb'
      ],
      types: ['historic', 'culture', 'ruins'],
    ),
    PlaceModel(
      id: '12',
      name: 'Hilltop Winery',
      description:
          'Award-winning winery set on rolling hills. Enjoy tastings, vineyard tours, and sunset views over the valley.',
      lat: 34.0580,
      lng: -118.2500,
      imageUrls: [
        'https://images.unsplash.com/photo-1506377247377-2a5b3b417ebb'
      ],
      types: ['food', 'wine', 'relaxation'],
    ),
    PlaceModel(
      id: '13',
      name: 'Ocean Aquarium',
      description:
          'Home to thousands of marine species. Walk through underwater tunnels and watch sharks glide overhead.',
      lat: 34.0470,
      lng: -118.2380,
      imageUrls: ['https://images.unsplash.com/photo-1544551763-46a013bb70d5'],
      types: ['aquarium', 'family', 'nature'],
    ),
    PlaceModel(
      id: '14',
      name: 'Medieval Castle',
      description:
          'A beautifully preserved castle with towers, courtyards, and panoramic views. Step back in time with guided tours.',
      lat: 34.0545,
      lng: -118.2475,
      imageUrls: [
        'https://images.unsplash.com/photo-1533154683220-d2afb3e52c12'
      ],
      types: ['historic', 'castle', 'architecture'],
    ),
    PlaceModel(
      id: '15',
      name: 'Hot Springs Retreat',
      description:
          'Natural thermal pools surrounded by lush forests. The perfect escape for relaxation and rejuvenation.',
      lat: 34.0600,
      lng: -118.2520,
      imageUrls: [
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d'
      ],
      types: ['nature', 'relaxation', 'spa'],
    ),
    PlaceModel(
      id: '16',
      name: 'Street Art District',
      description:
          'Vibrant neighborhood covered in colorful murals by local and international artists. A living outdoor gallery.',
      lat: 34.0505,
      lng: -118.2395,
      imageUrls: [
        'https://images.unsplash.com/photo-1499781350541-7783f6c6a0c8'
      ],
      types: ['art', 'culture', 'city'],
    ),
    PlaceModel(
      id: '17',
      name: 'Lakeside Campground',
      description:
          'Peaceful camping grounds beside a crystal-clear lake. Kayak, fish, or just sit by the fire under the stars.',
      lat: 34.0620,
      lng: -118.2550,
      imageUrls: [
        'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4'
      ],
      types: ['nature', 'camping', 'outdoors'],
    ),
    PlaceModel(
      id: '18',
      name: 'Rooftop Sky Bar',
      description:
          'Chic rooftop lounge offering craft cocktails and breathtaking city skyline views. The place to see and be seen.',
      lat: 34.0515,
      lng: -118.2415,
      imageUrls: [
        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4'
      ],
      types: ['nightlife', 'food', 'city'],
    ),
    PlaceModel(
      id: '19',
      name: 'Waterfall Canyon',
      description:
          'A hidden canyon with a majestic waterfall at its heart. The moderate hike through the gorge is half the adventure.',
      lat: 34.0570,
      lng: -118.2490,
      imageUrls: [
        'https://images.unsplash.com/photo-1432405972618-c6b0cfba8051'
      ],
      types: ['nature', 'hiking', 'water'],
    ),
    PlaceModel(
      id: '20',
      name: 'Science Discovery Center',
      description:
          'Interactive museum with hands-on exhibits about space, physics, and biology. Fun for curious minds of all ages.',
      lat: 34.0495,
      lng: -118.2405,
      imageUrls: [
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d'
      ],
      types: ['museum', 'family', 'science'],
    ),
    PlaceModel(
      id: '21',
      name: 'Floating Market',
      description:
          'Colorful boats laden with fresh produce, spices, and street food. A feast for the senses on the water.',
      lat: 34.0480,
      lng: -118.2365,
      imageUrls: ['https://images.unsplash.com/photo-1555939594-58d7cb561ad1'],
      types: ['food', 'shopping', 'culture'],
    ),
    PlaceModel(
      id: '22',
      name: 'Glacier Viewpoint',
      description:
          'Jaw-dropping views of ancient glaciers and ice-blue lakes. Accessible via a scenic mountain road.',
      lat: 34.0640,
      lng: -118.2580,
      imageUrls: [
        'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5'
      ],
      types: ['nature', 'viewpoint', 'adventure'],
    ),
    PlaceModel(
      id: '23',
      name: 'Lighthouse Point',
      description:
          'Historic coastal lighthouse perched on dramatic sea cliffs. Watch waves crash and spot whales during migration season.',
      lat: 34.0460,
      lng: -118.2350,
      imageUrls: [
        'https://images.unsplash.com/photo-1501785888041-af3ef285b470'
      ],
      types: ['historic', 'nature', 'coast'],
    ),
    PlaceModel(
      id: '24',
      name: 'Underground Caves',
      description:
          'Explore vast underground chambers filled with stunning stalactites and underground rivers lit by soft light.',
      lat: 34.0555,
      lng: -118.2510,
      imageUrls: [
        'https://images.unsplash.com/photo-1504893524553-b855bce32c67'
      ],
      types: ['nature', 'adventure', 'geology'],
    ),
    PlaceModel(
      id: '25',
      name: 'Zen Garden Park',
      description:
          'Tranquil Japanese-inspired garden with koi ponds, bamboo groves, raked sand patterns, and meditation pavilions.',
      lat: 34.0535,
      lng: -118.2455,
      imageUrls: [
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b'
      ],
      types: ['nature', 'garden', 'relaxation'],
    ),
    PlaceModel(
      id: '26',
      name: 'Crystal Ice Cave',
      description: 'Explore the shimmering blue ice formations hidden beneath a massive glacier. A surreal natural wonder.',
      lat: 64.1466,
      lng: -21.9426,
      imageUrls: ['https://images.unsplash.com/photo-1517621111664-9b57be2cc92c'],
      types: ['nature', 'adventure', 'cave'],
    ),
    PlaceModel(
      id: '27',
      name: 'Desert Oasis',
      description: 'A lush pocket of palm trees and natural springs rising out of the sweeping desert dunes.',
      lat: 25.0,
      lng: 55.0,
      imageUrls: ['https://images.unsplash.com/photo-1543336306-25f0bbcc6711'],
      types: ['nature', 'oasis', 'desert'],
    ),
    PlaceModel(
      id: '28',
      name: 'Old Town Square',
      description: 'The historic heart of the city, surrounded by colorful baroque buildings and featuring an astronomical clock.',
      lat: 50.0878,
      lng: 14.4205,
      imageUrls: ['https://images.unsplash.com/photo-1513076891104-5ba60dbf0514'],
      types: ['historic', 'city', 'culture'],
    ),
    PlaceModel(
      id: '29',
      name: 'Hanging Bridge',
      description: 'A thrilling suspension bridge swaying above a deep green canopy. Not for the faint of heart!',
      lat: 10.0,
      lng: -84.0,
      imageUrls: ['https://images.unsplash.com/photo-1533221307525-2c8c4f90d16c'],
      types: ['adventure', 'nature', 'bridge'],
    ),
    PlaceModel(
      id: '30',
      name: 'Coral Reef Snorkeling',
      description: 'Dive into warm, clear waters to swim alongside sea turtles and thousands of colorful fish.',
      lat: -16.0,
      lng: 145.0,
      imageUrls: ['https://images.unsplash.com/photo-1544551763-92ab472cad5d'],
      types: ['water', 'adventure', 'nature'],
    ),
    PlaceModel(
      id: '31',
      name: 'Neon Cyberpunk District',
      description: 'A bustling neighborhood that comes alive at night with towering neon signs and futuristic arcades.',
      lat: 35.6983,
      lng: 139.7731,
      imageUrls: ['https://images.unsplash.com/photo-1540959733332-eab4deabeeaf'],
      types: ['city', 'nightlife', 'culture'],
    ),
    PlaceModel(
      id: '32',
      name: 'Alpine Ski Resort',
      description: 'World-class slopes surrounded by snow-capped peaks. Cozy chalets and hot cocoa await after a long day.',
      lat: 46.0,
      lng: 7.0,
      imageUrls: ['https://images.unsplash.com/photo-1551524164-687a55dd1126'],
      types: ['sport', 'snow', 'resort'],
    ),
    PlaceModel(
      id: '33',
      name: 'Tropical Rainforest Reserve',
      description: 'Immerse yourself in biodiversity. Spot rare birds and monkeys on a guided trek through the jungle.',
      lat: -3.0,
      lng: -60.0,
      imageUrls: ['https://images.unsplash.com/photo-1518182170546-076616fdfaaf'],
      types: ['nature', 'forest', 'wildlife'],
    ),
    PlaceModel(
      id: '34',
      name: 'Geothermal Spa',
      description: 'Relax in milky-blue waters naturally heated by volcanic activity. Includes silica mud masks and steam rooms.',
      lat: 63.8804,
      lng: -22.4495,
      imageUrls: ['https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d'],
      types: ['relaxation', 'spa', 'nature'],
    ),
    PlaceModel(
      id: '35',
      name: 'Space Observatory',
      description: 'Peer into deep space through massive telescopes. Enjoy planetarium shows and astronomy lectures.',
      lat: 34.1341,
      lng: -118.3004,
      imageUrls: ['https://images.unsplash.com/photo-1446776811953-b23d57bd21aa'],
      types: ['science', 'viewpoint', 'museum'],
    ),
    PlaceModel(
      id: '36',
      name: 'Majestic Fjord',
      description: 'Cruise through steep cliffs diving into deep blue water. Spectacular waterfalls dot the landscape.',
      lat: 61.0,
      lng: 6.0,
      imageUrls: ['https://images.unsplash.com/photo-1476611317561-60117649dd94'],
      types: ['nature', 'water', 'viewpoint'],
    ),
    PlaceModel(
      id: '37',
      name: 'Bustling Bazaar',
      description: 'A labyrinth of stalls selling spices, textiles, and jewelry. Hone your bargaining skills!',
      lat: 41.0115,
      lng: 28.9669,
      imageUrls: ['https://images.unsplash.com/photo-1533618167822-13203fcf93ba'],
      types: ['shopping', 'culture', 'market'],
    ),
    PlaceModel(
      id: '38',
      name: 'Gothic Cathedral',
      description: 'A masterpiece of architecture featuring soaring spires, flying buttresses, and intricate stained glass.',
      lat: 48.8529,
      lng: 2.3499,
      imageUrls: ['https://images.unsplash.com/photo-1548625361-ec85302826db'],
      types: ['historic', 'architecture', 'religion'],
    ),
    PlaceModel(
      id: '39',
      name: 'Active Volcano Crater',
      description: 'Take a guided hike to the rim of a smoking volcano. Feel the heat of the earth and smell the sulfur.',
      lat: 19.4,
      lng: -155.2,
      imageUrls: ['https://images.unsplash.com/photo-1518105779142-d975f22f1b0a'],
      types: ['nature', 'adventure', 'hiking'],
    ),
    PlaceModel(
      id: '40',
      name: 'Glass Floor Skywalk',
      description: 'Walk on transparent glass hundreds of feet above a plunging canyon. An exhilarating view down!',
      lat: 36.0,
      lng: -113.0,
      imageUrls: ['https://images.unsplash.com/photo-1522069169874-c58ced4e0da0'],
      types: ['adventure', 'viewpoint', 'nature'],
    ),
    PlaceModel(
      id: '41',
      name: 'Cherry Blossom Walk',
      description: 'A scenic path lined with hundreds of cherry trees. Stunning pink petals rain down in spring.',
      lat: 35.0,
      lng: 135.0,
      imageUrls: ['https://images.unsplash.com/photo-1522383225653-ed111181a951'],
      types: ['nature', 'park', 'relaxation'],
    ),
    PlaceModel(
      id: '42',
      name: 'Undersea Restaurant',
      description: 'Dine in luxury inside a transparent glass dome surrounded by the vibrant marine life of a coral reef.',
      lat: 3.0,
      lng: 73.0,
      imageUrls: ['https://images.unsplash.com/photo-1514361892635-6b07e31e75f3'],
      types: ['food', 'unique', 'water'],
    ),
    PlaceModel(
      id: '43',
      name: 'Cliffside Village',
      description: 'Pastel-colored houses clinging to steep cliffs overlooking a sapphire sea. Perfect for romantic walks.',
      lat: 40.6,
      lng: 14.4,
      imageUrls: ['https://images.unsplash.com/photo-1516483638261-f40889eba30e'],
      types: ['city', 'viewpoint', 'romantic'],
    ),
    PlaceModel(
      id: '44',
      name: 'Megacity Train Hub',
      description: 'An architectural marvel of glass and steel where millions commute. Contains endless shops and cafes.',
      lat: 40.75,
      lng: -73.99,
      imageUrls: ['https://images.unsplash.com/photo-1473280025148-643f9b0cbac2'],
      types: ['city', 'architecture', 'transport'],
    ),
    PlaceModel(
      id: '45',
      name: 'Secluded Lagoon',
      description: 'A hidden cove accessible only by boat. Turquoise waters surrounded by towering limestone karsts.',
      lat: 9.9,
      lng: 118.9,
      imageUrls: ['https://images.unsplash.com/photo-1502082553048-f009c37129b9'],
      types: ['beach', 'water', 'nature'],
    ),
    PlaceModel(
      id: '46',
      name: 'Safari Grasslands',
      description: 'Vast open plains where you can spot lions, elephants, and giraffes in their natural habitat.',
      lat: -2.0,
      lng: 34.0,
      imageUrls: ['https://images.unsplash.com/photo-1516426122078-c23e76319801'],
      types: ['nature', 'wildlife', 'safari'],
    ),
    PlaceModel(
      id: '47',
      name: 'Ancient Colosseum',
      description: 'The iconic ruined amphitheater where gladiators once fought. A testament to the engineering of the past.',
      lat: 41.8902,
      lng: 12.4922,
      imageUrls: ['https://images.unsplash.com/photo-1552832233-fa4e995ab17c'],
      types: ['historic', 'architecture', 'ruins'],
    ),
    PlaceModel(
      id: '48',
      name: 'High-Speed Theme Park',
      description: 'Features the fastest roller coasters in the world and cutting-edge virtual reality attractions.',
      lat: 25.0,
      lng: 55.0,
      imageUrls: ['https://images.unsplash.com/photo-1515093796590-dbfb2b75fcfa'],
      types: ['amusement', 'adventure', 'family'],
    ),
    PlaceModel(
      id: '49',
      name: 'Floating Lantern Festival',
      description: 'A mesmerizing event where thousands of paper lanterns are released into the night sky over a tranquil river.',
      lat: 18.7,
      lng: 98.9,
      imageUrls: ['https://images.unsplash.com/photo-1498005391690-67520e542ef9'],
      types: ['culture', 'festival', 'nightlife'],
    ),
    PlaceModel(
      id: '50',
      name: 'Ice Hotel',
      description: 'A stunning structure built entirely of snow and ice, rebuilt every winter with unique icy sculptures.',
      lat: 67.8,
      lng: 20.2,
      imageUrls: ['https://images.unsplash.com/photo-1483325608035-77ee840fb2c5'],
      types: ['unique', 'hotel', 'snow'],
    ),
    PlaceModel(
      id: '51',
      name: 'Jazz Club Alley',
      description: 'A narrow, dimly-lit street famous for its authentic underground jazz clubs and speakeasy bars.',
      lat: 29.95,
      lng: -90.06,
      imageUrls: ['https://images.unsplash.com/photo-1511192336575-5a79af67a629'],
      types: ['nightlife', 'music', 'culture'],
    ),
  ];
}
