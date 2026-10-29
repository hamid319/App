import '../models/group_model.dart';

/// One stamp in the passport: a city the user has travelled to.
class PassportStamp {
  const PassportStamp({
    required this.cityId,
    required this.cityName,
    required this.countryCode,
    required this.date,
    this.checkedIn = false,
  });

  final String cityId;
  final String cityName;
  final String countryCode;

  /// The day of the check-in, else the day the first trip there began.
  final DateTime date;

  /// The user checked in on site (GPS). Without it the stamp is only
  /// pencilled in.
  final bool checkedIn;

  /// Stable across app starts (unlike String.hashCode), so a stamp keeps
  /// its shape, colour and tilt. FNV-1a, 32 bit.
  int get seed {
    var h = 0x811c9dc5;
    for (final c in cityId.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}

/// The key of a city in the passport and in `users/{uid}.checkIns`.
String stampKey(GroupLocation place) =>
    place.cityId.isNotEmpty ? place.cityId : place.cityName;

/// Whether [today] lies within the trip's dates (a trip without an end
/// lasts one day).
bool isTripNow(GroupModel trip, DateTime today) {
  final start = trip.tripStart;
  if (start == null) return false;
  final day = DateTime(today.year, today.month, today.day);
  final end = trip.tripEnd ?? start;
  return !DateTime(start.year, start.month, start.day).isAfter(day) &&
      !DateTime(end.year, end.month, end.day).isBefore(day);
}

/// A stamp per city of the user's trips that have begun, oldest first.
/// Several trips to one city share its first stamp. [checkIns] (city key ->
/// when) turns a stamp into a real one.
List<PassportStamp> passportStamps(List<GroupModel> trips, DateTime now,
    {Map<String, DateTime> checkIns = const {}}) {
  final today = DateTime(now.year, now.month, now.day);
  final byCity = <String, PassportStamp>{};
  for (final trip in trips) {
    final start = trip.tripStart;
    final place = trip.location;
    if (start == null || place == null || start.isAfter(today)) continue;
    final key = stampKey(place);
    if (key.isEmpty) continue;
    final known = byCity[key];
    if (known == null || start.isBefore(known.date)) {
      byCity[key] = PassportStamp(
        cityId: key,
        cityName: place.cityName,
        countryCode: place.countryCode,
        date: start,
      );
    }
  }
  return [
    for (final s in byCity.values)
      if (checkIns[s.cityId] case final at?)
        PassportStamp(
          cityId: s.cityId,
          cityName: s.cityName,
          countryCode: s.countryCode,
          date: at,
          checkedIn: true,
        )
      else
        s,
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// Trips the user is on today, in a known place, and not checked in at
/// yet: candidates for the check-in.
List<GroupModel> tripsToCheckIn(
        List<GroupModel> trips, Map<String, DateTime> checkIns, DateTime now) =>
    [
      for (final t in trips)
        if (t.location case final p?
            when (p.lat != 0 || p.lng != 0) &&
                !checkIns.containsKey(stampKey(p)) &&
                isTripNow(t, now))
          t,
    ];

/// When to remind about the check-in: 10:00 on the first day of each
/// upcoming trip whose city has no check-in yet, soonest first.
List<({GroupModel trip, DateTime at})> checkInReminderTimes(
    List<GroupModel> trips, Map<String, DateTime> checkIns, DateTime now) {
  final out = <({GroupModel trip, DateTime at})>[];
  for (final t in trips) {
    final start = t.tripStart;
    final p = t.location;
    if (start == null || p == null || checkIns.containsKey(stampKey(p))) {
      continue;
    }
    final at = DateTime(start.year, start.month, start.day, 10);
    if (at.isAfter(now)) out.add((trip: t, at: at));
  }
  return out..sort((a, b) => a.at.compareTo(b.at));
}
