import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/user_message.dart';
import '../../swipe/logic/swipe_controller.dart';
import '../../swipe/widgets/swipe_deck.dart';
import '../../swipe/widgets/discover_filters.dart';
import '../../swipe/logic/discover_preferences_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../common/widgets/ticket.dart';

/// The solo swipe deck, opened full screen from the home feed's
/// "Start swiping" ticket. Place and filters sit in its app bar.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: const [
          DiscoverLocationChip(),
          SizedBox(width: 6),
          DiscoverFilterButton(),
          SizedBox(width: 12),
        ],
      ),
      // Outside the shell there is no nav bar, so keep the buttons clear of
      // the home indicator.
      body: const SafeArea(top: false, child: _SwipeContent()),
    );
  }
}

class _SwipeContent extends ConsumerWidget {
  const _SwipeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(swipeControllerProvider);
    final ctrl = ref.read(swipeControllerProvider.notifier);

    return state.when(
      loading: () => const SwipeDeckSkeleton(),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                context.l10n.errorLoadingPlacesTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                userMessage(e, fallback: context.l10n.errorLoadPlaces, l10n: context.l10n),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(swipeControllerProvider),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      ),
      data: (places) {
        final current = ctrl.currentPlace;
        if (current == null) {
          return _EmptyDeck(reason: ctrl.emptyReason);
        }
        return SwipeDeck(
          place: current,
          nextPlace: ctrl.nextPlaceInDeck,
          canUndo: ctrl.canUndo,
          onUndo: ctrl.undo,
          onSkip: ctrl.skip,
          onDetail: () => context.push('/place/${current.id}'),
          onLike: () async {
            ctrl.like();
            final messenger = ScaffoldMessenger.of(context);
            final router = GoRouter.of(context);
            final l10n = context.l10n;
            // Guests keep swiping freely; they get one gentle nudge to save
            // their likes with an account instead of a blocking prompt.
            // Everyone else sees the LIKE stamp and the favorites badge.
            if (await ctrl.takeGuestFavoriteHint()) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.guestLikeHint),
                  duration: const Duration(seconds: 6),
                  // Snackbars with an action stay until dismissed by default;
                  // this one would cover the swipe buttons.
                  persist: false,
                  action: SnackBarAction(
                    label: l10n.signUp,
                    onPressed: () => router.push('/register'),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

/// What to show when the deck is empty, with the matching way out.
class _EmptyDeck extends ConsumerWidget {
  const _EmptyDeck({required this.reason});

  final DeckEmptyReason reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final prefs = ref.watch(discoverPreferencesProvider).value ??
        const DiscoverPreferences();

    final (IconData icon, ChipTone tone, String title, String body, Widget action) =
        switch (reason) {
      DeckEmptyReason.noPlacesInArea => (
          Icons.travel_explore,
          ChipTone.sky,
          l10n.emptyNoPlacesTitle,
          l10n.emptyNoPlacesBody(placeLabel(context, prefs)),
          FilledButton.icon(
            onPressed: () => showLocationPicker(context, ref),
            icon: const Icon(Icons.place_outlined),
            label: Text(l10n.changePlace),
          ),
        ),
      DeckEmptyReason.filteredOut => (
          Icons.filter_alt_off_outlined,
          ChipTone.peach,
          l10n.emptyFilteredTitle,
          l10n.emptyFilteredBody,
          FilledButton.icon(
            onPressed: () =>
                ref.read(discoverPreferencesProvider.notifier).resetFilters(),
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.resetFilters),
          ),
        ),
      _ => (
          Icons.check_circle_outline,
          ChipTone.mint,
          l10n.noMorePlacesTitle,
          l10n.seenAllPlaces,
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(swipeControllerProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.reload),
          ),
        ),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: icon, tone: tone),
            const SizedBox(height: 24),
            Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(height: 48, child: action),
          ],
        ),
      ),
    );
  }
}
