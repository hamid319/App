import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/common/utils/passport_stamps.dart';

GroupModel _trip(String id, String city, DateTime? start) => GroupModel(
      groupId: id,
      tripStart: start,
      location: GroupLocation(
        countryCode: 'PT',
        countryName: 'Portugal',
        cityId: city.toLowerCase(),
        cityName: city,
        lat: 0,
        lng: 0,
      ),
    );

void main() {
  final now = DateTime(2026, 10, 28, 15);

  test('one stamp per city, from its first trip that has begun', () {
    final stamps = passportStamps([
      _trip('a', 'Lisbon', DateTime(2026, 5, 1)),
      _trip('b', 'Porto', DateTime(2025, 9, 3)),
      _trip('c', 'Lisbon', DateTime(2024, 4, 2)),
      _trip('d', 'Madeira', DateTime(2026, 11, 1)), // not started yet
      _trip('e', 'Faro', null), // no dates
      _trip('f', 'Braga', DateTime(2026, 10, 28)), // starts today
    ], now);

    expect(stamps.map((s) => s.cityName), ['Lisbon', 'Porto', 'Braga']);
    expect(stamps.first.date, DateTime(2024, 4, 2));
  });

  test('a city keeps its look', () {
    final a = passportStamps([_trip('a', 'Lisbon', DateTime(2025))], now);
    final b = passportStamps([_trip('b', 'Lisbon', DateTime(2024))], now);
    expect(a.single.seed, b.single.seed);
  });

  test('a check-in makes a stamp real and dates it', () {
    final stamps = passportStamps(
        [
          _trip('a', 'Lisbon', DateTime(2026, 10, 20)),
          _trip('b', 'Porto', DateTime(2026, 10, 1)),
        ],
        now,
        checkIns: {'lisbon': DateTime(2026, 10, 22)});
    expect(stamps.map((s) => (s.cityName, s.checkedIn)),
        [('Porto', false), ('Lisbon', true)]);
    expect(stamps.last.date, DateTime(2026, 10, 22));
  });

  test('a trip is now from its first to its last day', () {
    final trip = _trip('a', 'Lisbon', DateTime(2026, 10, 27))
        .copyWith(tripEnd: DateTime(2026, 10, 29));
    expect(isTripNow(trip, DateTime(2026, 10, 26, 23)), isFalse);
    expect(isTripNow(trip, DateTime(2026, 10, 27, 0)), isTrue);
    expect(isTripNow(trip, DateTime(2026, 10, 29, 23)), isTrue);
    expect(isTripNow(trip, DateTime(2026, 10, 30)), isFalse);
    expect(isTripNow(_trip('b', 'Porto', null), now), isFalse);
  });

  test('check-in candidates: on the trip now, located, not checked in', () {
    GroupModel at(String id, String city, double lat) =>
        _trip(id, city, DateTime(2026, 10, 27)).copyWith(
          tripEnd: DateTime(2026, 10, 30),
          location: GroupLocation(
            countryCode: 'PT',
            countryName: 'Portugal',
            cityId: city.toLowerCase(),
            cityName: city,
            lat: lat,
            lng: 1,
          ),
        );
    final trips = [
      at('a', 'Lisbon', 38.7),
      at('b', 'Porto', 41.1),
      at('c', 'Nowhere', 0).copyWith(
          location: const GroupLocation(
              countryCode: '',
              countryName: '',
              cityId: 'x',
              cityName: 'x',
              lat: 0,
              lng: 0)),
      _trip('d', 'Faro', DateTime(2026, 12, 1)),
    ];
    expect(
        tripsToCheckIn(trips, {'porto': DateTime(2026, 10, 27)}, now)
            .map((t) => t.groupId),
        ['a']);
  });

  test('reminders at 10:00 on the first day of upcoming trips', () {
    final r = checkInReminderTimes([
      _trip('a', 'Faro', DateTime(2026, 12, 1)),
      _trip('b', 'Porto', DateTime(2026, 11, 2)),
      _trip('c', 'Braga', DateTime(2026, 10, 28)), // today, 10:00 passed
      _trip('d', 'Lisbon', DateTime(2026, 11, 5)), // already checked in
    ], {
      'lisbon': DateTime(2025)
    }, now);
    expect(r.map((x) => (x.trip.groupId, x.at)), [
      ('b', DateTime(2026, 11, 2, 10)),
      ('a', DateTime(2026, 12, 1, 10)),
    ]);
  });
}
