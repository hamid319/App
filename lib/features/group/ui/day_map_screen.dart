import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/place_model.dart';
import '../../../common/utils/day_route.dart';
import '../../../common/utils/place_type_labels.dart';
import '../../../common/utils/trip_days.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/places_map.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/maps_availability.dart';
import '../../../core/services/maps_launcher.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';
import '../widgets/trip_ui.dart';

final _mapsConfiguredProvider =
    FutureProvider<bool>((ref) => MapsAvailability().isConfigured());

/// One day of the trip plan on a map: numbered stops joined in walking
/// order, and a sheet with the day's stops, times and walks.
class DayMapScreen extends ConsumerStatefulWidget {
  const DayMapScreen({super.key, required this.groupId, required this.day});

  final String groupId;
  final int day;

  @override
  ConsumerState<DayMapScreen> createState() => _DayMapScreenState();
}

class _DayMapScreenState extends ConsumerState<DayMapScreen> {
  late int _day = widget.day;
  bool _building = false;

  Future<void> _build(GroupModel group) async {
    final l10n = context.l10n;
    final ideas = ref.read(tripIdeasProvider(widget.groupId)).value ?? const [];
    setState(() => _building = true);
    try {
      await ref.read(tripActionsProvider.notifier).buildPlan(group, ideas);
    } catch (e) {
      if (mounted) {
        showTripSnack(context,
            userMessage(e, fallback: l10n.errorSaveDayPlan, l10n: l10n),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trip = ref.watch(tripProvider(widget.groupId));
    final back = Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      child: GlassButton(
        icon: Icons.arrow_back_ios_new_rounded,
        tooltip: l10n.back,
        opacity: 0.82,
        onTap: () => context.canPop()
            ? context.pop()
            : context.go('/trip/${widget.groupId}'),
      ),
    );

    return Scaffold(
      body: trip.when(
        loading: () => WithBackButton(
          fallbackRoute: '/trip/${widget.groupId}',
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => WithBackButton(
          fallbackRoute: '/trip/${widget.groupId}',
          child: ErrorView(
            message: userMessage(e, fallback: l10n.errorGeneric, l10n: l10n),
          ),
        ),
        data: (group) {
          if (group == null) {
            return ErrorView(
              message: l10n.groupNotFound,
              onRetry: () => context.go('/trips'),
            );
          }
          final plan = group.tripPlan;
          if (plan == null || plan.isEmpty) {
            final ideas =
                ref.watch(tripIdeasProvider(widget.groupId)).value ?? const [];
            final plannable = ideas.where((i) => i.placeId != null).length;
            return Stack(
              children: [
                ErrorView(
                  icon: Icons.map_outlined,
                  title: l10n.tripNoPlanTitle,
                  message: l10n.tripNoPlanBody,
                ),
                back,
                BottomFloat(
                  button: FloatingPrimaryButton(
                    label: plannable == 0
                        ? l10n.tripPlanNeedsIdeas
                        : l10n.tripBuildPlan(plannable),
                    icon: Icons.auto_awesome_rounded,
                    loading: _building,
                    onPressed: plannable == 0 ? null : () => _build(group),
                  ),
                ),
              ],
            );
          }
          final day = _day.clamp(0, plan.days.length - 1);
          final places =
              ref.watch(tripPlacesProvider(placesKey(plan.allPlaceIds)));
          final byId = {
            for (final p in places.value ?? const <PlaceModel>[]) p.id: p,
          };
          final stops = [
            for (final id in plan.days[day])
              if (byId[id] case final p?) p,
          ];
          final configured = ref.watch(_mapsConfiguredProvider).value;
          return Stack(
            children: [
              Positioned.fill(
                child: configured == true && stops.isNotEmpty
                    ? _DayMap(key: ValueKey(day), stops: stops)
                    : ColoredBox(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        child: configured == false
                            ? Align(
                                alignment: const Alignment(0, -0.6),
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(l10n.mapsNotConfigured,
                                      textAlign: TextAlign.center),
                                ),
                              )
                            : null,
                      ),
              ),
              back,
              _DaySheet(
                group: group,
                dayCount: plan.days.length,
                day: day,
                stops: stops,
                loading: places.isLoading,
                onDay: (d) => setState(() => _day = d),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Share of the screen the day sheet covers when it opens; the map keeps
/// its pins, logo and attribution above it.
const double _sheetStart = 0.58;

/// Mapbox map with numbered pins and the walking order as a line; tapping
/// a pin opens the place.
class _DayMap extends StatelessWidget {
  const _DayMap({super.key, required this.stops});

  final List<PlaceModel> stops;

  @override
  Widget build(BuildContext context) {
    // The sheet covers the lower half; keep the stops above it.
    return PlacesMap(
      places: stops,
      numbered: true,
      bottomInset: MediaQuery.sizeOf(context).height * _sheetStart,
      onTapPlace: (place) => context.push('/place/${place.id}'),
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.group,
    required this.dayCount,
    required this.day,
    required this.stops,
    required this.loading,
    required this.onDay,
  });

  final GroupModel group;
  final int dayCount;
  final int day;
  final List<PlaceModel> stops;
  final bool loading;
  final ValueChanged<int> onDay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dates = tripDays(group.tripStart, group.tripEnd);
    final date = day < dates.length ? dates[day] : null;

    final route = [
      for (final p in stops) RouteStop(id: p.id, lat: p.lat, lng: p.lng),
    ];
    final legsKm = [
      for (var i = 1; i < route.length; i++) legKm(route[i - 1], route[i]),
    ];
    final walks = [for (final km in legsKm) walkingMinutes(km)];
    final totalKm = legsKm.fold(0.0, (a, b) => a + b);
    final totalWalk = walks.fold(0, (a, b) => a + b);
    final starts = stopStartMinutes(walks);

    return DraggableScrollableSheet(
      initialChildSize: _sheetStart,
      minChildSize: 0.22,
      maxChildSize: 0.92,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.fromLTRB(
            8, 0, 8, 8 + MediaQuery.paddingOf(context).bottom * 0.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.08),
                    width: 0.5),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  const SheetGrabber(),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date != null
                                  ? DateFormat.MMMMEEEEd(locale).format(date)
                                  : l10n.tripDayN(day + 1),
                              style: text.headlineSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.tripDaySummary(
                                stops.length,
                                _distance(context, totalKm),
                                totalWalk,
                              ),
                              style: text.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: l10n.dayPlanOpenRoute,
                        child: Material(
                          color: scheme.primary.withValues(alpha: 0.16),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: stops.isEmpty
                                ? null
                                : () => _openRoute(context, stops),
                            child: SizedBox.square(
                              dimension: 44,
                              child: Icon(Icons.directions_walk_rounded,
                                  color: scheme.primary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (dayCount > 1) ...[
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var d = 0; d < dayCount; d++) ...[
                            if (d > 0) const SizedBox(width: 8),
                            _DayChip(
                              label: d < dates.length
                                  ? DateFormat.E(locale).format(dates[d])
                                  : l10n.tripDayN(d + 1),
                              selected: d == day,
                              onTap: () => onDay(d),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (stops.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        l10n.tripDayEmpty,
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    for (final (i, place) in stops.indexed) ...[
                      if (i > 0) _WalkLeg(minutes: walks[i - 1]),
                      _StopRow(
                        number: i + 1,
                        place: place,
                        startMinute: starts[i],
                      ),
                    ],
                  if (stops.length > MapsLauncher.maxRouteStops)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(l10n.dayPlanRouteCapped,
                          style: text.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRoute(BuildContext context, List<PlaceModel> stops) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MapsLauncher.openRoute(
          [for (final p in stops) (lat: p.lat, lng: p.lng)]);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(userMessage(e, fallback: l10n.errorOpenMaps, l10n: l10n)),
      ));
    }
  }
}

String _distance(BuildContext context, double km) {
  final l10n = context.l10n;
  if (km < 1) return l10n.distanceMetersValue((km * 1000).round());
  final locale = Localizations.localeOf(context).toLanguageTag();
  return l10n.distanceKmValue(NumberFormat('0.0', locale).format(km));
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.onSurface : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? scheme.surface : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.number,
    required this.place,
    required this.startMinute,
  });

  final int number;
  final PlaceModel place;
  final int startMinute;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: (startMinute ~/ 60) % 24, minute: startMinute % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final types = placeTypeLabels(l10n, place.types);
    final detail = [time, if (types.isNotEmpty) types.first].join(' · ');
    return InkWell(
      onTap: () => context.push('/place/${place.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
              child: Text(
                '$number',
                style: text.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.nameFor(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed connector between two stops with the walking time.
class _WalkLeg extends StatelessWidget {
  const _WalkLeg({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          CustomPaint(
            size: const Size(28, 24),
            painter: _DashPainter(scheme.outlineVariant),
          ),
          const SizedBox(width: 12),
          Text(
            context.l10n.tripWalkMinutes(minutes),
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final x = size.width / 2;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(
          Offset(x, y), Offset(x, math.min(y + 3, size.height)), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
