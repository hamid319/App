import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../logic/group_controller.dart';
import '../../../common/models/group_model.dart';
import '../../../common/widgets/primary_button.dart';
import '../../../common/widgets/loading_spinner.dart';
import '../../../common/widgets/error_view.dart';
import '../../auth/logic/auth_controller.dart';
import '../data/location_repository.dart';

class SimplifiedGroupScreen extends ConsumerStatefulWidget {
  const SimplifiedGroupScreen({super.key});

  @override
  ConsumerState<SimplifiedGroupScreen> createState() =>
      _SimplifiedGroupScreenState();
}

class _SimplifiedGroupScreenState extends ConsumerState<SimplifiedGroupScreen> {
  final TextEditingController _inviteCodeController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _swipeLimitController =
      TextEditingController(text: '10');
  final TextEditingController _timeLimitController =
      TextEditingController(text: '5');

  bool _isTimeLimit = false;
  bool _showCreateGroup = false;

  final _locationRepo = LocationRepository();
  bool _isLoadingLocations = false;
  List<Map<String, String>> _countries = [];
  List<Map<String, dynamic>> _cities = [];
  String? _selectedCountryCode;
  String? _selectedCountryName;
  Map<String, dynamic>? _selectedCity;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() => _isLoadingLocations = true);
    try {
      final countries = await _locationRepo.getCountries();
      if (mounted) setState(() => _countries = countries);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  Future<void> _loadCities(String countryCode, String countryName) async {
    setState(() {
      _selectedCountryCode = countryCode;
      _selectedCountryName = countryName;
      _selectedCity = null;
      _isLoadingLocations = true;
    });
    try {
      final cities = await _locationRepo.getCities(countryCode);
      if (mounted) setState(() => _cities = cities);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _groupNameController.dispose();
    _swipeLimitController.dispose();
    _timeLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedGroupIdProvider);
    final groupState = ref.watch(groupControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final groupController = ref.watch(groupControllerProvider.notifier);
    final userGroupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: selectedId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  ref.read(selectedGroupIdProvider.notifier).updateState(null);
                },
              )
            : null,
        title: Text(selectedId != null ? 'Group Details' : 'Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(userGroupsProvider);
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

          if (selectedId != null) {
            return groupState.when(
              loading: () => const LoadingSpinner(message: 'Loading group...'),
              error: (e, st) => ErrorView(
                message: 'Error: $e',
                onRetry: () => ref.refresh(groupControllerProvider),
              ),
              data: (group) {
                if (group == null) {
                  return const Center(child: Text('Group not found'));
                }
                return _buildGroupView(group, user.uid, groupController);
              },
            );
          }

          return userGroupsAsync.when(
            loading: () => const LoadingSpinner(message: 'Loading groups...'),
            error: (e, st) => ErrorView(
              message: 'Error: $e',
              onRetry: () => ref.refresh(userGroupsProvider),
            ),
            data: (groups) {
              return _buildDashboardView(groups, user.uid);
            },
          );
        },
      ),
    );
  }

  Widget _buildDashboardView(List<GroupModel> groups, String userId) {
    final header = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showJoinGroupDialog,
              icon: const Icon(Icons.group_add),
              label: const Text('Join'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              onPressed: () => setState(() => _showCreateGroup = true),
              icon: Icons.add,
              label: '+ New',
            ),
          ),
        ],
      ),
    );

    if (_showCreateGroup) {
      return SingleChildScrollView(
        child: Column(
          children: [
            header,
            _buildCreateGroupCard(),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: _buildEmptyDashboard(),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groups.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _buildGroupListTile(group, userId);
                },
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        header,
        Expanded(
          child: groups.isEmpty
              ? _buildEmptyDashboard()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _buildGroupListTile(group, userId);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupListTile(GroupModel group, String userId) {
    final isLive = group.activeSessionId != null;
    final hasCompleted = group.hasCompletedSession == true;
    final isOwner = group.ownerUid == userId;

    final badge = isLive
        ? InkWell(
            onTap: () => context.push('/swipe/${group.groupId}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Live',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          )
        : hasCompleted
            ? InkWell(
                onTap: () => context.push('/group-matches/${group.groupId}'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            : InkWell(
                onTap: () {
                  ref
                      .read(selectedGroupIdProvider.notifier)
                      .updateState(group.groupId);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        isOwner ? Colors.blue.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOwner ? 'Start' : 'Idle',
                    style: TextStyle(
                      color:
                          isOwner ? Colors.blue.shade700 : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(group.groupName?.substring(0, 1).toUpperCase() ?? 'G'),
        ),
        title: Text(group.groupName ?? 'Unnamed Group'),
        subtitle: Text('${group.members.length} members'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            if (isOwner)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => _confirmDeleteGroup(group),
              ),
          ],
        ),
        onTap: () {
          ref.read(selectedGroupIdProvider.notifier).updateState(group.groupId);
        },
      ),
    );
  }

  Widget _buildEmptyDashboard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_add, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No Groups Yet',
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
        ],
      ),
    );
  }

  Widget _buildCreateGroupCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: Colors.grey.shade300, width: 1, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
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
              if (_isLoadingLocations && _countries.isEmpty)
                const CircularProgressIndicator()
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCountryCode,
                  items: _countries.map((c) {
                    return DropdownMenuItem(
                      value: c['countryCode'],
                      child: Text(
                        c['countryName'] ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (code) {
                    if (code != null) {
                      final name = _countries.firstWhere(
                          (c) => c['countryCode'] == code)['countryName']!;
                      _loadCities(code, name);
                    }
                  },
                ),
              const SizedBox(height: 16),
              if (_selectedCountryCode != null)
                if (_isLoadingLocations && _cities.isEmpty)
                  const CircularProgressIndicator()
                else
                  DropdownButtonFormField<Map<String, dynamic>>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedCity,
                    items: _cities.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c['cityName'] ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (city) {
                      setState(() => _selectedCity = city);
                    },
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
    );
  }

  Widget _buildGroupView(
      GroupModel group, String userId, GroupController controller) {
    final isAdmin = group.ownerUid == userId;
    final hasActiveSession = group.activeSessionId != null;

    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName ?? 'Unnamed Group',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (group.location != null)
                    Text(
                        'Location: ${group.location!.cityName}, ${group.location!.countryName}'),
                  const SizedBox(height: 16),
                  if (group.invite != null && group.joinEnabled == true) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Invite Code: ${group.invite!.code}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: group.invite!.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Invite code copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  if (group.joinEnabled == false)
                    const Text('Joining is disabled (Session active)'),
                  if (!isAdmin && !hasActiveSession)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Waiting for the admin to start a session.'),
                    ),
                ],
              ),
            ),
          ),
          if (isAdmin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Admin Controls',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),
                      if (!hasActiveSession) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Limit Type: '),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Swipes'),
                              selected: !_isTimeLimit,
                              onSelected: (val) {
                                if (val) setState(() => _isTimeLimit = false);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Time (mins)'),
                              selected: _isTimeLimit,
                              onSelected: (val) {
                                if (val) setState(() => _isTimeLimit = true);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(_isTimeLimit ? 'Time Limit: ' : 'Swipe Limit: '),
                            Expanded(
                              child: TextField(
                                controller: _isTimeLimit ? _timeLimitController : _swipeLimitController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  suffixText: _isTimeLimit ? 'mins' : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'Start Session',
                          icon: Icons.play_arrow,
                          onPressed: _startSession,
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: () => controller.endSession(),
                          icon: const Icon(Icons.stop),
                          label: const Text('End Session Early'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (group.members.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Members (${group.members.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: group.members.length,
              itemBuilder: (context, index) {
                final memberId = group.members[index];
                final isMemberAdmin = memberId == group.ownerUid;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(memberId.substring(0, 1).toUpperCase()),
                  ),
                  title:
                      Text(memberId == userId ? 'You' : 'Member ${index + 1}'),
                  subtitle: Text(memberId),
                  trailing: isMemberAdmin
                      ? const Icon(Icons.star, color: Colors.amber)
                      : null,
                );
              },
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (hasActiveSession)
                  PrimaryButton(
                    label: 'Continue Swiping',
                    icon: Icons.swipe,
                    width: double.infinity,
                    onPressed: () => context.push('/swipe/${group.groupId}'),
                  )
                else
                  PrimaryButton(
                    label: 'View Matches',
                    icon: Icons.favorite,
                    width: double.infinity,
                    onPressed: () =>
                        context.push('/group-matches/${group.groupId}'),
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
      ),
    );
  }

  void _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty ||
        _selectedCountryCode == null ||
        _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and select location')),
      );
      return;
    }

    final location = GroupLocation(
      countryCode: _selectedCountryCode!,
      countryName: _selectedCountryName!,
      cityId: _selectedCity!['cityId'] as String,
      cityName: _selectedCity!['cityName'] as String,
      lat: _selectedCity!['lat'] as double,
      lng: _selectedCity!['lng'] as double,
    );

    try {
      await ref.read(groupControllerProvider.notifier).createGroupWithSettings(
            groupName: groupName,
            location: location,
          );
      if (mounted) {
        setState(() {
          _showCreateGroup = false;
          _groupNameController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error creating group: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _startSession() async {
    int? swipeLimit;
    int? timeLimit;

    if (_isTimeLimit) {
      final valStr = _timeLimitController.text.trim();
      timeLimit = int.tryParse(valStr) ?? 5;
      if (timeLimit < 1 || timeLimit > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time limit must be between 1 and 120 mins')),
        );
        return;
      }
      swipeLimit = 100; // Large arbitrary limit when using time
    } else {
      final limitStr = _swipeLimitController.text.trim();
      swipeLimit = int.tryParse(limitStr) ?? 10;
      if (swipeLimit < 1 || swipeLimit > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Swipe limit must be between 1 and 100')),
        );
        return;
      }
    }

    try {
      await ref
          .read(groupControllerProvider.notifier)
          .startSessionWithLimit(swipeLimit: swipeLimit, durationMinutes: timeLimit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Session started!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error starting session: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group via Invite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _inviteCodeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code (6 chars)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _inviteCodeController.clear();
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
    final code = _inviteCodeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an Invite Code')),
      );
      return;
    }

    try {
      await ref
          .read(groupControllerProvider.notifier)
          .joinByInviteCodeOnly(code);
      if (mounted) {
        _inviteCodeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Successfully joined group!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error joining group: $e'),
              backgroundColor: Colors.red),
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
              await ref
                  .read(groupControllerProvider.notifier)
                  .leaveGroup(groupId, userId);
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

  void _confirmDeleteGroup(GroupModel group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text("Are you sure you want to delete '${group.groupName}'? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(groupRepositoryProvider).deleteGroup(group.groupId);
                ref.invalidate(userGroupsProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting group: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class GroupJoinScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String code;

  const GroupJoinScreen({super.key, required this.groupId, required this.code});

  @override
  ConsumerState<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends ConsumerState<GroupJoinScreen> {
  bool _attempted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_attempted) {
      _attempted = true;
      _join();
    }
  }

  Future<void> _join() async {
    try {
      await ref
          .read(groupControllerProvider.notifier)
          .joinByInviteLink(widget.groupId, widget.code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Joined group via link!'),
              backgroundColor: Colors.green),
        );
        context.go('/group');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to join via link: $e'),
              backgroundColor: Colors.red),
        );
        context.go('/group');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Joining Group...'),
          ],
        ),
      ),
    );
  }
}
