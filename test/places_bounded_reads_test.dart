// Firestore mocks implement its sealed query classes, as test doubles do.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/features/swipe/data/places_repository.dart';

class _MockDb extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockSnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

// Berlin centre and a point 20 km south-east of it.
const _berlinLat = 52.5200, _berlinLng = 13.4050;

Future<void> _addPlace(
  FakeFirebaseFirestore db,
  String id, {
  required String cityId,
  double lat = _berlinLat,
  double lng = _berlinLng,
  String? status = 'active',
  int popularity = 100,
}) =>
    db.collection('places').doc(id).set({
      'id': id,
      'name': id,
      'lat': lat,
      'lng': lng,
      'cityId': cityId,
      if (status != null) 'status': status,
      'popularity': popularity,
    });

void main() {
  group('nearest curated city', () {
    test('picks the closest city within radius plus reach', () {
      expect(
        PlacesRepository.nearestCityId(52.40, 13.55, radiusKm: 10),
        'de_berlin',
      );
    });

    test('a city just beyond the radius still counts via cityReachKm', () {
      // About 25 km from the Berlin centre, radius 10 km.
      expect(
        PlacesRepository.nearestCityId(52.30, 13.40, radiusKm: 10),
        'de_berlin',
      );
    });

    test('no city in the middle of nowhere', () {
      // North Atlantic.
      expect(PlacesRepository.nearestCityId(45.0, -30.0, radiusKm: 100),
          isNull);
    });
  });

  group('loadPlacesAround / loadNearbyPlaces', () {
    test('GPS mode loads only the nearest city, filtered by distance',
        () async {
      final db = FakeFirebaseFirestore();
      await _addPlace(db, 'near', cityId: 'de_berlin');
      await _addPlace(db, 'far', cityId: 'de_berlin', lat: 53.5, lng: 13.4);
      await _addPlace(db, 'lisbon', cityId: 'pt_lisbon', lat: 38.72, lng: -9.14);

      final repo = PlacesRepository(firestore: db);
      final places = await repo.loadPlacesAround(
          lat: _berlinLat, lng: _berlinLng, radiusKm: 25);
      expect(places.map((p) => p.id), ['near']);
    });

    test('falls back to the legacy cache of that city only', () async {
      final db = FakeFirebaseFirestore();
      await _addPlace(db, 'legacy', cityId: 'DE_berlin', status: null);
      await _addPlace(db, 'other', cityId: 'PT_lisbon', status: null);

      final places = await PlacesRepository(firestore: db)
          .loadNearbyPlaces(_berlinLat, _berlinLng);
      expect(places.map((p) => p.id), ['legacy']);
    });

    test('empty, not a full scan, when no curated city is near', () async {
      final db = FakeFirebaseFirestore();
      await _addPlace(db, 'ocean', cityId: 'x', lat: 45.0, lng: -30.0);

      final places =
          await PlacesRepository(firestore: db).loadNearbyPlaces(45.0, -30.0);
      expect(places, isEmpty);
    });

    test('never issues an unbounded query on the places collection',
        () async {
      final db = _MockDb();
      final collection = _MockCollection();
      final query = _MockQuery();
      final snapshot = _MockSnapshot();
      when(() => db.collection('places')).thenReturn(collection);
      when(() => collection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(query);
      when(() => query.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(query);
      when(() => query.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(query);
      when(() => query.limit(any())).thenReturn(query);
      when(() => snapshot.docs).thenReturn([]);
      when(() => query.get()).thenAnswer((_) async => snapshot);

      final repo = PlacesRepository(firestore: db);
      await repo.loadNearbyPlaces(_berlinLat, _berlinLng);
      await repo.loadNearbyPlaces(45.0, -30.0);
      await repo.loadPlacesAround(
          cityId: 'pt_lisbon', lat: 38.72, lng: -9.14, radiusKm: 50);

      verifyNever(() => collection.get());
      // Curated + legacy query for each of the two cities.
      verify(() => query.limit(any())).called(4);
      verify(() => query.get()).called(4);
    });
  });

  group('city cache', () {
    test('home feed and deck share one query per city', () async {
      final db = _MockDb();
      final collection = _MockCollection();
      final query = _MockQuery();
      final snapshot = _MockSnapshot();
      when(() => db.collection('places')).thenReturn(collection);
      when(() => collection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(query);
      when(() => query.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(query);
      when(() => query.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(query);
      when(() => query.limit(any())).thenReturn(query);
      when(() => snapshot.docs).thenReturn([]);
      when(() => query.get()).thenAnswer((_) async => snapshot);

      final repo = PlacesRepository(firestore: db);
      await Future.wait([
        repo.loadCityPlaces('de_berlin'),
        repo.loadCityPlaces('de_berlin'),
      ]);
      verify(() => query.get()).called(1);

      await repo.loadCityPlaces('de_berlin', refresh: true);
      verify(() => query.get()).called(1);

      repo.clearCityCache();
      await repo.loadCityPlaces('de_berlin');
      verify(() => query.get()).called(1);
    });

    test('a failed load is not cached', () async {
      final db = _MockDb();
      final collection = _MockCollection();
      final query = _MockQuery();
      final snapshot = _MockSnapshot();
      when(() => db.collection('places')).thenReturn(collection);
      when(() => collection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(query);
      when(() => query.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(query);
      when(() => query.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(query);
      when(() => query.limit(any())).thenReturn(query);
      when(() => snapshot.docs).thenReturn([]);
      when(() => query.get()).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));

      final repo = PlacesRepository(firestore: db);
      await expectLater(
          repo.loadCityPlaces('de_berlin'), throwsA(isA<FirebaseException>()));

      when(() => query.get()).thenAnswer((_) async => snapshot);
      expect(await repo.loadCityPlaces('de_berlin'), isEmpty);
    });
  });
}
