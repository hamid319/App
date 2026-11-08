import 'passport_stamps.dart';

/// Extras the suitcase earns, in the order they unlock.
enum SuitcaseExtra { tag, strap, goldWheels, goldHandle }

/// What the user has to reach for an extra: a count of trips, cities or
/// countries.
enum SuitcaseGoal { trips, cities, countries }

/// When each extra unlocks.
const suitcaseExtraRules = {
  SuitcaseExtra.tag: (goal: SuitcaseGoal.trips, need: 1),
  SuitcaseExtra.strap: (goal: SuitcaseGoal.cities, need: 3),
  SuitcaseExtra.goldWheels: (goal: SuitcaseGoal.countries, need: 3),
  SuitcaseExtra.goldHandle: (goal: SuitcaseGoal.cities, need: 10),
};

/// Miles needed for each level (index = level).
const suitcaseLevels = [0, 40, 150, 350, 700];

/// Miles per trip planned or joined, per city stamp, per on-site check-in
/// and per country.
const milesPerTrip = 10;
const milesPerCity = 30;
const milesPerCheckIn = 20;
const milesPerCountry = 40;

/// Miles per trip the user has fully packed for (packing list at 100 %).
const milesPerPackedTrip = 15;

/// The user's suitcase: level, miles, extras and city stickers. Derived
/// from the trips, passport stamps and packed trips the app already
/// loads, so it costs no extra reads and has no counter to write.
class SuitcaseProgress {
  const SuitcaseProgress({
    required this.miles,
    required this.trips,
    required this.stickers,
  });

  final int miles;
  final int trips;

  /// One sticker per passport stamp, oldest first.
  final List<PassportStamp> stickers;

  int get cities => stickers.length;
  int get countries => {
        for (final s in stickers)
          if (s.countryCode.isNotEmpty) s.countryCode
      }.length;

  int get level => suitcaseLevels.lastIndexWhere((need) => miles >= need);

  bool get isMaxLevel => level == suitcaseLevels.length - 1;

  /// Miles where this level began and where the next one starts (null at
  /// the top).
  int get levelStart => suitcaseLevels[level];
  int? get nextLevelAt => isMaxLevel ? null : suitcaseLevels[level + 1];

  /// 0..1 on the way to the next level (1 at the top).
  double get levelProgress {
    final next = nextLevelAt;
    if (next == null) return 1;
    return (miles - levelStart) / (next - levelStart);
  }

  int count(SuitcaseGoal goal) => switch (goal) {
        SuitcaseGoal.trips => trips,
        SuitcaseGoal.cities => cities,
        SuitcaseGoal.countries => countries,
      };

  Set<SuitcaseExtra> get extras => {
        for (final e in suitcaseExtraRules.entries)
          if (count(e.value.goal) >= e.value.need) e.key
      };

  /// The next extra to earn and how many trips, cities or countries are
  /// still missing; null once all are earned.
  ({SuitcaseExtra extra, SuitcaseGoal goal, int missing})? get nextExtra {
    for (final e in suitcaseExtraRules.entries) {
      final have = count(e.value.goal);
      if (have < e.value.need) {
        return (extra: e.key, goal: e.value.goal, missing: e.value.need - have);
      }
    }
    return null;
  }
}

SuitcaseProgress suitcaseProgress({
  required int trips,
  required List<PassportStamp> stamps,
  int packedTrips = 0,
}) {
  final countries = {
    for (final s in stamps)
      if (s.countryCode.isNotEmpty) s.countryCode
  }.length;
  final checkIns = stamps.where((s) => s.checkedIn).length;
  return SuitcaseProgress(
    miles: trips * milesPerTrip +
        stamps.length * milesPerCity +
        checkIns * milesPerCheckIn +
        countries * milesPerCountry +
        packedTrips * milesPerPackedTrip,
    trips: trips,
    stickers: stamps,
  );
}

/// Steps of planning one trip, in the order they are suggested.
enum TripPackStep { friends, swipe, wishlist, dayPlan }

/// Which planning steps a trip has done. A trip planned to 100 % has a
/// second member, the user's swipes, three wishlist ideas and a day plan.
Map<TripPackStep, bool> tripPacking({
  required int members,
  required bool swiped,
  required int ideas,
  required bool hasDayPlan,
}) =>
    {
      TripPackStep.friends: members > 1,
      TripPackStep.swipe: swiped,
      TripPackStep.wishlist: ideas >= 3,
      TripPackStep.dayPlan: hasDayPlan,
    };
