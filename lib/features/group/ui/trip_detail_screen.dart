import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/place_model.dart';
import '../../../common/models/trip_idea.dart';
import '../../../common/models/trip_poll.dart';
import '../../../common/utils/group_swipes.dart';
import '../../../common/utils/passport_stamps.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/link_launcher.dart';
import '../../../l10n/l10n.dart';
import '../../../main_providers.dart';
import '../../auth/logic/auth_controller.dart';
import '../logic/group_controller.dart';
import '../logic/trip_controller.dart';
import '../widgets/idea_sheet.dart';
import '../widgets/poll_sheet.dart';
import '../widgets/sync_badge.dart';
import '../widgets/trip_members_sheet.dart';
import '../widgets/trip_ui.dart';

/// The segments of a trip.
enum TripSection { plan, map, journal, costs }

/// Segmented control shared by the trip screens. Map, journal and costs
/// are their own routes on top of the plan.
class TripSectionControl extends StatelessWidget {
  const TripSectionControl({
    super.key,
    required this.groupId,
    required this.selected,
  });

  final String groupId;
  final TripSection selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TripSegmentedControl(
      segments: [
        TripSegment(l10n.tripTabPlan),
        TripSegment(l10n.tripTabMap),
        TripSegment(l10n.tripTabJournal),
        TripSegment(l10n.tripTabCosts),
      ],
      selected: selected.index,
      onSelected: (i) {
        final target = TripSection.values[i];
        if (target == selected) return;
        // Map, journal and costs open on top of the plan and replace each
        // other.
        void open(String path) => selected == TripSection.plan
            ? context.push(path)
            : context.pushReplacement(path);
        switch (target) {
          case TripSection.plan:
            context.canPop() ? context.pop() : context.go('/trip/$groupId');
          case TripSection.map:
            open('/trip/$groupId/day/0');
          case TripSection.journal:
            open('/trip/$groupId/journal');
          case TripSection.costs:
            open('/trip/$groupId/costs');
        }
      },
    );
  }
}

