import '../models/group_model.dart';

/// One stamp in the passport: a city the user has travelled to.
class PassportStamp {
  const PassportStamp({
    required this.cityId,
    required this.cityName,
    required this.countryCode,
    required this.date,
  });

  final String cityId;
  final String cityName;
  final String countryCode;

  /// The day the first trip to this city began.
  final DateTime date;

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

/// A stamp per city of the user's trips that have begun, oldest first.
/// Several trips to one city share its first stamp.
List<PassportStamp> passportStamps(List<GroupModel> trips, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final byCity = <String, PassportStamp>{};
  for (final trip in trips) {
    final start = trip.tripStart;
    final place = trip.location;
    if (start == null || place == null || start.isAfter(today)) continue;
    final key = place.cityId.isNotEmpty ? place.cityId : place.cityName;
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
  return byCity.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}
