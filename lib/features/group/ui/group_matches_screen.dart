import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common/models/place_model.dart';
import '../../../common/widgets/loading_spinner.dart';
import '../../../common/widgets/error_view.dart';
import '../logic/group_controller.dart';
import '../../swipe/data/places_repository.dart';

final groupMatchesProvider = FutureProvider<List<PlaceModel>>((ref) async {
  final groupState = ref.watch(groupControllerProvider);
  final repo = PlacesRepository();
  
  return groupState.when(
    data: (group) async {
      if (group == null || group.sharedFavorites.isEmpty) {
        return [];
      }
      final allPlaces = await repo.loadNearbyPlaces(0, 0, useMock: true);
      return allPlaces
          .where((place) => group.sharedFavorites.contains(place.id))
          .toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

class GroupMatchesScreen extends ConsumerWidget {
  const GroupMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupState = ref.watch(groupControllerProvider);
    final matchesAsync = ref.watch(groupMatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Matches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref.read(groupControllerProvider.notifier).refreshGroupMatches();
              ref.invalidate(groupMatchesProvider);
            },
          ),
        ],
      ),
      body: groupState.when(
        loading: () => const LoadingSpinner(message: 'Loading group...'),
        error: (error, stack) => ErrorView(
          message: 'Error: $error',
          title: 'Failed to load group',
          onRetry: () => ref.invalidate(groupControllerProvider),
        ),
        data: (group) {
          if (group == null) {
            return ErrorView(
              message: 'Create or join a group first',
              title: 'No Group',
              icon: Icons.group_off,
              onRetry: () => context.go('/home'),
            );
          }

          return matchesAsync.when(
            loading: () => const LoadingSpinner(message: 'Loading matches...'),
            error: (error, stack) => ErrorView(
              message: 'Error loading matches: $error',
              onRetry: () => ref.invalidate(groupMatchesProvider),
            ),
            data: (matches) {
              if (matches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Matches Yet',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'When all group members like a place,\nit will appear here as a match.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.explore),
                        label: const Text('Discover Places'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.green.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.favorite, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Text(
                          '${matches.length} ${matches.length == 1 ? 'Match' : 'Matches'} found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final place = matches[index];
                        return _MatchCard(place: place);
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

class _MatchCard extends StatelessWidget {
  final PlaceModel place;

  const _MatchCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => context.push('/place/${place.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bild
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade400,
                      Colors.purple.shade400,
                    ],
                  ),
                ),
                child: place.images.isNotEmpty
                    ? Image.network(
                        place.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 16,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Match',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    place.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (place.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: place.tags
                          .take(3)
                          .map(
                            (tag) => Chip(
                              label: Text(
                                tag,
                                style: const TextStyle(fontSize: 11),
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/place/${place.id}'),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('View Details'),
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

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.place,
          size: 60,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