/// A trip's plan: polls, the wishlist and the way into the day plan.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  bool _building = false;

  @override
  void initState() {
    super.initState();
    // The swipe session flows work on the selected group.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(selectedGroupIdProvider.notifier).updateState(widget.groupId);
    });
  }

  Future<void> _buildPlan(GroupModel group, List<TripIdea> ideas) async {
    final l10n = context.l10n;
    setState(() => _building = true);
    try {
      await ref.read(tripActionsProvider.notifier).buildPlan(group, ideas);
      if (mounted) context.push('/trip/${group.groupId}/day/0');
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
    final uid = ref.watch(authControllerProvider).value?.uid ?? '';

    return Scaffold(
      body: trip.when(
        loading: () => WithBackButton(
          fallbackRoute: '/trips',
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => WithBackButton(
          fallbackRoute: '/trips',
          child: ErrorView(
            message: userMessage(e, fallback: l10n.errorLoadGroups, l10n: l10n),
            onRetry: () => ref.invalidate(userGroupsProvider),
          ),
        ),
        data: (group) {
          if (group == null) {
            return ErrorView(
              message: l10n.groupNotFound,
              onRetry: () => context.go('/trips'),
            );
          }
          final ideas =
              ref.watch(tripWishlistProvider(widget.groupId)).value ?? const [];
          final plannable = ideas.where((i) => i.placeId != null).length;
          return Stack(
            children: [
              _PlanBody(group: group, uid: uid, ideas: ideas),
              BottomFloat(
                button: FloatingPrimaryButton(
                  label: plannable == 0
                      ? l10n.tripPlanNeedsIdeas
                      : l10n.tripBuildPlan(plannable),
                  icon: Icons.auto_awesome_rounded,
                  loading: _building,
                  onPressed:
                      plannable == 0 ? null : () => _buildPlan(group, ideas),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanBody extends ConsumerWidget {
  const _PlanBody(
      {required this.group, required this.uid, required this.ideas});

  final GroupModel group;
  final String uid;
  final List<TripIdea> ideas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final polls =
        ref.watch(tripPollsProvider(group.groupId)).value ?? const <TripPoll>[];
    final names = [
      for (final (i, id) in group.members.indexed)
        id == uid
            ? memberName(ref, id, l10n.tripYou)
            : memberName(ref, id, l10n.memberFallback(i + 1)),
    ];
    final subtitle = [
      tripDatesLabel(context, group),
      names.join(', '),
    ].whereType<String>().join(' · ');
    final topPadding = MediaQuery.paddingOf(context).top;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 230,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TripCover(group: group),
              Positioned(
                top: topPadding + 8,
                left: 16,
                child: GlassButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: l10n.back,
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/trips'),
                ),
              ),
              Positioned(
                top: topPadding + 8,
                right: 16,
                child: GlassButton(
                  icon: Icons.person_add_alt_1_rounded,
                  tooltip: l10n.tripInviteFriends,
                  label: l10n.tripInvite,
                  onTap: () => copyTripInvite(context, group),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -24),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(group.groupName ?? l10n.unnamedGroup,
                          style: text.headlineMedium),
                    ),
                    TripSyncBadge(groupId: group.groupId),
                  ],
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => showTripMembersSheet(context, group, uid),
                  child: Text(
                    subtitle,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 16),
                TripSectionControl(
                    groupId: group.groupId, selected: TripSection.plan),
                const SizedBox(height: 16),
                // During the trip, up top: the passport check-in.
                if (_canCheckIn(group)) ...[
                  InsetGroup(children: [_CheckInRow(group: group)]),
                  const SizedBox(height: 16),
                ],
                for (final poll in polls) ...[
                  _PollCard(group: group, poll: poll, uid: uid),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showPollSheet(context, group.groupId),
                    icon: const Icon(Icons.how_to_vote_outlined, size: 20),
                    label: Text(l10n.tripNewPoll),
                  ),
                ),
                const SizedBox(height: 8),
                TripSectionHeader(
                  l10n.tripWishlist,
                  action: l10n.tripAddIdea,
                  onAction: () => showIdeaSheet(context, group),
                ),
                const SizedBox(height: 8),
                _Wishlist(group: group, uid: uid, ideas: ideas),
                const SizedBox(height: 24),
                _MoreSection(group: group, uid: uid, ideas: ideas),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PollCard extends ConsumerWidget {
  const _PollCard({required this.group, required this.poll, required this.uid});

  final GroupModel group;
  final TripPoll poll;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final voters = poll.voterCount;
    final mine = poll.voteOf(uid);
    var top = 0;
    for (final o in poll.options) {
      final v = poll.votesFor(o.id);
      if (v > top) top = v;
    }

    void vote(String optionId) {
      final actions = ref.read(tripActionsProvider.notifier);
      runTripWrite(context, () => actions.vote(group.groupId, poll, optionId));
    }

    return TripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(poll.question, style: text.titleMedium)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  poll.closed
                      ? l10n.tripPollClosed
                      : l10n.tripPollVoted(voters, group.members.length),
                  style:
                      text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              if (poll.createdBy == uid)
                SizedBox(
                  height: 24,
                  width: 32,
                  child: PopupMenuButton<bool>(
                    padding: EdgeInsets.zero,
                    tooltip: l10n.moreOptions,
                    icon: Icon(Icons.more_horiz_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                    onSelected: (close) {
                      final actions = ref.read(tripActionsProvider.notifier);
                      runTripWrite(
                          context,
                          () => actions.setPollClosed(
                              group.groupId, poll.id, close));
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: !poll.closed,
                        child: Text(poll.closed
                            ? l10n.tripPollReopen
                            : l10n.tripPollClose),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, option) in poll.options.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _PollOptionBar(
              label: option.label,
              votes: poll.votesFor(option.id),
              fraction: voters == 0 ? 0 : poll.votesFor(option.id) / voters,
              leading: top > 0 && poll.votesFor(option.id) == top,
              mine: mine == option.id,
              onTap: poll.closed ? null : () => vote(option.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _PollOptionBar extends StatelessWidget {
  const _PollOptionBar({
    required this.label,
    required this.votes,
    required this.fraction,
    required this.leading,
    required this.mine,
    required this.onTap,
  });

  final String label;
  final int votes;
  final double fraction;
  final bool leading;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fill = leading
        ? scheme.primary.withValues(alpha: 0.16)
        : scheme.surfaceContainerHigh;
    return Semantics(
      button: onTap != null,
      selected: mine,
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: ColoredBox(color: fill),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      if (mine) ...[
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                              fontWeight:
                                  leading ? FontWeight.w600 : FontWeight.w400),
                        ),
                      ),
                      Text(
                        '$votes',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: leading
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Wishlist extends ConsumerWidget {
  const _Wishlist(
      {required this.group, required this.uid, required this.ideas});

  final GroupModel group;
  final String uid;
  final List<TripIdea> ideas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (ideas.isEmpty) {
      return TripCard(
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.tripWishlistEmpty,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      );
    }
    final ids = [
      for (final i in ideas)
        if (i.placeId != null) i.placeId!,
    ];
    final places = ref.watch(tripPlacesProvider(placesKey(ids))).value ??
        const <PlaceModel>[];
    final byId = {for (final p in places) p.id: p};
    return InsetGroup(
      separatorIndent: 14 + 48 + 12,
      children: [
        for (final idea in ideas)
          _IdeaRow(
            group: group,
            idea: idea,
            place: byId[idea.placeId],
            uid: uid,
          ),
      ],
    );
  }
}

class _IdeaRow extends ConsumerWidget {
  const _IdeaRow({
    required this.group,
    required this.idea,
    required this.place,
    required this.uid,
  });

  final GroupModel group;
  final TripIdea idea;
  final PlaceModel? place;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final author = idea.addedBy == uid
        ? l10n.tripIdeaByYou
        : l10n.tripIdeaBy(memberName(ref, idea.addedBy, l10n.userFallbackName));
    final subtitle = [
      author,
      switch (idea.source) {
        IdeaSource.swipe => l10n.tripIdeaFromSwipe,
        IdeaSource.link => l10n.tripIdeaFromLink,
        IdeaSource.manual => null,
      },
    ].whereType<String>().join(' · ');
    final liked = idea.isLikedBy(uid);
    final placeModel = place;

    void open() {
      if (idea.placeId != null) {
        context.push('/place/${idea.placeId}');
      } else if (idea.source == IdeaSource.link) {
        LinkLauncher.open(idea.title).catchError((_) {});
      }
    }

    Future<void> delete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.tripIdeaDeleteTitle),
          content: Text(idea.title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error),
              child: Text(l10n.delete),
            ),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        final actions = ref.read(tripActionsProvider.notifier);
        runTripWrite(context, () => actions.deleteIdea(group.groupId, idea.id));
      }
    }

    return InkWell(
      onTap: open,
      // A swipe match has no idea document to delete; a veto removes it.
      onLongPress:
          idea.addedBy == uid && !isSwipeMatchIdea(idea) ? delete : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: 48,
                child: placeModel != null
                    ? PlacePhoto(place: placeModel)
                    : ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: Icon(
                          idea.source == IdeaSource.link
                              ? Icons.link_rounded
                              : Icons.lightbulb_outline_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placeModel?.nameFor(lang) ?? idea.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              selected: liked,
              label: l10n.tripLikeIdea,
              child: Material(
                color: liked
                    ? scheme.primary.withValues(alpha: 0.16)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    final actions = ref.read(tripActionsProvider.notifier);
                    runTripWrite(
                        context, () => actions.toggleLike(group.groupId, idea));
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color:
                              liked ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${idea.likes}',
                          style: text.labelLarge?.copyWith(
                            fontSize: 14,
                            color: liked
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Day plan, the group swipe round and the members.
class _MoreSection extends ConsumerWidget {
  const _MoreSection(
      {required this.group, required this.uid, required this.ideas});

  final GroupModel group;
  final String uid;
  final List<TripIdea> ideas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = group.groupId;
    final city = group.location?.cityName ?? '';
    final plan = group.tripPlan;
    final places = ref.watch(tripSwipePlacesProvider(id)).value;
    final mine = (ref.watch(tripSwipesProvider(id)).value ?? const [])
        .where((m) => m.uid == uid)
        .firstOrNull;
    final left =
        places?.where((p) => !(mine?.votes.containsKey(p.id) ?? false)).length;

    return InsetGroup(
      separatorIndent: 14 + 28 + 12,
      children: [
        // Open to every member at any time; matches go to the wishlist.
        _ActionRow(
          icon: Icons.swipe_rounded,
          title: l10n.tripSwipeTitle,
          subtitle: left == null || mine == null
              ? l10n.tripSwipeSubtitle(city)
              : l10n.tripSwipeLeft(left),
          onTap: () => context.push('/trip/$id/swipe'),
        ),
        if (plan != null && !plan.isEmpty)
          _ActionRow(
            icon: Icons.map_outlined,
            title: l10n.tripShowDayPlan,
            subtitle: l10n.tripPlanStops(plan.stopCount),
            onTap: () => context.push('/trip/$id/day/0'),
          ),
        _ActionRow(
          icon: Icons.group_outlined,
          title: l10n.membersHeader(group.members.length),
          trailing: AvatarRow(memberIds: group.members, size: 26, max: 4),
          onTap: () => showTripMembersSheet(context, group, uid),
        ),
      ],
    );
  }
}

bool _canCheckIn(GroupModel group) {
  final place = group.location;
  return place != null &&
      (place.lat != 0 || place.lng != 0) &&
      isTripNow(group, DateTime.now());
}

/// During the trip: check in on site for the city's passport stamp.
class _CheckInRow extends ConsumerStatefulWidget {
  const _CheckInRow({required this.group});

  final GroupModel group;

  @override
  ConsumerState<_CheckInRow> createState() => _CheckInRowState();
}

class _CheckInRowState extends ConsumerState<_CheckInRow> {
  bool _busy = false;

  Future<void> _checkIn() async {
    final l10n = context.l10n;
    final city = widget.group.location!.cityName;
    setState(() => _busy = true);
    try {
      final km =
          await ref.read(tripActionsProvider.notifier).checkIn(widget.group);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showTripSnack(context,
          km == null ? l10n.checkInDone(city) : l10n.checkInTooFar(km, city));
    } catch (_) {
      // No permission, location off or no fix in time.
      if (mounted) showTripSnack(context, l10n.checkInNoLocation, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final place = widget.group.location!;
    final done = ref.watch(checkInsProvider).value?[stampKey(place)] != null;
    return _ActionRow(
      icon: done ? Icons.verified_rounded : Icons.approval_rounded,
      title: done ? l10n.checkInStamped : l10n.checkInTitle,
      subtitle:
          done ? l10n.checkInOpenPass : l10n.checkInSubtitle(place.cityName),
      trailing: _busy
          ? const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      onTap: _busy ? null : (done ? () => context.push('/passport') : _checkIn),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Icon(icon,
                  color: enabled ? scheme.primary : scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: text.bodyLarge?.copyWith(
                          color: enabled
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: text.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            if (enabled)
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
