import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../common/models/place_model.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/ticket.dart';
import '../../../common/widgets/wordmark.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../swipe/logic/discover_preferences_controller.dart';
import '../../swipe/logic/swipe_controller.dart';
import '../../swipe/widgets/discover_filters.dart';
import '../logic/home_feed_controller.dart';
import '../widgets/place_ticket_tile.dart';

/// Width and height of a slider ticket.
const double _tileWidth = 160;
const double _rowHeight = 228;

/// Sliders show this many tiles; "All" opens the rest.
const int _rowLimit = 10;

/// Title of a home collection, for its row and its grid screen.
String homeCollectionTitle(AppLocalizations l10n, HomeCollection c) =>
    switch (c) {
      HomeCollection.mustSees => l10n.homeSectionMustSees,
      HomeCollection.tonight => l10n.homeSectionTonight,
      HomeCollection.hiddenGems => l10n.homeSectionHiddenGems,
    };

/// The "Discover" tab: a headline for the chosen place, the hero ticket
/// into the swipe deck and themed sliders (must-sees, tonight, hidden gems).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Wordmark(),
        actions: const [
          DiscoverLocationChip(),
          SizedBox(width: AppSizes.space12),
        ],
      ),
      body: feed.when(
        loading: () => const _FeedSkeleton(),
        error: (e, _) => _FeedError(error: e),
        data: (feed) => _Feed(feed: feed),
      ),
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed({required this.feed});

  final HomeFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: () async {
        refreshHomeFeed(ref);
        try {
          await ref.read(homeFeedProvider.future);
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.space32),
        children: [
          const _Headline(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenEdge,
              AppSizes.space8,
              AppSizes.screenEdge,
              AppSizes.groupGap,
            ),
            child: _StartSwipingTicket(
              fallbackCount: feed.sightCount,
              topPlace: feed.mustSees.isEmpty ? null : feed.mustSees.first,
            ),
          ),
          if (feed.mustSees.isEmpty)
            const _NoPlaces()
          else
            _PlaceRow(
                collection: HomeCollection.mustSees, places: feed.mustSees),
          if (!feed.hasVenues)
            _Section(
              title: l10n.homeSectionTonight,
              child: const _VenuesComingSoon(),
            )
          else if (feed.tonight.isNotEmpty)
            _PlaceRow(collection: HomeCollection.tonight, places: feed.tonight),
          if (feed.hiddenGems.isNotEmpty)
            _PlaceRow(
              collection: HomeCollection.hiddenGems,
              places: feed.hiddenGems,
            ),
        ],
      ),
    );
  }
}

class _Headline extends ConsumerWidget {
  const _Headline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final city = ref.watch(discoverPreferencesProvider).value?.city;
    final text = city == null
        ? l10n.homeHeadlineNearby
        : l10n.homeHeadlineCity(
            city.nameFor(Localizations.localeOf(context).languageCode),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenEdge,
        AppSizes.space8,
        AppSizes.screenEdge,
        AppSizes.space16,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.displaySmall,
      ),
    );
  }
}

/// Raised orange ticket into the swipe deck, with the number of cards
/// waiting and a small tilted photo of the best-known place.
class _StartSwipingTicket extends ConsumerWidget {
  const _StartSwipingTicket({required this.fallbackCount, this.topPlace});

  /// Shown until the deck itself has loaded.
  final int fallbackCount;
  final PlaceModel? topPlace;

  static const double _stub = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final deck = ref.watch(swipeControllerProvider);
    final count = deck.hasValue
        ? ref.read(swipeControllerProvider.notifier).remainingCount
        : fallbackCount;
    final onAccent = scheme.onPrimary;

