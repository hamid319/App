import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../common/models/place_model.dart';
import '../../../common/utils/place_photo_url_builder.dart';
import '../../../common/models/group_session_model.dart';
import '../../../common/widgets/error_view.dart';
import '../logic/group_controller.dart';
import '../../auth/logic/auth_controller.dart';
import '../../swipe/data/places_repository.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../common/widgets/skeleton.dart';
import '../widgets/match_celebration.dart';
import '../../../app/theme.dart';

class ResultItem {
  final PlaceModel place;
  final int likes;

  const ResultItem({required this.place, required this.likes});
}

class SessionResultsQuery {
  final String groupId;
  final String sessionId;

  const SessionResultsQuery({
    required this.groupId,
    required this.sessionId,
  });

  @override
  bool operator ==(Object other) {
    return other is SessionResultsQuery &&
        other.groupId == groupId &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode => Object.hash(groupId, sessionId);
}

final completedSessionsProvider =
    FutureProvider.family<List<GroupSessionModel>, String>((ref, groupId) {
  return ref.read(groupRepositoryProvider).getCompletedSessions(groupId);
});

class SelectedSessionIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void updateState(String? value) => state = value;
}

final selectedSessionIdProvider =
    NotifierProvider.family<SelectedSessionIdNotifier, String?, String>(
        (_) => SelectedSessionIdNotifier());

final sessionResultsProvider =
    FutureProvider.family<List<ResultItem>, SessionResultsQuery>(
  (ref, query) async {
    final repo = ref.read(groupRepositoryProvider);
    final session = await repo.getSession(
      groupId: query.groupId,
      sessionId: query.sessionId,
    );
    if (session == null) return [];

    final qualified = await repo.getQualifiedPlaces(
      groupId: query.groupId,
      sessionId: query.sessionId,
      participantCount: session.participants.length,
    );

    final placesRepo = PlacesRepository();
    final results = <ResultItem>[];
    for (final vote in qualified) {
      final placeId = vote['placeId'] as String?;
      if (placeId == null) continue;
      final likes = (vote['likes'] as num?)?.toInt() ?? 0;
      final place = await placesRepo.getPlaceById(placeId);
      if (place == null) continue;
      results.add(ResultItem(place: place, likes: likes));
    }

    if (session.orderedPlaceIds != null) {
      final map = {for (var r in results) r.place.id: r};
      final orderedResults = <ResultItem>[];
      for (final pid in session.orderedPlaceIds!) {
        if (map.containsKey(pid)) orderedResults.add(map[pid]!);
      }
      return orderedResults;
    } else {
      results.sort((a, b) => b.likes.compareTo(a.likes));
      return results;
    }
  },
);

class GroupMatchesScreen extends ConsumerStatefulWidget {
  final String groupId;

  /// Show the match moment for the newest session once its results load.
  final bool celebrate;

  const GroupMatchesScreen({
    super.key,
    required this.groupId,
    this.celebrate = false,
  });

  @override
  ConsumerState<GroupMatchesScreen> createState() => _GroupMatchesScreenState();
}

class _GroupMatchesScreenState extends ConsumerState<GroupMatchesScreen> {
  bool _celebrated = false;

