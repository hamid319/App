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
            return Center(child: Text(l10n.dayPlanNone));
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
            segments: [
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.hotel_outlined),
                label: Text(l10n.dayPlanEndNearMe),
              ),
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.near_me_outlined),
                label: Text(l10n.dayPlanStartNearMe),
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
              return Card(
                key: ValueKey(place.id),
                margin: const EdgeInsets.only(bottom: AppSizes.space8),
                child: ListTile(
                  onTap: () => context.push('/place/${place.id}'),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: PlacePhoto(place: place),
                        ),
                      ),
                      Positioned(
                        left: -6,
                        top: -6,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: scheme.primary,
                          child: Text(
                            '${index + 1}',
                            style: text.labelSmall
                                ?.copyWith(color: scheme.onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    place.nameFor(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: leg == null
                      ? null
                      : Text(l10n.dayPlanLeg(_distance(context, l10n, leg))),
                  trailing: widget.isAdmin
                      ? ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_indicator),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge,
                AppSizes.space8, AppSizes.screenEdge, AppSizes.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_stops.length > 1)
                  Text(
                    l10n.dayPlanTotal(_distance(context, l10n, total)),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                if (_stops.length > MapsLauncher.maxRouteStops)
                  Text(
                    l10n.dayPlanRouteCapped,
                    textAlign: TextAlign.center,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: AppSizes.space8),
                FilledButton.icon(
                  icon: const Icon(Icons.directions_walk),
                  label: Text(l10n.dayPlanOpenRoute),
                  onPressed: () async {
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _distance(BuildContext context, AppLocalizations l10n, double km) {
  if (km < 1) return l10n.distanceMetersValue((km * 1000).round());
  final locale = Localizations.localeOf(context).toLanguageTag();
  return l10n.distanceKmValue(NumberFormat('0.0', locale).format(km));
}
