import '../../../common/models/place_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class PlacesRepository {
  PlacesRepository();

  Future<List<PlaceModel>> loadNearbyPlaces(double lat, double lng, {
    double radius = 10.0,
    List<String>? tags,
    bool useMock = false,
  }) async {
    if (useMock) return _mockPlaces;
    // Example simple Firestore logic for places within radius
    final query = await FirebaseFirestore.instance
      .collection('places')
      .get();
    return query.docs
      .map((doc) => PlaceModel.fromJson(doc.data()))
      .where((place) {
        // Simple radius filter
        final double dx = place.lat - lat;
        final double dy = place.lng - lng;
        final dist = sqrt(dx * dx + dy * dy);
        final matchesTags = tags == null || tags.every((t) => place.tags.contains(t));
        return dist < radius && matchesTags;
      }).toList();
  }

  Future<PlaceModel?> getPlaceById(String id, {bool useMock = false}) async {
    if (useMock) {
      return _mockPlaces.firstWhere(
        (place) => place.id == id,
        orElse: () => _mockPlaces.first,
      );
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('places')
          .doc(id)
          .get();
      if (doc.exists) {
        return PlaceModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static const List<PlaceModel> _mockPlaces = [
    PlaceModel(
      id: '1',
      name: 'Grand Park',
      description: 'A beautiful green park.',
      lat: 34.0522,
      lng: -118.2437,
      images: ['https://example.com/park.jpg'],
      tags: ['nature', 'outdoors'],
    ),
    PlaceModel(
      id: '2',
      name: 'City Art Museum',
      description: 'Modern + classic art exhibits.',
      lat: 34.0523,
      lng: -118.2438,
      images: ['https://example.com/museum.jpg'],
      tags: ['art', 'museum'],
    ),
  ];
}
