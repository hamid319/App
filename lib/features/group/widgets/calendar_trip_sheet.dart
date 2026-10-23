import 'package:flutter/material.dart';

import '../../../common/models/calendar_trip.dart';
import '../../../common/utils/trip_dates.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/calendar_service.dart';
import '../../../l10n/l10n.dart';

/// Lists upcoming calendar events; returns the one the user picks, or null.
Future<CalendarTrip?> showCalendarTripSheet(
  BuildContext context, {
  required Future<List<CalendarTrip>> Function() loadTrips,
}) {
  return showModalBottomSheet<CalendarTrip>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CalendarTripSheet(loadTrips: loadTrips),
  );
}

class _CalendarTripSheet extends StatefulWidget {
  const _CalendarTripSheet({required this.loadTrips});

  final Future<List<CalendarTrip>> Function() loadTrips;

  @override
  State<_CalendarTripSheet> createState() => _CalendarTripSheetState();
}

class _CalendarTripSheetState extends State<_CalendarTripSheet> {
  late final Future<List<CalendarTrip>> _trips = widget.loadTrips();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget message(IconData icon, String body) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBadge(icon: icon, tone: ChipTone.sky, size: 64),
              const SizedBox(height: AppSizes.space12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenEdge,
              0,
              AppSizes.screenEdge,
              AppSizes.space4,
            ),
            child: Text(l10n.calendarPickTitle, style: text.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenEdge,
              0,
              AppSizes.screenEdge,
              AppSizes.space12,
            ),
            child: Text(
              l10n.calendarPickHint,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CalendarTrip>>(
              future: _trips,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Skeleton(
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.screenEdge,
                      ),
                      children: const [
                        SkeletonBox(height: 64, radius: AppSizes.radiusTicket),
                        SizedBox(height: AppSizes.space8),
                        SkeletonBox(height: 64, radius: AppSizes.radiusTicket),
                        SizedBox(height: AppSizes.space8),
                        SkeletonBox(height: 64, radius: AppSizes.radiusTicket),
                      ],
                    ),
                  );
                }
                final error = snapshot.error;
                if (error is CalendarPermissionDenied) {
                  return message(Icons.lock_outline, l10n.calendarPermissionDenied);
                }
                if (error != null) {
                  return message(
                    Icons.error_outline,
                    userMessage(error,
                        fallback: l10n.errorLoadCalendar, l10n: l10n),
                  );
                }
                final trips = snapshot.data ?? const <CalendarTrip>[];
                if (trips.isEmpty) {
                  return message(Icons.event_busy_outlined, l10n.calendarNoEvents);
                }
                final locale = Localizations.localeOf(context).toLanguageTag();
                return ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenEdge,
                    0,
                    AppSizes.screenEdge,
                    AppSizes.space24,
                  ),
                  itemCount: trips.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.space12),
                  itemBuilder: (context, i) {
                    final trip = trips[i];
                    final details = [
                      formatTripDates(trip.start, trip.end, locale),
                      if (trip.location != null) trip.location!,
                    ].join(' · ');
                    return Ticket(
                      onTap: () => Navigator.of(context).pop(trip),
                      child: ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: Text(
                          trip.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          details,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
