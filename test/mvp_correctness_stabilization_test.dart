import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/app/routes.dart';
import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/features/swipe/data/places_repository.dart';
import 'package:swipetrip/main.dart' as app_main;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 MVP correctness stabilization', () {
    test('favorites load places directly by favorite place IDs in order',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repository = PlacesRepository(firestore: firestore);

      final eiffelTower = PlaceModel(
        id: 'places/eiffel',
        name: 'Eiffel Tower',
        lat: 48.8584,
        lng: 2.2945,
        cityId: 'fr_paris',
      );
      final louvre = PlaceModel(
        id: 'places/louvre',
        name: 'Louvre Museum',
        lat: 48.8606,
        lng: 2.3376,
        cityId: 'fr_paris',
      );
      final outsideRadius = PlaceModel(
        id: 'places/tokyo-tower',
        name: 'Tokyo Tower',
        lat: 35.6586,
        lng: 139.7454,
        cityId: 'jp_tokyo',
      );

      await firestore
          .collection('places')
          .doc(eiffelTower.id)
          .set(eiffelTower.toJson());
      await firestore.collection('places').doc(louvre.id).set(louvre.toJson());
      await firestore
          .collection('places')
          .doc(outsideRadius.id)
          .set(outsideRadius.toJson());

      final places = await repository.loadPlacesByIds([
        outsideRadius.id,
        'places/missing',
        eiffelTower.id,
      ]);

      expect(
        places.map((place) => place.id),
        equals([outsideRadius.id, eiffelTower.id]),
      );
    });

    test('active sessions still allow intentional navigation to app sections',
        () {
      expect(isActiveSessionRouteAllowed('/swipe/group-a'), isTrue);
      expect(isActiveSessionRouteAllowed('/group-matches/group-a'), isTrue);
      expect(isActiveSessionRouteAllowed('/profile'), isTrue);
      expect(isActiveSessionRouteAllowed('/settings'), isTrue);
      expect(isActiveSessionRouteAllowed('/favorites'), isTrue);
      expect(isActiveSessionRouteAllowed('/group'), isTrue);
      expect(isActiveSessionRouteAllowed('/group/join'), isTrue);

      expect(isActiveSessionRouteAllowed('/home'), isFalse);
      expect(isActiveSessionRouteAllowed('/place/places-eiffel'), isFalse);
    });

    test('bootstrap initializes Env before Firebase reads configuration',
        () async {
      final calls = <String>[];

      await app_main.bootstrapApp(
        initializeEnv: () async => calls.add('env'),
        initializeFirebase: () async => calls.add('firebase'),
        runApplication: (Widget app) => calls.add('runApp'),
      );

      expect(calls, equals(['env', 'firebase', 'runApp']));
    });
  });
}
