import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/core/constants/popular_cities.dart';
import 'package:swipetrip/features/swipe/data/places_repository.dart';

Map<String, dynamic> _curated(String id,
        {int popularity = 10,
        String status = 'active',
        String cityId = 'pt_lisbon'}) =>
    {
      'id': id,
      'source': 'wikidata',
      'cityId': cityId,
      'status': status,
      'name': 'Belém Tower',
      'description': 'A fortified tower.',
      'names': {'en': 'Belém Tower', 'de': 'Torre de Belém'},
      'descriptions': {'en': 'A fortified tower.', 'de': 'Ein Wehrturm.'},
      'wikipediaUrls': {
        'en': 'https://en.wikipedia.org/wiki/Bel%C3%A9m_Tower',
        'de': 'https://de.wikipedia.org/wiki/Torre_de_Bel%C3%A9m',
      },
      'lat': 38.69,
      'lng': -9.21,
      'types': ['historical_landmark'],
      'interests': ['history'],
      'popularity': popularity,
      'imageUrls': ['https://img.test/a.webp'],
      'photos': [
        {
          'publicUrl': 'https://img.test/a.webp',
          'creator': 'Jane',
          'licenseName': 'CC BY-SA 4.0'
        },
      ],
    };

void main() {
  group('PlaceModel languages', () {
    final place = PlaceModel.fromJson(_curated('wd_Q1'));

    test('picks name and description in the app language', () {
      expect(place.nameFor('de'), 'Torre de Belém');
      expect(place.descriptionFor('de'), 'Ein Wehrturm.');
      expect(place.wikipediaUrlFor('de'), contains('de.wikipedia.org'));
    });

    test('falls back to the default text for other languages', () {
      expect(place.nameFor('fr'), 'Belém Tower');
      expect(place.descriptionFor('fr'), 'A fortified tower.');
      expect(place.wikipediaUrlFor('fr'), contains('en.wikipedia.org'));
    });

    test('reads opening hours, website and the OSM source', () {
      final osm = PlaceModel.fromJson({
        ..._curated('wd_Q5'),
        'openingHours': 'Tu-Su 10:00-18:00',
        'website': 'https://torre.example/',
        'osmUrl': 'https://www.openstreetmap.org/way/11',
        'address': 'Avenida Brasília, Lisboa',
      });
      expect(osm.openingHours, 'Tu-Su 10:00-18:00');
      expect(osm.website, 'https://torre.example/');
      expect(osm.osmUrl, contains('openstreetmap.org'));
      expect(osm.address, 'Avenida Brasília, Lisboa');
      expect(place.openingHours, isNull);
      expect(place.osmUrl, isNull);
    });

    test('older documents without languages still work', () {
      final legacy =
          PlaceModel.fromJson({'id': 'p', 'name': 'Park', 'lat': 0, 'lng': 0});
      expect(legacy.nameFor('de'), 'Park');
      expect(legacy.descriptionFor('de'), isNull);
      expect(legacy.wikipediaUrlFor('de'), isNull);
    });
  });

  test('nearest popular city within a radius', () {
    expect(PopularCity.nearest(38.71, -9.13, maxKm: 50)?.id, 'pt_lisbon');
    expect(PopularCity.nearest(0, 0, maxKm: 50), isNull);
  });

  group('curated places', () {
    late FakeFirebaseFirestore db;
    late PlacesRepository repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = PlacesRepository(firestore: db);
      await db
          .collection('places')
          .doc('wd_Q1')
          .set(_curated('wd_Q1', popularity: 50));
      await db
          .collection('places')
          .doc('wd_Q2')
          .set(_curated('wd_Q2', popularity: 90));
      await db
          .collection('places')
          .doc('wd_Q3')
          .set(_curated('wd_Q3', status: 'hidden'));
      await db
          .collection('places')
          .doc('wd_Q4')
          .set(_curated('wd_Q4', cityId: 'de_berlin'));
    });

    test('loads the active places of one city, best-known first', () async {
      final places = await repo.loadCityPlaces('pt_lisbon');
      expect(places.map((p) => p.id), ['wd_Q2', 'wd_Q1']);
    });

    test('group pools come from the curated city when it has places', () async {
      const lisbon = GroupLocation(
        countryCode: 'PT',
        countryName: 'Portugal',
        cityId: 'lisbon',
        cityName: 'Lisbon',
        lat: 38.72,
        lng: -9.14,
      );
      expect(PlacesRepository.curatedCityId(lisbon), 'pt_lisbon');
      final pool = await repo.fetchPlacesForCity(lisbon, limit: 5);
      expect(pool.map((p) => p.id).toSet(), {'wd_Q1', 'wd_Q2'});
    });
  });
}
