// Firestore mocks implement its sealed query classes, as test doubles do.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/common/models/interest.dart';
import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/common/utils/opening_hours_format.dart';
import 'package:swipetrip/common/utils/place_type_labels.dart';
import 'package:swipetrip/features/home/logic/home_feed_controller.dart';
import 'package:swipetrip/features/swipe/data/places_repository.dart';
import 'package:swipetrip/features/swipe/logic/swipe_controller.dart';
import 'package:swipetrip/l10n/app_localizations_de.dart';

class _MockDb extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

PlaceModel _sight(int rank, {int? popularity}) => PlaceModel(
      id: 's$rank',
      name: 'Sight $rank',
      lat: 0,
      lng: 0,
      popularity: popularity ?? 2000 - rank,
    );

PlaceModel _venue(String id, String? hours, {int popularity = 100}) =>
    PlaceModel(
      id: id,
      name: id,
      lat: 0,
      lng: 0,
      kind: PlaceKind.venue,
      types: const ['bar'],
      popularity: popularity,
      openingHours: hours,
    );

/// Friday, 23 October 2026.
final _friday = DateTime(2026, 10, 23, 12);

bool? _tonight(String? hours, [DateTime? day]) => isOpenBetween(
      hours,
      day: day ?? _friday,
      fromMinutes: tonightFrom,
      toMinutes: tonightTo,
    );

