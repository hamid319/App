import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/group_model.dart';
import '../../../common/utils/trip_dates.dart';
import '../../../common/widgets/city_picker.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../main_providers.dart';
import '../logic/group_controller.dart';
import 'calendar_trip_sheet.dart';
import 'trip_ui.dart';

/// Sheet to plan a new trip: name, city and optional dates (also from a
/// calendar event). Returns the new trip's group id, or null.
Future<String?> showCreateTripSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _CreateTripSheet(),
  );
}

class _CreateTripSheet extends ConsumerStatefulWidget {
  const _CreateTripSheet();

  @override
  ConsumerState<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends ConsumerState<_CreateTripSheet> {
  final _name = TextEditingController();
  PopularCity? _city;
  DateTimeRange? _dates;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Fills name, city and dates from an event the user picks in their
  /// calendar. Calendar access is only requested here, on the user's tap.
  Future<void> _fillFromCalendar() async {
    final calendar = ref.read(calendarServiceProvider);
    final trip = await showCalendarTripSheet(
      context,
      loadTrips: calendar.upcomingTrips,
    );
    if (trip == null || !mounted) return;
    final city = PopularCity.findIn([trip.location, trip.title]);
    setState(() {
      _name.text = trip.title;
      if (city != null) _city = city;
      _dates = DateTimeRange(start: trip.start, end: trip.end);
    });
    if (city == null) showTripSnack(context, context.l10n.calendarCityNotFound);
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      initialDateRange: _dates,
    );
    if (picked != null && mounted) setState(() => _dates = picked);
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    final city = _city;
    if (name.isEmpty || city == null) {
      showTripSnack(context, l10n.enterNameAndLocation);
      return;
    }
    final location = GroupLocation(
      countryCode: city.countryCode,
      countryName: city.countryNameEn,
      // Stable key for the place cache, e.g. "los_angeles".
      cityId: city.id.substring(city.id.indexOf('_') + 1),
      cityName: city.nameEn,
      lat: city.lat,
      lng: city.lng,
    );
    setState(() => _busy = true);
    await ref.read(groupControllerProvider.notifier).createGroupWithSettings(
          groupName: name,
          location: location,
          tripStart: _dates?.start,
          tripEnd: _dates?.end,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    final state = ref.read(groupControllerProvider);
    if (state.hasError) {
      showTripSnack(
        context,
        userMessage(state.error!, fallback: l10n.errorCreateGroup, l10n: l10n),
        error: true,
      );
      return;
    }
    Navigator.of(context).pop(ref.read(selectedGroupIdProvider));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final city = _city;
    final dates = _dates;
    final muted = text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(l10n.tripNewTitle, style: text.headlineSmall)),
                TextButton.icon(
                  onPressed: _fillFromCalendar,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(l10n.fromCalendar),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InsetGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: l10n.groupNameHint,
                      labelText: l10n.groupNameLabel,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(l10n.cityLabel),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (city != null) Text(city.nameFor(lang), style: muted),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => showCityPicker(
                    context,
                    selectedId: city?.id,
                    offerCurrentLocation: false,
                    onSelected: (c) => setState(() => _city = c),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.date_range_outlined),
                  title: Text(l10n.tripDatesLabel),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dates != null) ...[
                        Text(
                          formatTripDates(dates.start, dates.end,
                              Localizations.localeOf(context).toLanguageTag()),
                          style: muted,
                        ),
                        IconButton(
                          tooltip: l10n.clearTripDates,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => _dates = null),
                        ),
                      ] else
                        const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: _pickDates,
                ),
              ],
            ),
            const SizedBox(height: 20),
            FloatingPrimaryButton(
              label: l10n.tripCreateButton,
              icon: Icons.add_rounded,
              loading: _busy,
              onPressed: _create,
            ),
          ],
        ),
      ),
    );
  }
}
