import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/common/utils/day_route.dart';
import 'package:swipetrip/common/utils/trip_days.dart';

void main() {
  test('tripDays covers both ends and is capped', () {
    final days = tripDays(DateTime(2026, 10, 29, 15), DateTime(2026, 10, 31));
    expect(days, [DateTime(2026, 10, 29), DateTime(2026, 10, 30), DateTime(2026, 10, 31)]);
    expect(tripDays(null, null), isEmpty);
    expect(tripDays(DateTime(2026, 1, 1), DateTime(2026, 3, 1)).length, maxTripDays);
    expect(tripDayCount(null, null), 1);
    expect(tripDayCount(DateTime(2026, 1, 1), null), 1);
  });

  test('walking minutes at 4.8 km/h', () {
    expect(walkingMinutes(0), 0);
    expect(walkingMinutes(0.01), 1);
    expect(walkingMinutes(2.4), 30);
  });

  test('stop times add the stay and the walk', () {
    expect(stopStartMinutes([12, 18]), [600, 600 + 90 + 12, 600 + 180 + 30]);
  });

  group('distributeStopsOverDays', () {
    // Two clusters far apart: west (w*) and east (e*).
    final stops = [
      const RouteStop(id: 'w1', lat: 38.70, lng: -9.20),
      const RouteStop(id: 'e1', lat: 38.70, lng: -9.00),
      const RouteStop(id: 'w2', lat: 38.701, lng: -9.201),
      const RouteStop(id: 'e2', lat: 38.701, lng: -9.001),
      const RouteStop(id: 'w3', lat: 38.702, lng: -9.199),
      const RouteStop(id: 'e3', lat: 38.699, lng: -9.002),
    ];

    test('keeps each day in one part of the city', () {
      final days = distributeStopsOverDays(stops, 2);
      expect(days.length, 2);
      expect(days[0].toSet(), {'w1', 'w2', 'w3'});
      expect(days[1].toSet(), {'e1', 'e2', 'e3'});
      // The favourite starts the first day.
      expect(days[0].first, 'w1');
    });

    test('uses every stop once and evens out day sizes', () {
      final days = distributeStopsOverDays(stops, 4);
      expect(days.map((d) => d.length).toList(), [2, 2, 1, 1]);
      expect(days.expand((d) => d).toSet().length, 6);
    });

    test('more days than stops leaves days empty, one day takes all', () {
      expect(distributeStopsOverDays(stops.take(2).toList(), 3)
          .map((d) => d.length), [1, 1, 0]);
      expect(distributeStopsOverDays(stops, 1).single.length, 6);
      expect(distributeStopsOverDays(const [], 2), [<String>[], <String>[]]);
    });

    test('only the most liked stops are used when there are too many', () {
      final days = distributeStopsOverDays(stops, 1, perDay: 2);
      expect(days.single.toSet(), {'w1', 'e1'});
    });
  });

  test('splitTrips orders upcoming and past trips', () {
    final today = DateTime(2026, 10, 27);
    GroupModel g(String id, DateTime? start, [DateTime? end]) =>
        GroupModel(groupId: id, tripStart: start, tripEnd: end);
    final split = splitTrips([
      g('past', DateTime(2026, 6, 1), DateTime(2026, 6, 3)),
      g('undated', null),
      g('later', DateTime(2026, 12, 1)),
      g('soon', DateTime(2026, 10, 29), DateTime(2026, 10, 31)),
      g('ongoing', DateTime(2026, 10, 25), DateTime(2026, 10, 28)),
      g('older', DateTime(2026, 3, 1)),
    ], today);
    expect(split.upcoming.map((t) => t.groupId),
        ['ongoing', 'soon', 'later', 'undated']);
    expect(split.past.map((t) => t.groupId), ['past', 'older']);
    expect(daysUntil(DateTime(2026, 10, 30, 8), today), 3);
  });
}
