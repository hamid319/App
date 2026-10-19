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
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      border: Border(
                        bottom: BorderSide(color: Theme.of(context).colorScheme.primaryContainer),
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
                          initialResults: results,
                          isAdmin: group.ownerUid == user?.uid,
                          sessionId: sessionId,
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

class _ResultsList extends ConsumerStatefulWidget {
  final List<ResultItem> initialResults;
  final bool isAdmin;
  final String sessionId;

  const _ResultsList({
    required this.initialResults,
    required this.isAdmin,
    required this.sessionId,
  });

  @override
  ConsumerState<_ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends ConsumerState<_ResultsList> {
  late List<ResultItem> _results;

  @override
  void initState() {
    super.initState();
    _results = List.from(widget.initialResults);
  }

  @override
  void didUpdateWidget(covariant _ResultsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the new initial results are completely different (e.g. session switched), update them
    // Otherwise, we keep our local sorted state to prevent jitter during drag/drop
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.initialResults.length != widget.initialResults.length) {
      _results = List.from(widget.initialResults);
    }
  }

  void _saveOrder() {
    ref.read(groupControllerProvider.notifier).updateSessionOrder(
          widget.sessionId,
          _results.map((r) => r.place.id).toList(),
        );
  }

  void _removeItem(int index) {
    setState(() {
      _results.removeAt(index);
    });
    _saveOrder();
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(16.0),
      itemCount: _results.length,
      onReorder: (oldIndex, newIndex) {
        if (!widget.isAdmin) return;
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = _results.removeAt(oldIndex);
          _results.insert(newIndex, item);
        });
        _saveOrder();
      },
      itemBuilder: (context, index) {
        final result = _results[index];
        return ListTile(
          key: ValueKey(result.place.id),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          leading: _ResultThumbnail(place: result.place),
          title: Text(result.place.name),
          subtitle:
              result.place.address != null ? Text(result.place.address!) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, color: Theme.of(context).colorScheme.error, size: 18),
              const SizedBox(width: 6),
              Text('${result.likes}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (widget.isAdmin) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  onPressed: () => _removeItem(index),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          onTap: () => context.push('/place/${result.place.id}'),
        );
      },
    );
  }
}
