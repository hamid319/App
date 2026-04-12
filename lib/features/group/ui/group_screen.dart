import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../logic/group_controller.dart';
import '../../../common/models/group_model.dart';
import '../../../common/widgets/primary_button.dart';
import '../../../common/widgets/loading_spinner.dart';
import '../../../common/widgets/error_view.dart';
import '../../auth/logic/auth_controller.dart';

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  final TextEditingController _groupIdController = TextEditingController();
  bool _showCreateGroup = false;
  final TextEditingController _groupNameController = TextEditingController();

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group'),
        actions: [
          if (groupState.value != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(groupControllerProvider);
              },
            ),
        ],
      ),
      body: authState.when(
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
      ),
    );
  }

  Widget _buildNoGroupView(String userId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.group_add,
            size: 80,
            color: Colors.grey[400],
          ),
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
              onPressed: () {
                setState(() {
                  _showCreateGroup = true;
                });
              },
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Join Group',
              icon: Icons.group_add,
              width: double.infinity,
              backgroundColor: Colors.blue.shade50,
              textColor: Colors.blue,
              onPressed: () {
                _showJoinGroupDialog();
              },
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
                            onPressed: () => _createGroup(),
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
        // Group Info Card
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
                      onPressed: () {
                        // Copy group ID to clipboard
                        // You can add clipboard functionality here
                      },
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
        // Members List
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
        // Action Buttons
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

    final authState = ref.read(authControllerProvider);
    final userId = authState.value?.uid;
    if (userId == null) return;

    final groupId = _generateGroupId();
    final group = GroupModel(
      groupId: groupId,
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
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: Colors.red,
          ),
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

    final authState = ref.read(authControllerProvider);
    final userId = authState.value?.uid;
    if (userId == null) return;

    try {
      await ref.read(groupControllerProvider.notifier).joinGroup(groupId, userId);
      if (mounted) {
        _groupIdController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined group!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _leaveGroup(String groupId) {
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
              // Reset group state by invalidating
              ref.invalidate(groupControllerProvider);
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

  String _generateGroupId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
