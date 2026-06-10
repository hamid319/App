import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common/models/place_model.dart';
import '../../swipe/data/places_repository.dart';
import '../../swipe/logic/swipe_controller.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(swipeControllerProvider);
    final favorites = ref.read(swipeControllerProvider.notifier).favoritesList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Favorites'),
      ),
      body: favorites.isEmpty
          ? _buildEmptyState(context)
          : FutureBuilder<List<PlaceModel>>(
              future: PlacesRepository().loadNearbyPlaces(0, 0, useMock: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading places: ${snapshot.error}'),
                    ),
                  );
                }

                final allPlaces = snapshot.data ?? [];
                final favoritePlaces =
                    allPlaces.where((p) => favorites.contains(p.id)).toList();

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
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Remove from favorites',
                        onPressed: () {
                          ref
                              .read(swipeControllerProvider.notifier)
                              .removeFavorite(place.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${place.name} removed from favorites'),
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
        child: place.imageUrls.isNotEmpty
            ? Image.network(
                place.imageUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildThumbnailPlaceholder(),
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
              'No favorites yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Start swiping to add places to your favorites!',
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