    return Ticket(
      raised: true,
      color: scheme.primary,
      notchFromBottom: _stub,
      onTap: () => context.push('/discover'),
      child: SizedBox(
        height: 192,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.space24,
                  AppSizes.space16,
                  AppSizes.space16,
                  AppSizes.space12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.homeStartSwiping,
                        style: AppTypography.display(size: 32, color: onAccent),
                      ),
                    ),
                    if (topPlace != null) ...[
                      const SizedBox(width: AppSizes.space12),
                      _TiltedPhoto(place: topPlace!),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              height: _stub,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space24,
                ),
                child: Row(
                  children: [
                    Icon(Icons.swipe_rounded, color: onAccent, size: 20),
                    const SizedBox(width: AppSizes.space8),
                    Expanded(
                      child: Text(
                        l10n.homeStartSwipingCount(count),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: onAccent),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: onAccent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small print of a photo, pinned at an angle on the hero ticket.
class _TiltedPhoto extends StatelessWidget {
  const _TiltedPhoto({required this.place});

  final PlaceModel place;

  @override
  Widget build(BuildContext context) {
    final edge = context.swipeColors.edge;
    return Transform.rotate(
      angle: 0.08,
      child: Container(
        width: 92,
        height: 108,
        padding: const EdgeInsets.all(AppSizes.space4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusXs),
          border: Border.all(color: edge, width: AppSizes.edge),
          boxShadow: printShadow(edge),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusXs - 3),
          child: PlacePhoto(place: place),
        ),
      ),
    );
  }
}

/// Section header with an optional "All" action, then [child].
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.onAll});

  final String title;
  final Widget child;
  final VoidCallback? onAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.groupGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenEdge,
            ),
            child: SectionLabel(
              title,
              trailing: onAll == null
                  ? null
                  : TextButton(
                      onPressed: onAll,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(context.l10n.homeSeeAll),
                    ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.collection, required this.places});

  final HomeCollection collection;
  final List<PlaceModel> places;

  @override
  Widget build(BuildContext context) {
    final shown = places.take(_rowLimit).toList();
    return _Section(
      title: homeCollectionTitle(context.l10n, collection),
      onAll: () => context.push('/collection/${collection.slug}'),
      child: SizedBox(
        height: _rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.screenEdge,
          ),
          itemCount: shown.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSizes.space12),
          itemBuilder: (context, i) => SizedBox(
            width: _tileWidth,
            child: PlaceTicketTile(
              place: shown[i],
              subtitle: placeCategoryLabel(context, shown[i]),
              tone: placeTicketTones[i % placeTicketTones.length],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stands in for the "Tonight" row until venues are imported for the city.
class _VenuesComingSoon extends StatelessWidget {
  const _VenuesComingSoon();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenEdge),
      child: Ticket(
        color: context.swipeColors.sky,
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Row(
          children: [
            const IconBadge(
              icon: Icons.local_bar_rounded,
              tone: ChipTone.gold,
              size: 56,
            ),
            const SizedBox(width: AppSizes.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.homeVenuesComingTitle, style: text.titleMedium),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    l10n.homeVenuesComingBody,
                    style: text.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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

/// No sights at all for the chosen place.
class _NoPlaces extends ConsumerWidget {
  const _NoPlaces();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final prefs = ref.watch(discoverPreferencesProvider).value ??
        const DiscoverPreferences();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.space32,
        0,
        AppSizes.space32,
        AppSizes.groupGap,
      ),
      child: Column(
        children: [
          const IconBadge(icon: Icons.travel_explore, tone: ChipTone.sky),
          const SizedBox(height: AppSizes.space16),
          Text(
            l10n.emptyNoPlacesTitle,
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            l10n.emptyNoPlacesBody(placeLabel(context, prefs)),
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSizes.space16),
          OutlinedButton.icon(
            onPressed: () => showLocationPicker(context, ref),
            icon: const Icon(Icons.place_outlined),
            label: Text(l10n.changePlace),
          ),
        ],
      ),
    );
  }
}

class _FeedError extends ConsumerWidget {
  const _FeedError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconBadge(icon: Icons.cloud_off_rounded),
            const SizedBox(height: AppSizes.space24),
            Text(
              l10n.errorLoadingPlacesTitle,
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              userMessage(error, fallback: l10n.errorLoadPlaces, l10n: l10n),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            FilledButton.icon(
              onPressed: () => refreshHomeFeed(ref),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget row() => SizedBox(
          height: _rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: AppSizes.screenEdge),
            itemCount: 4,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSizes.space12),
            itemBuilder: (_, __) => const SkeletonBox(
              width: _tileWidth,
              radius: AppSizes.radiusTicket,
            ),
          ),
        );
    const label = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenEdge,
        AppSizes.groupGap,
        AppSizes.screenEdge,
        AppSizes.space12,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SkeletonBox(width: 110, height: 12),
      ),
    );
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSizes.screenEdge,
              AppSizes.space8,
              AppSizes.screenEdge,
              AppSizes.space16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 280, height: 30),
                SizedBox(height: AppSizes.space8),
                SkeletonBox(width: 180, height: 30),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.screenEdge),
            child: SkeletonBox(height: 192, radius: AppSizes.radiusTicket),
          ),
          label,
          row(),
          label,
          row(),
        ],
      ),
    );
  }
}
