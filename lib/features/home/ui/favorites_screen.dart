import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common/models/place_model.dart';
import '../../../common/utils/place_type_labels.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../main_providers.dart';
import '../../swipe/logic/swipe_controller.dart';

/// Two-column photo grid of saved places with category chips as filters.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  /// Loaded places, refetched only when the set of favorite IDs changes
  /// (the old FutureBuilder refetched on every rebuild).
  Future<List<PlaceModel>>? _places;
  String _loadedKey = '';
  String? _filter;

  Future<List<PlaceModel>> _placesFor(List<String> ids) {
    final key = ([...ids]..sort()).join('|');
    if (_places == null || key != _loadedKey) {
      _loadedKey = key;
      _places = ref.read(placesRepositoryProvider).loadPlacesByIds(ids);
    }
    return _places!;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(swipeControllerProvider);
    final ids = ref.read(swipeControllerProvider.notifier).favoritesList;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navFavorites),
        actions: [
          // Destructive reset lives behind a menu here rather than as a
          // one-tap red button on the Discover screen.
          PopupMenuButton<String>(
            tooltip: l10n.moreOptions,
            onSelected: (value) {
              if (value == 'reset') _confirmReset(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reset',
                child: Text(l10n.clearFavoritesMenu),
              ),
            ],
          ),
        ],
      ),
      body: ids.isEmpty
          ? const _EmptyState()
          : FutureBuilder<List<PlaceModel>>(
              future: _placesFor(ids),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _GridSkeleton();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.space24),
                      child: Text(
                        userMessage(
                          snapshot.error!,
                          fallback: l10n.errorLoadFavorites,
                          l10n: l10n,
                        ),
                      ),
                    ),
                  );
                }
                // Removing a favorite updates the IDs before the next load
                // finishes, so filter the loaded list by the current IDs.
                final places = (snapshot.data ?? [])
                    .where((p) => ids.contains(p.id))
                    .toList();
                if (places.isEmpty) return const _EmptyState();
                return _Grid(
                  places: places,
                  filter: _filter,
                  onFilter: (f) => setState(() => _filter = f),
                );
              },
            ),
    );
  }

  void _confirmReset(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearEverythingTitle),
        content: Text(l10n.clearEverythingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(swipeControllerProvider.notifier).resetAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.clearedSnack)),
                );
              }
            },
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({
    required this.places,
    required this.filter,
    required this.onFilter,
  });

  final List<PlaceModel> places;
  final String? filter;
  final ValueChanged<String?> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    String? category(PlaceModel p) {
      final labels = placeTypeLabels(l10n, p.types);
      return labels.isEmpty ? null : labels.first;
    }

    // Categories with at least one place, most common first.
    final counts = <String, int>{};
    for (final p in places) {
      final c = category(p);
      if (c != null) counts[c] = (counts[c] ?? 0) + 1;
    }
    final categories = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final active = categories.contains(filter) ? filter : null;
    final shown = active == null
        ? places
        : places.where((p) => category(p) == active).toList();

    return CustomScrollView(
      slivers: [
        if (categories.length > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.screenEdge,
                ),
                children: [
                  _FilterChip(
                    label: l10n.filterAll(places.length),
                    selected: active == null,
                    onTap: () => onFilter(null),
                  ),
                  for (final c in categories)
                    _FilterChip(
                      label: c,
                      selected: active == c,
                      onTap: () => onFilter(c),
                    ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenEdge,
            AppSizes.space8,
            AppSizes.screenEdge,
            AppSizes.space24,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSizes.space16,
              crossAxisSpacing: AppSizes.space12,
              childAspectRatio: 0.72,
            ),
            itemCount: shown.length,
            itemBuilder: (context, i) => _Tile(
              place: shown[i],
              subtitle: category(shown[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.place, this.subtitle});

  final PlaceModel place;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push('/place/${place.id}'),
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: placePhotoHeroTag(place.id),
                    child: PlacePhoto(place: place),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      tooltip: l10n.removeFromFavoritesTooltip,
                      icon: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Color(0x80000000), blurRadius: 6),
                        ],
                      ),
                      onPressed: () {
                        ref
                            .read(swipeControllerProvider.notifier)
                            .removeFavorite(place.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.placeRemovedFromFavorites(place.name),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            place.nameFor(Localizations.localeOf(context).languageCode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
      child: Material(
        color: selected ? scheme.onSurface : scheme.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? scheme.onSurface : scheme.outlineVariant,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? scheme.surface : scheme.onSurface,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSizes.screenEdge),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSizes.space16,
          crossAxisSpacing: AppSizes.space12,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SkeletonBox(
                width: double.infinity,
                radius: AppSizes.radiusMd,
              ),
            ),
            SizedBox(height: AppSizes.space8),
            FractionallySizedBox(
              widthFactor: 0.8,
              child: SkeletonBox(height: 12),
            ),
            SizedBox(height: AppSizes.space4),
            FractionallySizedBox(
              widthFactor: 0.5,
              child: SkeletonBox(height: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.favorite_rounded, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              l10n.noFavoritesTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              l10n.noFavoritesBody,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSizes.space24),
            FilledButton.icon(
              onPressed: () => context.go('/home'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.explore),
              label: Text(l10n.navDiscover),
            ),
          ],
        ),
      ),
    );
  }
}
