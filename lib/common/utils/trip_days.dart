import '../models/group_model.dart';
import 'day_route.dart';

/// Most days a trip plan covers.
const int maxTripDays = 14;

/// Most stops on one day of the plan.
const int maxStopsPerDay = 6;

/// The calendar days of a trip (both ends inclusive), capped at
/// [maxTripDays]. A trip without dates has one undated day: an empty list.
List<DateTime> tripDays(DateTime? start, DateTime? end) {
  if (start == null) return const [];
  final first = DateTime(start.year, start.month, start.day);
  final lastRaw = end ?? start;
  final last = DateTime(lastRaw.year, lastRaw.month, lastRaw.day);
  final days = <DateTime>[];
  for (var d = first;
      !d.isAfter(last) && days.length < maxTripDays;
      d = DateTime(d.year, d.month, d.day + 1)) {
    days.add(d);
  }
  return days.isEmpty ? [first] : days;
}

/// Number of plan days for a trip; at least one.
int tripDayCount(DateTime? start, DateTime? end) {
  final days = tripDays(start, end).length;
  return days == 0 ? 1 : days;
}

/// Spreads [stopsByPriority] (most liked first) over [dayCount] days.
///
/// At most [perDay] stops a day are used, the most liked ones. They are put
/// into one short walking route that starts at the favourite, and the route
/// is cut into consecutive pieces of nearly equal size, so each day covers
/// one part of the city. Returns place ids per day; days can be empty when
/// there are fewer stops than days.
List<List<String>> distributeStopsOverDays(
  List<RouteStop> stopsByPriority,
  int dayCount, {
  int perDay = maxStopsPerDay,
}) {
  final days = dayCount < 1 ? 1 : dayCount;
  final seen = <String>{};
  final unique = [
    for (final s in stopsByPriority)
      if (seen.add(s.id)) s,
  ];
  final chosen = unique.take(days * perDay).toList();
  final route = orderDayRoute(chosen);

  final result = <List<String>>[];
  final base = route.length ~/ days;
  final extra = route.length % days;
  var index = 0;
  for (var day = 0; day < days; day++) {
    final size = base + (day < extra ? 1 : 0);
    result.add([for (final s in route.sublist(index, index + size)) s.id]);
    index += size;
  }
  return result;
}

/// Start time (minutes after midnight) of every stop of a day: the first at
/// [startMinute], each next one after [stayMinutes] at the previous stop
/// plus the walk there ([walkMinutes][i] leads to stop i + 1).
List<int> stopStartMinutes(
  List<int> walkMinutes, {
  int startMinute = 10 * 60,
  int stayMinutes = 90,
}) {
  final times = [startMinute];
  for (final walk in walkMinutes) {
    times.add(times.last + stayMinutes + walk);
  }
  return times;
}

/// Whole days from [today] until [start] (negative once it has begun).
int daysUntil(DateTime start, DateTime today) {
  final a = DateTime.utc(today.year, today.month, today.day);
  final b = DateTime.utc(start.year, start.month, start.day);
  return b.difference(a).inDays;
}

/// Whether a trip with these dates is over on [today]. Trips without dates
/// are never over.
bool isTripOver(DateTime? start, DateTime? end, DateTime today) {
  final last = end ?? start;
  if (last == null) return false;
  return daysUntil(last, today) < 0;
}

/// Trips split into upcoming (next first; undated after dated, newest
/// first) and past (most recent first).
({List<GroupModel> upcoming, List<GroupModel> past}) splitTrips(
    List<GroupModel> trips, DateTime today) {
  final upcoming = <GroupModel>[];
  final past = <GroupModel>[];
  for (final t in trips) {
    (isTripOver(t.tripStart, t.tripEnd, today) ? past : upcoming).add(t);
  }
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  upcoming.sort((a, b) {
    final sa = a.tripStart, sb = b.tripStart;
    if (sa != null && sb != null) return sa.compareTo(sb);
    if (sa != null) return -1;
    if (sb != null) return 1;
    return (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch);
  });
  past.sort((a, b) => (b.tripStart ?? epoch).compareTo(a.tripStart ?? epoch));
  return (upcoming: upcoming, past: past);
}
