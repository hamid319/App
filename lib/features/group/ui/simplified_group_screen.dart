import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../logic/group_controller.dart';
import '../../../common/models/group_model.dart';
import '../../../common/widgets/primary_button.dart';
import '../../../common/widgets/error_view.dart';
import '../../auth/logic/auth_controller.dart';
import '../data/location_repository.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../app/theme.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/member_avatar.dart';
import '../widgets/session_progress_panel.dart';

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
      // Drop the old country's cities so the city field never offers, or
      // holds, a value from another country while the new list loads.
      _cities = [];
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
        title: Text(selectedId != null ? context.l10n.groupDetailsTitle : context.l10n.groupsTitle),
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
        loading: () => const SkeletonList(),
        error: (e, st) => ErrorView(
          message: userMessage(e, fallback: context.l10n.errorLoadAccount, l10n: context.l10n),
          onRetry: () => ref.refresh(authControllerProvider),
        ),
        data: (user) {
          if (user == null) {
            return ErrorView(
              message: context.l10n.loginToUseGroups,
              title: context.l10n.notLoggedIn,
              icon: Icons.login,
              onRetry: () => context.go('/login'),
            );
          }

          if (selectedId != null) {
            return groupState.when(
              loading: () => const SkeletonList(),
              error: (e, st) => ErrorView(
                message: userMessage(e, fallback: context.l10n.errorLoadGroups, l10n: context.l10n),
                onRetry: () => ref.refresh(groupControllerProvider),
              ),
              data: (group) {
                if (group == null) {
                  return Center(child: Text(context.l10n.groupNotFound));
                }
                return _buildGroupView(group, user.uid, groupController);
              },
            );
          }

          return userGroupsAsync.when(
            loading: () => const SkeletonList(),
            error: (e, st) => ErrorView(
              message: userMessage(e, fallback: context.l10n.errorLoadGroups, l10n: context.l10n),
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
              label: Text(context.l10n.join),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              onPressed: () => setState(() => _showCreateGroup = true),
              icon: Icons.add,
              label: context.l10n.newGroupButton,
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
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.l10n.statusLive,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.l10n.statusDone,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        isOwner ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOwner ? context.l10n.statusStart : context.l10n.statusIdle,
                    style: TextStyle(
                      color:
                          isOwner ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
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
        title: Text(group.groupName ?? context.l10n.unnamedGroup),
        subtitle: Text(context.l10n.memberCount(group.members.length)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            if (isOwner)
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error, size: 20),
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
          Icon(Icons.group_add, size: 80, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 24),
          Text(
            context.l10n.noGroupsTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.noGroupsBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest, width: 1, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.createNewGroup,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: context.l10n.groupNameLabel,
                  hintText: context.l10n.groupNameHint,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingLocations && _countries.isEmpty)
                const CircularProgressIndicator()
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.countryLabel,
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _selectedCountryCode,
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
                    // initialValue is only read once, so rebuild the field per
                    // country; otherwise it keeps a city that is no longer in
                    // the list and trips Flutter's dropdown assertion.
                    key: ValueKey(_selectedCountryCode),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.cityLabel,
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedCity,
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
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: context.l10n.create,
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
                    group.groupName ?? context.l10n.unnamedGroup,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (group.location != null)
                    Text(
                        context.l10n.groupLocation(group.location!.cityName, group.location!.countryName)),
                  const SizedBox(height: 16),
                  if (group.invite != null && group.joinEnabled == true) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.inviteCode(group.invite!.code),
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
                              SnackBar(
                                  content:
                                      Text(context.l10n.inviteCodeCopied)),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  if (group.joinEnabled == false)
                    Text(context.l10n.joiningDisabled),
                  if (!isAdmin && !hasActiveSession)
                    Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(context.l10n.waitingForAdmin),
                    ),
                ],
              ),
            ),
          ),
          if (isAdmin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.adminControls,
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
                            Text(context.l10n.limitType),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(context.l10n.limitSwipes),
                              selected: !_isTimeLimit,
                              onSelected: (val) {
                                if (val) setState(() => _isTimeLimit = false);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(context.l10n.limitTime),
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
                            Text(_isTimeLimit
                                ? context.l10n.timeLimitLabel
                                : context.l10n.swipeLimitLabel),
                            Expanded(
                              child: TextField(
                                controller: _isTimeLimit
                                    ? _timeLimitController
                                    : _swipeLimitController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  suffixText: _isTimeLimit ? context.l10n.minutesSuffix : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: context.l10n.startSession,
                          icon: Icons.play_arrow,
                          onPressed: _startSession,
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: () => controller.endSession(),
                          icon: const Icon(Icons.stop),
                          label: Text(context.l10n.endSessionEarly),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (hasActiveSession) SessionProgressPanel(userId: userId),
          if (group.members.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.membersHeader(group.members.length),
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
                final name =
                    ref.watch(groupMemberNameProvider(memberId)).value ??
                        context.l10n.memberFallback(index + 1);
                final label = memberId == userId ? context.l10n.memberYou(name) : name;
                return ListTile(
                  leading: MemberAvatar(id: memberId, name: name, size: 40),
                  title: Text(label),
                  subtitle: isMemberAdmin ? Text(context.l10n.admin) : null,
                  trailing: isMemberAdmin
                      ? Icon(Icons.star, color: context.swipeColors.gold)
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
                    label: context.l10n.continueSwiping,
                    icon: Icons.swipe,
                    width: double.infinity,
                    onPressed: () => context.push('/swipe/${group.groupId}'),
                  )
                else
                  PrimaryButton(
                    label: context.l10n.viewMatches,
                    icon: Icons.favorite,
                    width: double.infinity,
                    onPressed: () =>
                        context.push('/group-matches/${group.groupId}'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _leaveGroup(group.groupId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(context.l10n.leaveGroup, textAlign: TextAlign.center),
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
        SnackBar(content: Text(context.l10n.enterNameAndLocation)),
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
          SnackBar(
            content: Text(context.l10n.groupCreated),
            backgroundColor: context.swipeColors.like,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userMessage(e, fallback: context.l10n.errorCreateGroup, l10n: context.l10n)),
              backgroundColor: Theme.of(context).colorScheme.error),
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
          SnackBar(
              content: Text(context.l10n.timeLimitRange)),
        );
        return;
      }
      swipeLimit = 100; // Large arbitrary limit when using time
    } else {
      final limitStr = _swipeLimitController.text.trim();
      swipeLimit = int.tryParse(limitStr) ?? 10;
      if (swipeLimit < 1 || swipeLimit > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.swipeLimitRange)),
        );
        return;
      }
    }

    try {
      await ref.read(groupControllerProvider.notifier).startSessionWithLimit(
          swipeLimit: swipeLimit, durationMinutes: timeLimit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.sessionStarted), backgroundColor: context.swipeColors.like),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userMessage(e, fallback: context.l10n.errorStartSession, l10n: context.l10n)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.joinGroupViaInvite),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _inviteCodeController,
              decoration: InputDecoration(
                labelText: context.l10n.inviteCodeFieldLabel,
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
            child: Text(context.l10n.cancel),
          ),
          PrimaryButton(
            label: context.l10n.join,
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
        SnackBar(content: Text(context.l10n.enterInviteCode)),
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
          SnackBar(
              content: Text(context.l10n.joinedGroup),
              backgroundColor: context.swipeColors.like),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userMessage(e, fallback: context.l10n.errorJoinGroup, l10n: context.l10n)),
              backgroundColor: Theme.of(context).colorScheme.error),
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
        title: Text(context.l10n.leaveGroupTitle),
        content: Text(context.l10n.leaveGroupBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(groupControllerProvider.notifier)
                  .leaveGroup(groupId, userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.leftGroup)),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(context.l10n.leave),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(GroupModel group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteGroupTitle),
        content: Text(
            context.l10n.deleteGroupBody(group.groupName ?? context.l10n.unnamedGroup)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final l10n = context.l10n;
              Navigator.pop(context);
              try {
                await ref
                    .read(groupRepositoryProvider)
                    .deleteGroup(group.groupId);
                ref.invalidate(userGroupsProvider);
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(userMessage(e, fallback: l10n.errorDeleteGroup, l10n: l10n))),
                  );
                }
              }
            },
            child: Text(context.l10n.delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
          SnackBar(
              content: Text(context.l10n.joinedViaLink),
              backgroundColor: context.swipeColors.like),
        );
        context.go('/group');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userMessage(e, fallback: context.l10n.errorJoinGroup, l10n: context.l10n)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
        context.go('/group');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(context.l10n.joiningGroup),
          ],
        ),
      ),
    );
  }
}
