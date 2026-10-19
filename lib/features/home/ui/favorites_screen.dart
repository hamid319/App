import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../common/models/place_model.dart';
import '../../places/data/place_photo_url_builder.dart';
import '../../../main_providers.dart';
import '../../swipe/logic/swipe_controller.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(swipeControllerProvider);
    final favorites = ref.read(swipeControllerProvider.notifier).favoritesList;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.favoritesTitle),
        actions: [
          // Destructive reset lives behind a menu here rather than as a
          // one-tap red button on the Discover screen.
          PopupMenuButton<String>(
            tooltip: context.l10n.moreOptions,
            onSelected: (value) {
              if (value == 'reset') _confirmReset(context, ref);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reset',
                child: Text(context.l10n.clearFavoritesMenu),
              ),
            ],
          ),
        ],
      ),
      body: favorites.isEmpty
          ? _buildEmptyState(context)
          : FutureBuilder<List<PlaceModel>>(
              future:
                  ref.read(placesRepositoryProvider).loadPlacesByIds(favorites),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(userMessage(snapshot.error!, fallback: context.l10n.errorLoadFavorites, l10n: context.l10n)),
                    ),
                  );
                }

                final favoritePlaces = snapshot.data ?? [];

                if (favoritePlaces.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: favoritePlaces.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = favoritePlaces[index];
                    return ListTile(
                      leading: _buildPlaceThumbnail(place),
                      title: Text(place.name),
                      subtitle: Text(
                        place.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: context.l10n.removeFromFavoritesTooltip,
                        onPressed: () {
                          ref
                              .read(swipeControllerProvider.notifier)
                              .removeFavorite(place.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(context.l10n.placeRemovedFromFavorites(place.name)),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      onTap: () => context.push('/place/${place.id}'),
                    );
                  },
                );
              },
            ),
    );
  }

  static Widget _buildPlaceThumbnail(PlaceModel place) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: resolvePlacePhotoUrls(place).isNotEmpty
            ? CachedNetworkImage(
                imageUrl: resolvePlacePhotoUrls(place).first,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) =>
                    _buildThumbnailPlaceholder(),
              )
            : _buildThumbnailPlaceholder(),
      ),
    );
  }

  static Widget _buildThumbnailPlaceholder() {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: Icon(Icons.place, color: Colors.grey.shade600),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.clearEverythingTitle),
        content: Text(
          context.l10n.clearEverythingBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(swipeControllerProvider.notifier).resetAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.clearedSnack),
                  ),
                );
              }
            },
            child: Text(context.l10n.clear),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              context.l10n.noFavoritesTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.noFavoritesBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
