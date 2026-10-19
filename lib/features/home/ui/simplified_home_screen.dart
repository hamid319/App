import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/user_message.dart';
import '../../swipe/logic/swipe_controller.dart';
import '../../swipe/widgets/swipe_deck.dart';
import '../../../common/widgets/wordmark.dart';
import '../../../l10n/l10n.dart';
import '../../../app/theme.dart';

class SimplifiedHomeScreen extends ConsumerWidget {
  const SimplifiedHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Wordmark(),
      ),
      body: const _SwipeContent(),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 80, color: context.swipeColors.like),
                const SizedBox(height: 24),
                Text(
                  context.l10n.noMorePlacesTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.seenAllPlaces,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(swipeControllerProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.reload),
                ),
              ],
            ),
          );
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
