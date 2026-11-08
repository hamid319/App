import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/common/utils/geohash.dart';
import 'package:swipetrip/features/swipe/data/places_repository.dart';

void main() {
  test('geohash matches the import (tools/city-import/test/tiles.test.ts)', () {
    expect(geohash(57.64911, 10.40744, 11), 'u4pruydqqvj');
    expect(geohash(52.52, 13.405), 'u33dc');
    final around = geohashesAround(52.52, 13.405);
    expect(around, hasLength(9));
    expect(around, contains('u33dc'));
  });

  test('near the user: city list plus tiles, nearby and known first', () async {
    final db = FakeFirebaseFirestore();
    // City-wide top list: a famous sight 6 km away.
    await db.collection('places').doc('famous').set({
      'id': 'famous',
      'name': 'Famous',
      'lat': 52.52,
      'lng': 13.49,
      'cityId': 'de_berlin',
      'status': 'active',
      'popularity': 990,
    });
    // Tile around the user: a bar next door, a duplicate of the famous
    // sight (the full doc wins) and a place outside the radius.
    await db.collection('placeTiles').doc('de_berlin_u33dc').set({
      'cityId': 'de_berlin',
      'places': [
        {
          'id': 'bar',
          'name': 'Bar',
          'lat': 52.5205,
          'lng': 13.4055,
          'kind': 'venue',
          'popularity': 400,
        },
        {
          'id': 'famous',
          'name': 'Tile copy',
          'lat': 52.52,
          'lng': 13.49,
          'popularity': 990,
        },
      ],
    });
    final repo = PlacesRepository(firestore: db);
    final near =
        await repo.loadPlacesAround(lat: 52.52, lng: 13.405, radiusKm: 10);
    expect(near.map((p) => p.id), ['bar', 'famous']);
    expect(near.last.name, 'Famous');
    expect(near.first.isVenue, isTrue);

    final small =
        await repo.loadPlacesAround(lat: 52.52, lng: 13.405, radiusKm: 2);
    expect(small.map((p) => p.id), ['bar']);

    // A chosen city keeps its own top list, no tiles.
    final city = await repo.loadPlacesAround(
        cityId: 'de_berlin', lat: 52.52, lng: 13.405, radiusKm: 10);
    expect(city.map((p) => p.id), ['famous']);
  });

  test('rankByRelevance weighs popularity against distance', () {
    PlaceModel place(String id, double lng, int popularity) => PlaceModel(
        id: id, name: id, lat: 52.52, lng: lng, popularity: popularity);
    final ranked = rankByRelevance(
        [place('far', 13.6, 990), place('close', 13.406, 300)], 52.52, 13.405);
    expect(ranked.map((p) => p.id), ['close', 'far']);
  });
}
