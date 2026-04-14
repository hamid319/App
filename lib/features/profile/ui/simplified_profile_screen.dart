import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../logic/profile_controller.dart';
import '../../auth/logic/auth_controller.dart';
import '../../swipe/data/places_repository.dart';
import '../../../common/models/place_model.dart';
import '../../../common/widgets/loading_spinner.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/place_card.dart';

class SimplifiedProfileScreen extends ConsumerWidget {
  const SimplifiedProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final user = ref.watch(authControllerProvider).value;
              return IconButton(
                icon: const Icon(Icons.edit),
                onPressed: user != null ? () => _showEditProfileDialog(context, ref, user) : null,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
      body: authState.when(
        loading: () => const LoadingSpinner(message: 'Loading profile...'),
        error: (e, st) => ErrorView(
          message: 'Error loading profile: $e',
          onRetry: () => ref.refresh(authControllerProvider),
        ),
        data: (user) {
          if (user == null) {
            return ErrorView(
              message: 'Please login to view your profile',
              title: 'Not logged in',
              icon: Icons.login,
              onRetry: () => context.go('/login'),
            );
          }

          ref.read(profileControllerProvider.notifier).loadProfile(user.uid);
          final profileState = ref.watch(profileControllerProvider);

          return profileState.when(
            loading: () => _buildProfileContent(context, ref, user, isLoading: true),
            error: (e, st) => ErrorView(
              message: 'Error loading profile: $e',
              onRetry: () => ref.refresh(profileControllerProvider),
            ),
            data: (profileUser) {
              final displayUser = profileUser ?? user;
              return _buildProfileContent(context, ref, displayUser);
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, user, {bool isLoading = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: user.photoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            user.photoUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person, size: 50, color: Colors.white),
                          ),
                        )
                      : const Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  user.displayName ?? 'User',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditProfileDialog(context, ref, user),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context, ref),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Logout', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Favorites',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const LoadingSpinner(message: 'Loading favorites...')
          else
            _buildFavoritesList(context, user.favorites),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(BuildContext context, List<String> favoriteIds) {
    if (favoriteIds.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start swiping to add places to your favorites!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<PlaceModel>>(
      future: _loadFavoritePlaces(favoriteIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingSpinner(message: 'Loading favorites...');
        }

        if (snapshot.hasError) {
          return ErrorView(
            message: 'Error loading favorites: ${snapshot.error}',
            icon: Icons.error_outline,
          );
        }

        final places = snapshot.data ?? [];
        if (places.isEmpty) {
          return const Center(child: Text('No favorite places found'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: places.length,
          itemBuilder: (context, index) {
            final place = places[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: PlaceCard(
                place: place,
                onTap: () => context.push('/place/${place.id}'),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<PlaceModel>> _loadFavoritePlaces(List<String> favoriteIds) async {
    final repo = PlacesRepository();
    final allPlaces = await repo.loadNearbyPlaces(0, 0, useMock: true);
    return allPlaces.where((place) => favoriteIds.contains(place.id)).toList();
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, user) {
    final nameController = TextEditingController(text: user.displayName ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(profileControllerProvider.notifier).updateProfile(
                  user.uid,
                  {'displayName': nameController.text.trim()},
                );
                nameController.dispose();
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}