void main() {
  group('PlaceModel kind, popularity, cuisine', () {
    test('venue fields are parsed', () {
      final place = PlaceModel.fromJson({
        'id': 'osm_node_1',
        'name': 'Zur Linde',
        'lat': 52.5,
        'lng': 13.4,
        'kind': 'venue',
        'types': ['pub'],
        'popularity': 312,
        'cuisine': ' german ',
      });
      expect(place.kind, PlaceKind.venue);
      expect(place.isVenue, isTrue);
      expect(place.popularity, 312);
      expect(place.cuisine, 'german');
    });

    test('missing or odd values fall back safely', () {
      final place = PlaceModel.fromJson({
        'id': 'wd_Q1',
        'name': 'Tower',
        'lat': 0,
        'lng': 0,
        'kind': 'something-else',
        'popularity': '980',
        'cuisine': '',
      });
      expect(place.kind, PlaceKind.sight);
      expect(place.popularity, 980);
      expect(place.cuisine, isNull);
      expect(
        PlaceModel.fromJson({'id': 'a', 'name': 'A', 'lat': 0, 'lng': 0})
            .popularity,
        isNull,
      );
      expect(
        PlaceModel.fromJson(
                {'id': 'a', 'name': 'A', 'lat': 0, 'lng': 0, 'popularity': 9.6})
            .popularity,
        10,
      );
    });

    test('toJson keeps the new fields round-trip', () {
      final venue = _venue('v', null).copyWith(name: 'Renamed');
      final back = PlaceModel.fromJson(venue.toJson());
      expect(back.isVenue, isTrue);
      expect(back.popularity, 100);
      expect(back.name, 'Renamed');
      expect(_sight(1).toJson()['kind'], 'sight');
    });
  });

  test('food and pub interests match venue types; labels exist', () {
    final pub = _venue('p', null).copyWith(types: ['pub']);
    final cafe = _venue('c', null).copyWith(types: ['cafe']);
    expect(placeMatchesInterests(pub, {Interest.nightlife}), isTrue);
    expect(placeMatchesInterests(cafe, {Interest.food}), isTrue);
    expect(placeMatchesInterests(pub, {Interest.food}), isFalse);
    final de = AppLocalizationsDe();
    expect(placeTypeLabel(de, 'pub'), 'Kneipe');
    expect(placeTypeLabel(de, 'biergarten'), 'Biergarten');
  });

  test('solo deck never shows venues', () {
    final deck = soloDeckCandidates([_sight(1), _venue('v', null), _sight(2)]);
    expect(deck.map((p) => p.id), ['s1', 's2']);
  });

  group('must-sees', () {
    test('top 10 by popularity, unranked last', () {
      final sights = [
        for (var i = 15; i >= 1; i--) _sight(i),
        const PlaceModel(id: 'none', name: 'No rank', lat: 0, lng: 0),
      ];
      final mustSees = selectMustSees(sights);
      expect(mustSees.map((p) => p.id), [for (var i = 1; i <= 10; i++) 's$i']);
      expect(rankByPopularity(sights).last.id, 'none');
    });

    test('ties keep the query order', () {
      final a = _sight(1, popularity: 5), b = _sight(2, popularity: 5);
      expect(rankByPopularity([b, a]).map((p) => p.id), ['s2', 's1']);
    });
  });

  group('hidden gems', () {
    final big = [for (var i = 1; i <= 40; i++) _sight(i)];

    test('only places ranked below the top 20', () {
      final gems = selectHiddenGems(big, day: _friday);
      expect(gems, hasLength(20));
      final ranks = gems.map((p) => int.parse(p.id.substring(1)));
      expect(ranks.every((r) => r > 20), isTrue);
    });

    test('same order all day, a new order the next day', () {
      final morning = selectHiddenGems(big, day: DateTime(2026, 10, 24, 7));
      final evening = selectHiddenGems(big, day: DateTime(2026, 10, 24, 23));
      final nextDay = selectHiddenGems(big, day: DateTime(2026, 10, 25, 7));
      expect(morning.map((p) => p.id), evening.map((p) => p.id));
      expect(morning.map((p) => p.id), isNot(nextDay.map((p) => p.id)));
      expect(dailySeed(DateTime(2026, 10, 24, 1)),
          dailySeed(DateTime(2026, 10, 24, 22)));
      expect(dailySeed(_friday, 'de_berlin'),
          isNot(dailySeed(_friday, 'pt_lisbon')));
    });

    test('small city: bottom third, never a must-see', () {
      final twelve = [for (var i = 1; i <= 12; i++) _sight(i)];
      final gems = selectHiddenGems(twelve, day: _friday);
      expect(gems.map((p) => p.id).toSet(), {'s11', 's12'});

      final eighteen = [for (var i = 1; i <= 18; i++) _sight(i)];
      expect(
        selectHiddenGems(eighteen, day: _friday).map((p) => p.id).toSet(),
        {for (var i = 13; i <= 18; i++) 's$i'},
      );
      expect(selectHiddenGems([_sight(1), _sight(2)], day: _friday), isEmpty);
    });
  });

  group('isOpenBetween', () {
    test('simple ranges and 24/7', () {
      expect(_tonight('24/7'), isTrue);
      expect(_tonight('Mo-Su 10:00-22:00'), isTrue);
      expect(_tonight('Mo-Su 08:00-18:00'), isFalse); // Closes at 18:00.
      expect(_tonight('Mo-Su 23:00-05:00'), isFalse); // Opens at 23:00.
      expect(_tonight('Mo-Su 22:30-05:00'), isTrue);
      expect(_tonight('17:00-01:00'), isTrue); // No days: every day.
      expect(_tonight('Mo-Fr 18:00+'), isTrue);
    });

    test('weekday selectors, wrapping ranges and later rules', () {
      expect(_tonight('Mo-Th 17:00-23:00'), isFalse); // Friday not listed.
      expect(_tonight('Mo-Th 11:00-15:00; Fr,Sa 18:00-02:00'), isTrue);
      expect(_tonight('Th-Mo 19:00-23:00'), isTrue);
      expect(_tonight('Mo-Su 12:00-23:00; Fr off'), isFalse);
      expect(_tonight('Mo-Fr 11:00-14:00,17:30-22:00'), isTrue);
      expect(_tonight('Mo-Th 10:00-14:00, Fr 19:00-23:00'), isTrue);
      expect(_tonight('Mo - Fr 10:00 - 20:00'), isTrue);
      expect(_tonight('Mo-Su 12:00-22:00; PH off'), isTrue);
      expect(_tonight('Mo-Su,PH 12:00-22:00'), isTrue);
      expect(_tonight('Mo-Su 18:00-23:00', DateTime(2026, 10, 25)), isTrue);
    });

    test('unknown or unreadable values give null', () {
      expect(_tonight(null), isNull);
      expect(_tonight(''), isNull);
      expect(_tonight('Apr-Oct Mo-Su 10:00-22:00'), isNull);
      expect(_tonight('Mo-Su sunrise-sunset'), isNull);
      expect(_tonight('Sa[1] 10:00-22:00'), isNull);
      expect(_tonight('by appointment'), isNull);
    });
  });

  test('tonight: open first, unknown after, closed left out', () {
    final venues = [
      _venue('unknown', 'Apr-Oct 10:00-22:00', popularity: 400),
      _venue('closed', 'Mo-Su 08:00-17:00', popularity: 300),
      _venue('open', 'Mo-Su 17:00-01:00', popularity: 200),
      _venue('noHours', null, popularity: 100),
    ];
    expect(selectTonight(venues, now: _friday).map((p) => p.id),
        ['open', 'unknown', 'noHours']);
  });

  test('feed: placeholder without venues, sights only in the rows', () {
    final sights = [for (var i = 1; i <= 25; i++) _sight(i), _venue('v', null)];
    final noVenues = buildHomeFeed(sights: sights, venues: null, now: _friday);
    expect(noVenues.hasVenues, isFalse);
    expect(noVenues.sightCount, 25);
    expect(noVenues.mustSees, hasLength(10));
    expect(noVenues.hiddenGems.map((p) => p.id).toSet(),
        {for (var i = 21; i <= 25; i++) 's$i'});

    final withVenues = buildHomeFeed(
      sights: sights,
      venues: [_venue('bar', 'Mo-Su 18:00-02:00')],
      now: _friday,
    );
    expect(withVenues.hasVenues, isTrue);
    expect(withVenues.places(HomeCollection.tonight).single.id, 'bar');
    expect(HomeCollection.fromSlug('hidden-gems'), HomeCollection.hiddenGems);
    expect(HomeCollection.fromSlug('nope'), isNull);
  });

  test('loadCityVenues returns active venues of the city, best first',
      () async {
    final db = FakeFirebaseFirestore();
    Future<void> add(String id, Map<String, dynamic> extra) =>
        db.collection('places').doc(id).set({
          'id': id,
          'name': id,
          'lat': 0,
          'lng': 0,
          'cityId': 'de_berlin',
          'status': 'active',
          ...extra,
        });
    await add('sight', {'popularity': 990});
    await add('low', {'kind': 'venue', 'popularity': 10});
    await add('high', {'kind': 'venue', 'popularity': 400});
    await add(
        'hidden', {'kind': 'venue', 'popularity': 450, 'status': 'hidden'});
    await add('other', {'kind': 'venue', 'popularity': 450, 'cityId': 'x'});

    final venues =
        await PlacesRepository(firestore: db).loadCityVenues('de_berlin');
    expect(venues.map((p) => p.id), ['high', 'low']);
    expect(venues.every((p) => p.isVenue), isTrue);
  });

  test('a missing venue index means "no venues", other errors surface',
      () async {
    final db = _MockDb();
    final collection = _MockCollection();
    final query = _MockQuery();
    when(() => db.collection('places')).thenReturn(collection);
    when(() => collection.where(any(), isEqualTo: any(named: 'isEqualTo')))
        .thenReturn(query);
    when(() => query.where(any(), isEqualTo: any(named: 'isEqualTo')))
        .thenReturn(query);
    when(() => query.orderBy(any(), descending: any(named: 'descending')))
        .thenReturn(query);
    when(() => query.limit(any())).thenReturn(query);
    when(() => query.get()).thenThrow(FirebaseException(
      plugin: 'cloud_firestore',
      code: 'failed-precondition',
      message: 'The query requires an index.',
    ));
    final repo = PlacesRepository(firestore: db);
    expect(await repo.loadCityVenues('de_berlin'), isEmpty);

    when(() => query.get()).thenThrow(FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    ));
    expect(repo.loadCityVenues('de_berlin'), throwsA(isA<FirebaseException>()));
  });
}
