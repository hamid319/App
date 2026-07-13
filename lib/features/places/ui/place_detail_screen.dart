import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/maps_launcher.dart';
import '../../../common/models/place_model.dart';
import '../data/place_photo_url_builder.dart';
import '../../swipe/data/places_repository.dart';
import '../../swipe/logic/swipe_controller.dart';

final placeDetailProvider =
    FutureProvider.family<PlaceModel?, String>((ref, placeId) async {
  final repo = PlacesRepository();
  return await repo.getPlaceById(placeId);
});

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeId = GoRouterState.of(context).pathParameters['id'] ?? '';
    final placeAsync = ref.watch(placeDetailProvider(placeId));

    final appBarTitle = placeAsync.when(
      data: (place) => place?.name ?? 'Place',
      loading: () => 'Place',
      error: (_, __) => 'Place',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: placeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
        data: (place) {
          if (place == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.place, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Place not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            );
          }
          return _PlaceDetailContent(place: place);
        },
      ),
    );
  }
}

class _PlaceDetailContent extends ConsumerWidget {
  final PlaceModel place;

  const _PlaceDetailContent({required this.place});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the swipe controller to get reactive updates on favorite status
    ref.watch(swipeControllerProvider);
    final swipeCtrl = ref.read(swipeControllerProvider.notifier);
    final isFav = swipeCtrl.isFavorite(place.id);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: resolvePlacePhotoUrls(place).isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: resolvePlacePhotoUrls(place).first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.description ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 24),
                // Tags
                if (place.types.isNotEmpty) ...[
                  Text(
                    'Tags',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: place.types
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Colors.blue.shade50,
                            side: BorderSide(color: Colors.blue.shade200),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                // Koordinaten
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Coordinates',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await MapsLauncher.openInMaps(
                          place.lat,
                          place.lng,
                          place.name,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not open Maps app: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Open in Maps'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: isFav
                      ? ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(swipeControllerProvider.notifier)
                                .removeFavorite(place.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${place.name} removed from favorites'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          icon: const Icon(Icons.favorite, color: Colors.white),
                          label: const Text('Remove from Favorites'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () async {
                            await ref
                                .read(swipeControllerProvider.notifier)
                                .addFavorite(place.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${place.name} added to favorites!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.favorite_border),
                          label: const Text('Add to Favorites'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.place,
          size: 100,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
