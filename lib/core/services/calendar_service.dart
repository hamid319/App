import 'package:device_calendar/device_calendar.dart';

import '../../common/models/calendar_trip.dart';

class CalendarPermissionDenied implements Exception {
  const CalendarPermissionDenied();
}

/// Reads upcoming events from the calendars on the device (Apple Calendar,
/// and Google Calendar where the account is set up on the phone).
///
/// Only called when the user taps "From calendar"; events stay on the
/// device, the caller keeps just the chosen one's title, place and dates.
class CalendarService {
  CalendarService([DeviceCalendarPlugin? plugin])
      : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  Future<List<CalendarTrip>> upcomingTrips({
    Duration ahead = const Duration(days: 365),
    int maxEvents = 100,
  }) async {
    var granted = (await _plugin.hasPermissions()).data ?? false;
    if (!granted) {
      granted = (await _plugin.requestPermissions()).data ?? false;
    }
    if (!granted) throw const CalendarPermissionDenied();

    final calendars = (await _plugin.retrieveCalendars()).data ?? const [];
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final params =
        RetrieveEventsParams(startDate: from, endDate: now.add(ahead));

    final trips = <CalendarTrip>[];
    for (final calendar in calendars) {
      final id = calendar.id;
      // Read-only calendars are subscriptions such as holidays or
      // birthdays, not the user's own plans.
      if (id == null || calendar.isReadOnly == true) continue;
      final events =
          (await _plugin.retrieveEvents(id, params)).data ?? const [];
      for (final event in events) {
        final title = event.title?.trim() ?? '';
        final start = event.start;
        final end = event.end;
        if (title.isEmpty || start == null || end == null) continue;
        trips.add(CalendarTrip.fromEvent(
          title: title,
          // The plugin's TZDateTime.toLocal() uses the timezone package's
          // local zone (UTC by default); go through the instant instead to
          // get the device's local day.
          start:
              DateTime.fromMillisecondsSinceEpoch(start.millisecondsSinceEpoch),
          end: DateTime.fromMillisecondsSinceEpoch(end.millisecondsSinceEpoch),
          location: event.location,
        ));
      }
    }
    trips.sort((a, b) => a.start.compareTo(b.start));
    return trips.take(maxEvents).toList();
  }
}