  void _maybeCelebrate(GroupSessionModel newest, String shownSessionId,
      List<ResultItem> results) {
    if (!widget.celebrate || _celebrated || results.isEmpty) return;
    if (shownSessionId != newest.sessionId) return;
    _celebrated = true;
    final top = results.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showMatchCelebration(
        context,
        place: top.place,
        likes: top.likes,
        participants: newest.participants,
        onOpenPlace: () => context.push('/place/${top.place.id}'),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(selectedGroupIdProvider.notifier).updateState(widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupControllerProvider);
    final user = ref.watch(authControllerProvider).value;
    final sessionsAsync = ref.watch(completedSessionsProvider(widget.groupId));
    final selectedSessionId =
        ref.watch(selectedSessionIdProvider(widget.groupId));

    if (sessionsAsync.hasValue &&
        (selectedSessionId == null || selectedSessionId.isEmpty)) {
      final sessions = sessionsAsync.value ?? [];
      if (sessions.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(selectedSessionIdProvider(widget.groupId).notifier)
              .updateState(sessions.first.sessionId);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.groupResultsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              ref.invalidate(completedSessionsProvider(widget.groupId));
              final sessionId =
                  ref.read(selectedSessionIdProvider(widget.groupId));
              if (sessionId != null) {
                ref.invalidate(sessionResultsProvider(
                  SessionResultsQuery(
                    groupId: widget.groupId,
                    sessionId: sessionId,
                  ),
                ));
              }
            },
          ),
        ],
      ),
      body: groupState.when(
        loading: () => const SkeletonList(),
        error: (error, stack) => ErrorView(
          message: userMessage(error, fallback: context.l10n.errorGeneric, l10n: context.l10n),
          title: context.l10n.failedToLoadGroup,
          onRetry: () => ref.invalidate(groupControllerProvider),
        ),
        data: (group) {
          if (group == null) {
            return ErrorView(
              message: context.l10n.noGroupMessage,
              title: context.l10n.noGroupTitle,
              icon: Icons.group_off,
              onRetry: () => context.go('/home'),
            );
          }

          return sessionsAsync.when(
            loading: () =>
                const SkeletonList(),
            error: (error, stack) => ErrorView(
              message: userMessage(error, fallback: context.l10n.errorLoadSessions, l10n: context.l10n),
              onRetry: () =>
                  ref.invalidate(completedSessionsProvider(widget.groupId)),
            ),
            data: (sessions) {
              if (sessions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 80,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.l10n.noCompletedSessionsTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.noCompletedSessionsBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.explore),
                        label: Text(context.l10n.discoverTitle),
                      ),
                    ],
                  ),
                );
              }

              final sessionId = selectedSessionId ?? sessions.first.sessionId;
              final resultsAsync = ref.watch(sessionResultsProvider(
                SessionResultsQuery(
                  groupId: widget.groupId,
                  sessionId: sessionId,
                ),
              ));

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<String>(
                            value: sessionId,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            onChanged: (value) {
                              if (value == null) return;
                              ref
                                  .read(
                                      selectedSessionIdProvider(widget.groupId)
                                          .notifier)
                                  .updateState(value);
                            },
                            items: sessions
                                .map(
                                  (session) => DropdownMenuItem(
                                    value: session.sessionId,
                                    child: Text(
                                      _formatSessionLabel(context, session),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: resultsAsync.when(
                      loading: () =>
                          const SkeletonList(),
                      error: (error, stack) => ErrorView(
                        message: userMessage(error, fallback: context.l10n.errorLoadResults, l10n: context.l10n),
                        onRetry: () => ref.invalidate(sessionResultsProvider(
                          SessionResultsQuery(
                            groupId: widget.groupId,
                            sessionId: sessionId,
                          ),
                        )),
                      ),
                      data: (results) {
                        _maybeCelebrate(sessions.first, sessionId, results);
                        if (results.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  size: 80,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  context.l10n.noQualifiedPlacesTitle,
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.l10n.noQualifiedPlacesBody,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          );
                        }

                        return _ResultsList(
                          results: results,
                          isAdmin: group.ownerUid == user?.uid,
                          groupId: widget.groupId,
                          session: sessions.firstWhere(
                            (s) => s.sessionId == sessionId,
                            orElse: () => sessions.first,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ResultThumbnail extends StatelessWidget {
  final PlaceModel place;

  const _ResultThumbnail({required this.place});

  @override
  Widget build(BuildContext context) {
    final imageUrls = resolvePlacePhotoUrls(place);
    if (imageUrls.isEmpty) {
      return _buildImagePlaceholder(context);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrls.first,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        placeholder: (context, url) => const SkeletonImage(),
        errorWidget: (context, url, error) => _buildImagePlaceholder(context),
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.place,
          size: 28,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _formatSessionLabel(BuildContext context, GroupSessionModel session) {
  final endedAt = session.endedAt;
  final dateLabel = endedAt == null
      ? context.l10n.sessionInProgress
      : endedAt.toLocal().toIso8601String().split('T').first;
  return '${session.destination} · $dateLabel';
}

/// The session's matches. The group admin ticks the ones for the day plan
/// and creates it; everyone can open an existing plan.
class _ResultsList extends ConsumerStatefulWidget {
  final List<ResultItem> results;
  final bool isAdmin;
  final String groupId;
  final GroupSessionModel session;

  const _ResultsList({
    required this.results,
    required this.isAdmin,
    required this.groupId,
    required this.session,
  });

  @override
  ConsumerState<_ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends ConsumerState<_ResultsList> {
  late Set<String> _selected = _initialSelection();
  bool _busy = false;

  Set<String> _initialSelection() {
    final ids = {for (final r in widget.results) r.place.id};
    return {...?widget.session.dayPlan?.placeIds}.intersection(ids);
  }

  @override
  void didUpdateWidget(covariant _ResultsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.sessionId != widget.session.sessionId) {
      _selected = _initialSelection();
    }
  }

  void _openPlan() => context
      .push('/day-plan/${widget.groupId}/${widget.session.sessionId}');

  Future<void> _createPlan() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(groupControllerProvider.notifier);
    // In ranking order, so without a usable location the route starts at
    // the group's favourite.
    final places = [
      for (final r in widget.results)
        if (_selected.contains(r.place.id)) r.place,
    ];
    setState(() => _busy = true);
    try {
      final origin = await controller.planningOrigin();
      await controller.createDayPlan(
        widget.session.sessionId,
        places,
        endNearOrigin: widget.session.dayPlan?.endNearOrigin ?? true,
        origin: origin,
      );
      ref.invalidate(completedSessionsProvider(widget.groupId));
      if (mounted) _openPlan();
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final like = context.swipeColors.like;
    final hasPlan = widget.session.dayPlan?.placeIds.isNotEmpty ?? false;
    return Column(
      children: [
        if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              l10n.dayPlanSelectHint,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: widget.results.length,
            itemBuilder: (context, index) {
              final result = widget.results[index];
              final podium = index < 3;
              final selected = _selected.contains(result.place.id);
              return Padding(
                key: ValueKey(result.place.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.push('/place/${result.place.id}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: text.headlineSmall?.copyWith(
                                color: podium ? scheme.primary : scheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ResultThumbnail(place: result.place),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.place.nameFor(
                                    Localizations.localeOf(context).languageCode,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleMedium,
                                ),
                                if (result.place.address != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    result.place.address!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall
                                        ?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: like.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.favorite, size: 13, color: like),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${result.likes}',
                                        style: text.labelMedium?.copyWith(
                                          color: like,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isAdmin)
                            Checkbox(
                              value: selected,
                              semanticLabel: l10n.dayPlanSelectPlace,
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() {
                                        if (value == true) {
                                          _selected.add(result.place.id);
                                        } else {
                                          _selected.remove(result.place.id);
                                        }
                                      }),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.isAdmin || hasPlan)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isAdmin)
                    FilledButton.icon(
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.route),
                      label: Text(l10n.dayPlanCreate(_selected.length)),
                      onPressed:
                          _selected.isEmpty || _busy ? null : _createPlan,
                    ),
                  if (hasPlan) ...[
                    if (widget.isAdmin) const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: Text(l10n.dayPlanView),
                      onPressed: _openPlan,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
