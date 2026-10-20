import 'package:intl/intl.dart';

/// Trip dates in the given locale: "May 12 – May 15", or one day alone.
String formatTripDates(DateTime start, DateTime? end, String locale) {
  final day = DateFormat.MMMd(locale);
  final sameDay = end == null ||
      (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day);
  if (sameDay) return day.format(start);
  return '${day.format(start)} – ${day.format(end)}';
}
