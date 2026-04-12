import '../../../common/models/place_model.dart';
import '../../../common/models/swipe_result_model.dart';
import '../../../common/utils/geo_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlacesRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  PlacesRepository();

  Future<List<PlaceModel>> loadNearbyPlaces(double lat, double lng, {
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
          lat, lng, 
          place.lat, place.lng, 
          radiusKm,
        );
        final matchesTags = tags == null || tags.every((t) => place.tags.contains(t));
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
      description: 'A beautiful green park perfect for picnics, jogging, and family outings. Features walking trails, playgrounds, and scenic views.',
      lat: 34.0522,
      lng: -118.2437,
      images: ['https://images.unsplash.com/photo-1441974231531-c6227db76b6e'],
      tags: ['nature', 'outdoors', 'park'],
    ),
    PlaceModel(
      id: '2',
      name: 'City Art Museum',
      description: 'Modern and classic art exhibits featuring works from renowned artists. Perfect for art enthusiasts and cultural experiences.',
      lat: 34.0523,
      lng: -118.2438,
      images: ['https://images.unsplash.com/photo-1541961017774-22349e4a1262'],
      tags: ['art', 'museum', 'culture'],
    ),
    PlaceModel(
      id: '3',
      name: 'Sunset Beach',
      description: 'Pristine sandy beach with crystal clear waters. Ideal for swimming, sunbathing, and watching beautiful sunsets.',
      lat: 34.0489,
      lng: -118.2440,
      images: ['https://images.unsplash.com/photo-1507525428034-b723cf961d3e'],
      tags: ['beach', 'outdoors', 'water'],
    ),
    PlaceModel(
      id: '4',
      name: 'Mountain Trail',
      description: 'Challenging hiking trail with breathtaking mountain views. Perfect for adventure seekers and nature lovers.',
      lat: 34.0550,
      lng: -118.2420,
      images: ['https://images.unsplash.com/photo-1506905925346-21bda4d32df4'],
      tags: ['hiking', 'nature', 'adventure'],
    ),
    PlaceModel(
      id: '5',
      name: 'Historic Downtown',
      description: 'Charming historic district with cobblestone streets, unique shops, cafes, and architectural landmarks from the 1800s.',
      lat: 34.0510,
      lng: -118.2450,
      images: ['https://images.unsplash.com/photo-1449824913935-59a10b8d2000'],
      tags: ['historic', 'shopping', 'culture'],
    ),
    PlaceModel(
      id: '6',
      name: 'Riverside Cafe',
      description: 'Cozy cafe by the river serving artisanal coffee, fresh pastries, and light meals. Perfect spot for work or relaxation.',
      lat: 34.0530,
      lng: -118.2430,
      images: ['https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb'],
      tags: ['cafe', 'food', 'relaxation'],
    ),
    PlaceModel(
      id: '7',
      name: 'Adventure Park',
      description: 'Thrilling amusement park with roller coasters, water rides, and family-friendly attractions for all ages.',
      lat: 34.0490,
      lng: -118.2410,
      images: ['https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3'],
      tags: ['amusement', 'family', 'adventure'],
    ),
    PlaceModel(
      id: '8',
      name: 'Botanical Gardens',
      description: 'Lush botanical gardens featuring exotic plants, flower displays, and peaceful walking paths. A nature lover\'s paradise.',
      lat: 34.0540,
      lng: -118.2445,
      images: ['https://images.unsplash.com/photo-1416879595882-3373a0480b5b'],
      tags: ['nature', 'garden', 'relaxation'],
    ),
    PlaceModel(
      id: '9',
      name: 'Night Market',
      description: 'Vibrant night market with street food vendors, local crafts, live music, and a lively atmosphere. Open every weekend.',
      lat: 34.0500,
      lng: -118.2425,
      images: ['https://images.unsplash.com/photo-1556911220-bff31c812dba'],
      tags: ['food', 'shopping', 'nightlife'],
    ),
    PlaceModel(
      id: '10',
      name: 'Skyline Observatory',
      description: 'Panoramic city views from the highest observation deck. Perfect for photography and experiencing the city from above.',
      lat: 34.0525,
      lng: -118.2435,
      images: ['https://images.unsplash.com/photo-1506905925346-21bda4d32df4'],
      tags: ['viewpoint', 'photography', 'city'],
    ),
  ];
}
