import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common/models/day_plan.dart';
import '../../../common/models/group_session_model.dart';
import '../../../common/models/place_model.dart';
import '../../../common/utils/day_route.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/maps_launcher.dart';
import '../../../l10n/l10n.dart';
import '../../auth/logic/auth_controller.dart';
import '../../swipe/data/places_repository.dart';
import '../logic/group_controller.dart';

typedef _SessionKey = ({String groupId, String sessionId});

final _sessionProvider = StreamProvider.autoDispose
    .family<GroupSessionModel?, _SessionKey>((ref, key) {
  return ref
      .watch(groupRepositoryProvider)
      .streamSession(groupId: key.groupId, sessionId: key.sessionId);
});

/// Places of a plan in plan order; the key is the joined place ids.
final _planPlacesProvider =
    FutureProvider.autoDispose.family<List<PlaceModel>, String>((ref, key) {
  return PlacesRepository().loadPlacesByIds(key.split('|'));
});

final _originProvider =
    FutureProvider.autoDispose<({double lat, double lng})?>((ref) {
  return ref.read(groupControllerProvider.notifier).planningOrigin();
});

/// The day plan of a finished group session: the selected matches as a
/// walking route. The group admin chooses whether it ends or starts near
/// them and can reorder stops; everyone else sees the plan.
class DayPlanScreen extends ConsumerStatefulWidget {
  const DayPlanScreen({
    super.key,
    required this.groupId,
    required this.sessionId,
  });

  final String groupId;
  final String sessionId;

  @override
  ConsumerState<DayPlanScreen> createState() => _DayPlanScreenState();
}

class _DayPlanScreenState extends ConsumerState<DayPlanScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(selectedGroupIdProvider.notifier).updateState(widget.groupId);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content:
            Text(userMessage(e, fallback: l10n.errorSaveDayPlan, l10n: l10n)),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = (groupId: widget.groupId, sessionId: widget.sessionId);
    final session = ref.watch(_sessionProvider(key));
    final group = ref.watch(groupControllerProvider).value;
    final user = ref.watch(authControllerProvider).value;
    final isAdmin = group != null && group.ownerUid == user?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dayPlanTitle)),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: userMessage(e, fallback: l10n.errorGeneric, l10n: l10n),
          onRetry: () => ref.invalidate(_sessionProvider(key)),
        ),
        data: (s) {
          final plan = s?.dayPlan;
          if (plan == null || plan.placeIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IconBadge(icon: Icons.route, tone: ChipTone.sky),
                  const SizedBox(height: AppSizes.space16),
                  Text(l10n.dayPlanNone,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }
          final places =
              ref.watch(_planPlacesProvider(plan.placeIds.join('|')));
          return places.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message:
                  userMessage(e, fallback: l10n.errorLoadResults, l10n: l10n),
              onRetry: () =>
                  ref.invalidate(_planPlacesProvider(plan.placeIds.join('|'))),
            ),
            data: (list) => _PlanBody(
              plan: plan,
              places: list,
              isAdmin: isAdmin,
              busy: _busy,
              onModeChanged: (endNearOrigin) => _run(() async {
                final origin = await ref.read(_originProvider.future);
                await ref.read(groupControllerProvider.notifier).createDayPlan(
                      widget.sessionId,
                      list,
                      endNearOrigin: endNearOrigin,
                      origin: origin,
                    );
              }),
              onReorder: (ids) => _run(
                  () => ref.read(groupControllerProvider.notifier).saveDayPlan(
                        widget.sessionId,
                        DayPlan(
                            placeIds: ids, endNearOrigin: plan.endNearOrigin),
                      )),
            ),
          );
        },
      ),
    );
  }
}

class _PlanBody extends ConsumerStatefulWidget {
  const _PlanBody({
    required this.plan,
    required this.places,
    required this.isAdmin,
    required this.busy,
    required this.onModeChanged,
    required this.onReorder,
  });

  final DayPlan plan;
  final List<PlaceModel> places;
  final bool isAdmin;
  final bool busy;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<List<String>> onReorder;

  @override
  ConsumerState<_PlanBody> createState() => _PlanBodyState();
}

class _PlanBodyState extends ConsumerState<_PlanBody> {
  late List<PlaceModel> _stops = List.of(widget.places);

  @override
  void didUpdateWidget(covariant _PlanBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.places != widget.places) _stops = List.of(widget.places);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final routeStops = [
      for (final p in _stops) RouteStop(id: p.id, lat: p.lat, lng: p.lng),
    ];
    var total = 0.0;
    for (var i = 1; i < routeStops.length; i++) {
      total += legKm(routeStops[i - 1], routeStops[i]);
    }

