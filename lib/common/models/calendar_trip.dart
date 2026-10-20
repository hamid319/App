import 'package:meta/meta.dart';

/// A calendar event the user can turn into a group: only what the group
/// needs, nothing else from the calendar is kept.
@immutable
class CalendarTrip {
  const CalendarTrip({
    required this.title,
    required this.start,
    required this.end,
    this.location,
  });

  final String title;
  final String? location;

  /// First and last day of the trip, both inclusive, without time.
  final DateTime start;
  final DateTime end;

  /// Builds a trip from raw event times (device-local). An event ending
  /// exactly at midnight (Android all-day events, many trips) does not
  /// count that last midnight as a day; iOS all-day events end at 23:59.
  factory CalendarTrip.fromEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
  }) {
    final first = DateTime(start.year, start.month, start.day);
    var last = DateTime(end.year, end.month, end.day);
    final endsAtMidnight = end.hour == 0 && end.minute == 0 && end.second == 0;
    if (endsAtMidnight && last.isAfter(first)) {
      last = last.subtract(const Duration(days: 1));
    }
    if (last.isBefore(first)) last = first;
    final place = location?.trim();
    return CalendarTrip(
      title: title.trim(),
      location: (place == null || place.isEmpty) ? null : place,
      start: first,
      end: last,
    );
  }

  int get days => end.difference(start).inDays + 1;
}
