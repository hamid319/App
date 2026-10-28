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
}
