import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common/models/place_model.dart';
import '../../../common/models/group_model.dart';
import '../../../common/widgets/loading_spinner.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/primary_button.dart';
import '../../../common/widgets/place_card.dart';
import '../../swipe/logic/swipe_controller.dart';
import '../../swipe/data/places_repository.dart';
import '../../auth/logic/auth_controller.dart';
import '../../group/logic/group_controller.dart';
import '../../profile/logic/profile_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  PreferredSizeWidget _buildAppBar() {
    switch (_selectedIndex) {
      case 0:
        return AppBar(
          title: const Text('Discover Places'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Consumer(
                  builder: (context, ref, _) {
                    final favoritesCount = ref.read(swipeControllerProvider.notifier).favoritesList.length;
                    return GestureDetector(
                      onTap: () => _showFavoritesDialog(context, ref),
                      child: Badge(
                        label: Text('$favoritesCount'),
                        child: const Icon(Icons.favorite),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      case 1:
        return AppBar(title: const Text('Group'));
      case 2:
        return AppBar(title: const Text('Profile'));
      default:
        return AppBar(title: const Text('App'));
    }
  }

  void _showFavoritesDialog(BuildContext context, WidgetRef ref) {
    final favorites = ref.read(swipeControllerProvider.notifier).favoritesList;
    final repo = PlacesRepository();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Favorites'),
        content: SizedBox(
          width: double.maxFinite,
          child: favorites.isEmpty
              ? const Text('No favorites yet. Start swiping to add places!')
              : FutureBuilder<List<PlaceModel>>(
                  future: repo.loadNearbyPlaces(0, 0, useMock: true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allPlaces = snapshot.data ?? [];
                    final favoritePlaces = allPlaces.where((p) => favorites.contains(p.id)).toList();
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: favoritePlaces.length,
                      itemBuilder: (context, index) {
                        final place = favoritePlaces[index];
                        return ListTile(
                          leading: const Icon(Icons.place),
                          title: Text(place.name),
                          subtitle: Text(place.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/place/${place.id}');
                          },
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _SwipeContent(key: ValueKey('swipe')),
          _GroupContent(key: ValueKey('groups')),
          _ProfileContent(key: ValueKey('profile')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Swipe',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _SwipeContent extends ConsumerWidget {
  const _SwipeContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(swipeControllerProvider);
    final ctrl = ref.read(swipeControllerProvider.notifier);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading places',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(swipeControllerProvider),
                child: const Text('Retry'),
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
                const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  'No more places!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'You have seen all places',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(swipeControllerProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload'),
                ),
              ],
            ),
          );
        }
        return _SwipeCardStack(
          place: current,
          onLike: () {
            ctrl.like();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Added to favorites!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          },
          onSkip: () {
            ctrl.skip();
          },
          onDetail: () {
            context.push('/place/${current.id}');
          },
        );
      },
    );
  }
}

class _GroupContent extends ConsumerStatefulWidget {
  const _GroupContent({super.key});

  @override
  ConsumerState<_GroupContent> createState() => _GroupContentState();
}

class _GroupContentState extends ConsumerState<_GroupContent> {
  final TextEditingController _groupIdController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  bool _showCreateGroup = false;

  @override
  void dispose() {
    _groupIdController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupControllerProvider);
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => const LoadingSpinner(message: 'Loading user...'),
      error: (e, st) => ErrorView(
        message: 'Error loading user: $e',
        onRetry: () => ref.refresh(authControllerProvider),
      ),
      data: (user) {
        if (user == null) {
          return ErrorView(
            message: 'Please login to use groups',
            title: 'Not logged in',
            icon: Icons.login,
            onRetry: () => context.go('/login'),
          );
        }

        return groupState.when(
          loading: () => const LoadingSpinner(message: 'Loading group...'),
          error: (e, st) => ErrorView(
            message: 'Error: $e',
            onRetry: () => ref.refresh(groupControllerProvider),
          ),
          data: (group) {
            if (group == null) {
              return _buildNoGroupView(user.uid);
            }
            return _buildGroupView(group, user.uid);
          },
        );
      },
    );
  }

  Widget _buildNoGroupView(String userId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.group_add, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No Group Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new group or join an existing one',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (!_showCreateGroup) ...[
            PrimaryButton(
              label: 'Create Group',
              icon: Icons.add,
              width: double.infinity,
              onPressed: () => setState(() => _showCreateGroup = true),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Join Group',
              icon: Icons.group_add,
              width: double.infinity,
              backgroundColor: Colors.blue.shade50,
              textColor: Colors.blue,
              onPressed: _showJoinGroupDialog,
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Group',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        hintText: 'Enter group name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _showCreateGroup = false;
                                _groupNameController.clear();
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Create',
                            onPressed: _createGroup,
                            isLoading: ref.watch(groupControllerProvider).isLoading,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupView(GroupModel group, String userId) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Group ID: ${group.groupId}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${group.members.length} ${group.members.length == 1 ? 'member' : 'members'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${group.sharedFavorites.length} ${group.sharedFavorites.length == 1 ? 'match' : 'matches'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (group.members.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Members',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: group.members.length,
              itemBuilder: (context, index) {
                final memberId = group.members[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(memberId.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(memberId == userId ? 'You' : 'Member ${index + 1}'),
                  subtitle: Text(memberId),
                );
              },
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              PrimaryButton(
                label: 'View Matches',
                icon: Icons.favorite,
                width: double.infinity,
                onPressed: () => context.push('/group-matches'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _leaveGroup(group.groupId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const SizedBox(
                  width: double.infinity,
                  child: Text('Leave Group', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    final userId = ref.read(authControllerProvider).value?.uid;
    if (userId == null) return;

    final groupId = DateTime.now().millisecondsSinceEpoch.toString();
    final group = GroupModel(
      groupId: groupId,
      groupName: groupName,
      members: [userId],
      sharedFavorites: [],
    );

    try {
      await ref.read(groupControllerProvider.notifier).createGroup(group);
      if (mounted) {
        setState(() {
          _showCreateGroup = false;
          _groupNameController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group created! ID: $groupId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(
          controller: _groupIdController,
          decoration: const InputDecoration(
            labelText: 'Group ID',
            hintText: 'Enter group ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _groupIdController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            label: 'Join',
            onPressed: () {
              _joinGroup();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _joinGroup() async {
    final groupId = _groupIdController.text.trim();
    if (groupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group ID')),
      );
      return;
    }

    final userId = ref.read(authControllerProvider).value?.uid;
    if (userId == null) return;

    try {
      await ref.read(groupControllerProvider.notifier).joinGroup(groupId, userId);
      if (mounted) {
        _groupIdController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined group!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining group: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _leaveGroup(String groupId) {
    final userId = ref.read(authControllerProvider).value?.uid;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(groupControllerProvider.notifier).leaveGroup(groupId, userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Left group')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
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

// Swipe card stack widget with drag gestures
class _SwipeCardStack extends StatefulWidget {
  final PlaceModel place;
  final VoidCallback onLike;
  final VoidCallback onSkip;
  final VoidCallback onDetail;

  const _SwipeCardStack({
    required this.place,
    required this.onLike,
    required this.onSkip,
    required this.onDetail,
  });

  @override
  State<_SwipeCardStack> createState() => _SwipeCardStackState();
}

class _SwipeCardStackState extends State<_SwipeCardStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;
  
  double _dragStartX = 0;
  double _dragStartY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _dragStartX = details.globalPosition.dx;
      _dragStartY = details.globalPosition.dy;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final deltaX = details.globalPosition.dx - _dragStartX;
    final deltaY = details.globalPosition.dy - _dragStartY;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate rotation based on horizontal drag
    final rotation = deltaX / screenWidth * 0.1;
    // Calculate opacity based on drag distance
    final opacity = 1.0 - (deltaX.abs() / screenWidth * 0.5).clamp(0.0, 0.5);
    
    setState(() {
      _slideAnimation = AlwaysStoppedAnimation(Offset(deltaX / screenWidth, deltaY / screenWidth));
      _rotationAnimation = AlwaysStoppedAnimation(rotation);
      _opacityAnimation = AlwaysStoppedAnimation(opacity);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final currentOffset = _slideAnimation.value.dx;
    
    // Threshold for swipe (30% of screen width or fast velocity)
    final threshold = 0.3;
    final fastSwipe = velocity.abs() > 500;
    
    if (currentOffset > threshold || (velocity > 0 && fastSwipe)) {
      // Swipe right - Like
      _swipeRight();
    } else if (currentOffset < -threshold || (velocity < 0 && fastSwipe)) {
      // Swipe left - Skip
      _swipeLeft();
    } else {
      // Return to center
      _returnToCenter();
    }
  }

  void _swipeRight() {
    _slideAnimation = Tween<Offset>(
      begin: _slideAnimation.value,
      end: Offset(2.0, _slideAnimation.value.dy),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _rotationAnimation = Tween<double>(
      begin: _rotationAnimation.value,
      end: 0.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _opacityAnimation = Tween<double>(
      begin: _opacityAnimation.value,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    
    _controller.forward().then((_) {
      widget.onLike();
    });
  }

  void _swipeLeft() {
    _slideAnimation = Tween<Offset>(
      begin: _slideAnimation.value,
      end: Offset(-2.0, _slideAnimation.value.dy),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _rotationAnimation = Tween<double>(
      begin: _rotationAnimation.value,
      end: -0.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _opacityAnimation = Tween<double>(
      begin: _opacityAnimation.value,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    
    _controller.forward().then((_) {
      widget.onSkip();
    });
  }

  void _returnToCenter() {
    _slideAnimation = Tween<Offset>(
      begin: _slideAnimation.value,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _rotationAnimation = Tween<double>(
      begin: _rotationAnimation.value,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: _opacityAnimation.value,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _controller.forward().then((_) {
      _controller.reset();
    });
  }

  void _handleLike() {
    _swipeRight();
  }

  void _handleSkip() {
    _swipeLeft();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: widget.onDetail,
              onPanStart: _handleDragStart,
              onPanUpdate: _handleDragUpdate,
              onPanEnd: _handleDragEnd,
              child: SlideTransition(
                position: _slideAnimation,
                child: RotationTransition(
                  turns: _rotationAnimation,
                  child: FadeTransition(
                    opacity: _opacityAnimation,
                    child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
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
                          child: widget.place.images.isNotEmpty
                              ? Image.network(
                                  widget.place.images.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildPlaceholder(),
                                )
                              : _buildPlaceholder(),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.place.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.place.description,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 16,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.place.tags.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: widget.place.tags
                                        .map(
                                          (tag) => Chip(
                                            label: Text(
                                              tag,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor:
                                                Colors.white.withValues(alpha: 0.2),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: IconButton(
                            icon: const Icon(Icons.info_outline,
                                color: Colors.white),
                            onPressed: widget.onDetail,
                          ),
                        ),
                      ],
                    ),
                  ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      iconSize: 32,
                      onPressed: _handleSkip,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.green),
                      iconSize: 32,
                      onPressed: _handleLike,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Like',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.place,
          size: 80,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