    Widget? header;
    if (widget.isAdmin) {
      final origin = ref.watch(_originProvider).value;
      final near = origin != null && isOriginNear(origin, routeStops);
      header = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.sports_score_outlined),
                tooltip: l10n.dayPlanEndNearMe,
                label: Text(
                  l10n.dayPlanEndShort,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.my_location_outlined),
                tooltip: l10n.dayPlanStartNearMe,
                label: Text(
                  l10n.dayPlanStartShort,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            selected: {widget.plan.endNearOrigin},
            onSelectionChanged: widget.busy
                ? null
                : (selection) => widget.onModeChanged(selection.first),
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            !near
                ? l10n.dayPlanNoLocation
                : widget.plan.endNearOrigin
                    ? l10n.dayPlanEndNearMeHint
                    : l10n.dayPlanStartNearMeHint,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    } else {
      header = Text(
        l10n.dayPlanAdminOnly,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge,
              AppSizes.space8, AppSizes.screenEdge, AppSizes.space8),
          child: header,
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSizes.screenEdge),
            itemCount: _stops.length,
            onReorderItem: (oldIndex, newIndex) {
              if (!widget.isAdmin || widget.busy) return;
              setState(
                  () => _stops.insert(newIndex, _stops.removeAt(oldIndex)));
              widget.onReorder([for (final p in _stops) p.id]);
            },
            itemBuilder: (context, index) {
              final place = _stops[index];
              final leg = index == 0
                  ? null
                  : legKm(routeStops[index - 1], routeStops[index]);
              return Padding(
                key: ValueKey(place.id),
                padding: const EdgeInsets.only(bottom: AppSizes.space12),
                child: Ticket(
                  onTap: () => context.push('/place/${place.id}'),
                  padding: EdgeInsets.fromLTRB(AppSizes.space12,
                      AppSizes.space12, widget.isAdmin ? 0 : 12, 12),
                  child: Row(
                    children: [
                      _StopNumber(index + 1),
                      const SizedBox(width: AppSizes.space12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: PlacePhoto(place: place),
                        ),
                      ),
                      const SizedBox(width: AppSizes.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.nameFor(lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium,
                            ),
                            if (leg != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                l10n.dayPlanLeg(_distance(context, l10n, leg)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.isAdmin)
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSizes.space12),
                            child: Icon(Icons.drag_indicator),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge,
                AppSizes.space4, AppSizes.screenEdge, AppSizes.space16),
            child: _RouteStub(
              total: _stops.length > 1
                  ? l10n.dayPlanTotal(_distance(context, l10n, total))
                  : null,
              capped: _stops.length > MapsLauncher.maxRouteStops,
              onOpen: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await MapsLauncher.openRoute(
                      [for (final p in _stops) (lat: p.lat, lng: p.lng)]);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                    content: Text(userMessage(e,
                        fallback: l10n.errorOpenMaps, l10n: l10n)),
                  ));
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Small ink disc with the stop's number.
class _StopNumber extends StatelessWidget {
  const _StopNumber(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.onSurface, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.surface,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

/// The route's ticket stub: total distance above the perforation, the
/// one orange "open route" action below it.
class _RouteStub extends StatelessWidget {
  const _RouteStub({
    required this.total,
    required this.capped,
    required this.onOpen,
  });

  final String? total;
  final bool capped;
  final VoidCallback onOpen;

  static const _topHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final button = ElevatedButton.icon(
      icon: const Icon(Icons.directions_walk),
      label: Text(l10n.dayPlanOpenRoute),
      onPressed: onOpen,
    );
    if (total == null && !capped) return button;
    return Ticket(
      notchFromTop: total == null ? null : _topHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (total != null)
            SizedBox(
              height: _topHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 18, color: scheme.onSurface),
                  const SizedBox(width: AppSizes.space8),
                  Flexible(
                    child: Text(
                      total!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (capped) ...[
                  Text(
                    l10n.dayPlanRouteCapped,
                    textAlign: TextAlign.center,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSizes.space8),
                ],
                button,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _distance(BuildContext context, AppLocalizations l10n, double km) {
  if (km < 1) return l10n.distanceMetersValue((km * 1000).round());
  final locale = Localizations.localeOf(context).toLanguageTag();
  return l10n.distanceKmValue(NumberFormat('0.0', locale).format(km));
}
