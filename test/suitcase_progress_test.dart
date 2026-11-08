import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/utils/passport_stamps.dart';
import 'package:swipetrip/common/utils/suitcase_progress.dart';

PassportStamp _stamp(String city, String country, {bool checkedIn = false}) =>
    PassportStamp(
      cityId: city,
      cityName: city,
      countryCode: country,
      date: DateTime(2026),
      checkedIn: checkedIn,
    );

void main() {
  test('a new user starts at level 0 with no extras', () {
    final p = suitcaseProgress(trips: 0, stamps: const []);
    expect(p.miles, 0);
    expect(p.level, 0);
    expect(p.extras, isEmpty);
    expect(p.nextExtra?.extra, SuitcaseExtra.tag);
    expect(p.nextExtra?.missing, 1);
  });

  test('miles from trips, cities, check-ins and countries', () {
    final p = suitcaseProgress(trips: 2, stamps: [
      _stamp('lisbon', 'PT', checkedIn: true),
      _stamp('porto', 'PT'),
      _stamp('berlin', 'DE'),
    ]);
    // 2 trips + 3 cities + 1 check-in + 2 countries.
    expect(p.miles, 2 * 10 + 3 * 30 + 20 + 2 * 40);
    expect(p.level, 2);
    expect(p.extras, {SuitcaseExtra.tag, SuitcaseExtra.strap});
    expect(p.nextExtra?.extra, SuitcaseExtra.goldWheels);
    expect(p.nextExtra?.missing, 1);
    expect(p.levelProgress, closeTo((210 - 150) / (350 - 150), 1e-9));
  });

  test('the top level has no next level and full progress', () {
    final stamps = [
      for (var i = 0; i < 12; i++) _stamp('c$i', 'K${i % 4}', checkedIn: true)
    ];
    final p = suitcaseProgress(trips: 12, stamps: stamps);
    expect(p.isMaxLevel, isTrue);
    expect(p.nextLevelAt, isNull);
    expect(p.levelProgress, 1);
    expect(p.extras, SuitcaseExtra.values.toSet());
    expect(p.nextExtra, isNull);
  });

  test('packing counts friends, ideas and the day plan', () {
    final steps =
        tripPacking(members: 1, swiped: true, ideas: 2, hasDayPlan: false);
    expect(steps.values.where((done) => done).length, 1);
    expect(steps[TripPackStep.friends], isFalse);
    expect(steps[TripPackStep.wishlist], isFalse);
  });
}
