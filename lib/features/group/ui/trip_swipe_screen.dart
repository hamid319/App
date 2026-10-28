import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/place_model.dart';
import '../../../common/utils/group_swipes.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/swipe_deck.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../auth/logic/auth_controller.dart';
import '../logic/trip_controller.dart';
import '../widgets/trip_ui.dart';

/// The trip's swipe deck. Always open: every member swipes through the
/// city's places whenever they like, and a place the group agrees on goes
/// onto the wishlist on its own. Each member has one veto.
class TripSwipeScreen extends ConsumerStatefulWidget {
  const TripSwipeScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<TripSwipeScreen> createState() => _TripSwipeScreenState();
}

class _TripSwipeScreenState extends ConsumerState<TripSwipeScreen> {
  /// Answered here but maybe not yet back from the swipes stream, so the
  /// card does not flash up again.
  final _answered = <String>{};

  /// The last vote, for undo (not a veto).
  String? _last;

  String get _groupId => widget.groupId;

  void _vote(PlaceModel place, SwipeVote vote, String uid) {
    final l10n = context.l10n;
    final members = ref.read(tripProvider(_groupId)).value?.members ?? const [];
    final before = ref.read(tripSwipeTallyProvider(_groupId))[place.id];
    setState(() {
      _answered.add(place.id);
      _last = place.id;
    });
    runTripWrite(
        context,
        () => ref
            .read(tripActionsProvider.notifier)
            .swipe(_groupId, place.id, vote));
    if (vote == SwipeVote.nope || members.length < 2) return;

    // Did this vote make it a match? Then celebrate with who else wants it.
    final others = [
      for (final u in before?.likedBy ?? const <String>[])
        if (u != uid) u,
    ];
    final after = PlaceTally(
      placeId: place.id,
      likedBy: [...others, uid],
      superLikedBy: [
        for (final u in before?.superLikedBy ?? const <String>[])
          if (u != uid) u,
        if (vote == SwipeVote.superLike) uid,
      ],
      vetoedBy: before?.vetoedBy ?? const [],
    );
    final wasMatch = before?.isMatch(members.length) ?? false;
    if (wasMatch || !after.isMatch(members.length) || others.isEmpty) return;
    HapticFeedback.heavyImpact();
    final names = [
      for (final u in others) memberName(ref, u, l10n.userFallbackName),
    ].join(', ');
    _showMatch(place, names);
  }

  void _undo() {
    final placeId = _last;
    if (placeId == null) return;
    setState(() {
      _answered.remove(placeId);
      _last = null;
    });
    runTripWrite(
        context,
        () => ref
            .read(tripActionsProvider.notifier)
            .swipe(_groupId, placeId, null));
  }

  Future<void> _veto(
      PlaceModel place, String? currentVeto, List<PlaceModel> places) async {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final name = place.nameFor(lang);
    String? current;
    if (currentVeto != null && currentVeto != place.id) {
      current = places
              .where((p) => p.id == currentVeto)
              .map((p) => p.nameFor(lang))
              .firstOrNull ??
          currentVeto;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.tripSwipeVetoTitle),
        content: Text(current == null
            ? l10n.tripSwipeVetoBody(name)
            : l10n.tripSwipeVetoMove(current, name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error),
            child: Text(l10n.tripSwipeVetoConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _answered.add(place.id);
      _last = null;
    });
    runTripWrite(
        context,
        () =>
            ref.read(tripActionsProvider.notifier).setVeto(_groupId, place.id));
    showTripSnack(context, l10n.tripSwipeVetoSet(name));
  }

  void _showMatch(PlaceModel place, String names) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final text = Theme.of(dialogContext).textTheme;
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          icon: const IconBadge(
              icon: Icons.favorite_rounded, tone: ChipTone.peach),
          title: Text(l10n.tripSwipeMatchTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(place.nameFor(lang),
                  textAlign: TextAlign.center, style: text.titleMedium),
              const SizedBox(height: 8),
              Text(
                l10n.tripSwipeMatchBody(names),
                textAlign: TextAlign.center,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.tripSwipeMatchContinue),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uid = ref.watch(authControllerProvider).value?.uid;
    final trip = ref.watch(tripProvider(_groupId)).value;
    final places = ref.watch(tripSwipePlacesProvider(_groupId));
    final swipes = ref.watch(tripSwipesProvider(_groupId));
    final mine = (swipes.value ?? const <MemberSwipes>[])
        .where((m) => m.uid == uid)
        .firstOrNull;

    final deck = [
      for (final p in places.value ?? const <PlaceModel>[])
        if (!(mine?.votes.containsKey(p.id) ?? false) &&
            !_answered.contains(p.id))
          p,
    ];

    Widget body;
    if (places.hasError || swipes.hasError) {
      body = ErrorView(
        message: userMessage(places.error ?? swipes.error!,
            fallback: l10n.errorLoadPlaces, l10n: l10n),
        onRetry: () {
          ref.invalidate(tripSwipePlacesProvider(_groupId));
          ref.invalidate(tripSwipesProvider(_groupId));
        },
      );
    } else if (!places.hasValue || !swipes.hasValue || uid == null) {
      body = const SwipeDeckSkeleton();
    } else if (places.value!.isEmpty) {
      body = _DeckMessage(
        icon: Icons.travel_explore_rounded,
        title: l10n.tripSwipeNoPlaces,
      );
    } else if (deck.isEmpty) {
      body = _DeckMessage(
        icon: Icons.check_circle_outline,
        title: l10n.tripSwipeDone,
        body: l10n.tripSwipeDoneBody,
        action: FilledButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/trip/$_groupId'),
          child: Text(l10n.tripSwipeToWishlist),
        ),
      );
    } else {
      final current = deck.first;
      body = SwipeDeck(
        place: current,
        nextPlace: deck.length > 1 ? deck[1] : null,
        onLike: () => _vote(current, SwipeVote.like, uid),
        onSkip: () => _vote(current, SwipeVote.nope, uid),
        onSuperLike: () => _vote(current, SwipeVote.superLike, uid),
        onDetail: () => context.push('/place/${current.id}'),
        onUndo: _undo,
        canUndo: _last != null,
      );
    }

    final current = deck.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(trip?.location?.cityName ?? l10n.tripSwipeTitle),
        actions: [
          if (current != null && places.hasValue && swipes.hasValue)
            TextButton.icon(
              onPressed: () => _veto(current, mine?.veto, places.value!),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.block_rounded, size: 20),
              label: Text(l10n.tripSwipeVeto),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }
}

class _DeckMessage extends StatelessWidget {
  const _DeckMessage({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: icon, tone: ChipTone.mint),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
