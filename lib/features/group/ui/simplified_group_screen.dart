import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../logic/group_controller.dart';
import '../../../common/models/group_model.dart';
import '../../../common/widgets/error_view.dart';
import '../../auth/logic/auth_controller.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/constants/sizes.dart';
import '../../../l10n/l10n.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../common/widgets/ticket.dart';
import '../widgets/session_progress_panel.dart';
import '../../../common/widgets/city_picker.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../common/utils/trip_dates.dart';
import '../../../main_providers.dart';
import '../widgets/calendar_trip_sheet.dart';

/// Swipe limits the admin can step through when starting a session.
const _swipeLimitSteps = [5, 10, 15, 20, 25, 30, 40, 50];

/// Time limits (minutes) the admin can step through.
const _timeLimitSteps = [1, 2, 3, 5, 10, 15, 20, 30, 45, 60];

class SimplifiedGroupScreen extends ConsumerStatefulWidget {
  const SimplifiedGroupScreen({super.key});

  @override
  ConsumerState<SimplifiedGroupScreen> createState() =>
      _SimplifiedGroupScreenState();
}

class _SimplifiedGroupScreenState extends ConsumerState<SimplifiedGroupScreen> {
  final TextEditingController _inviteCodeController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  int _swipeLimit = 10;
  int _timeLimit = 5;

  bool _isTimeLimit = false;
  bool _showCreateGroup = false;

  /// Destination of the group being created.
  PopularCity? _city;

  /// Optional travel dates of the group being created.
  DateTimeRange? _tripDates;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _groupNameController.dispose();
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
        // The details view is a state of this screen, not a route, so the
        // back button clears the selection; its icon comes from the theme.
        leading: selectedId != null
            ? BackButton(
                onPressed: () {
                  ref.read(selectedGroupIdProvider.notifier).updateState(null);
                },
              )
            : null,
        title: Text(selectedId != null
            ? context.l10n.groupDetailsTitle
            : context.l10n.groupsTitle),
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
          message: userMessage(e,
              fallback: context.l10n.errorLoadAccount, l10n: context.l10n),
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
                message: userMessage(e,
                    fallback: context.l10n.errorLoadGroups, l10n: context.l10n),
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
              message: userMessage(e,
                  fallback: context.l10n.errorLoadGroups, l10n: context.l10n),
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
    // While the create form is open its "Create" is the one orange button.
    final newGroupButton = _showCreateGroup
        ? OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.newGroupButton),
          )
        : ElevatedButton.icon(
            onPressed: () => setState(() => _showCreateGroup = true),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.newGroupButton),
          );
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge, AppSizes.space8,
          AppSizes.screenEdge, AppSizes.space16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showJoinGroupDialog,
              icon: const Icon(Icons.group_add),
              label: Text(context.l10n.join),
            ),
          ),
          const SizedBox(width: AppSizes.space12),
          Expanded(child: newGroupButton),
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
                padding: const EdgeInsets.only(top: AppSizes.space24),
                child: _buildEmptyDashboard(),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge,
                    AppSizes.space16, AppSizes.screenEdge, AppSizes.space16),
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
                  padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge, 0,
                      AppSizes.screenEdge, AppSizes.space16),
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    void open() =>
        ref.read(selectedGroupIdProvider.notifier).updateState(group.groupId);

    final (String label, ChipTone tone, IconData? icon, VoidCallback onTap)
        status = isLive
            ? (
                l10n.statusLive,
                ChipTone.peach,
                Icons.bolt_rounded,
                () => context.push('/swipe/${group.groupId}'),
              )
            : hasCompleted
                ? (
                    l10n.statusDone,
                    ChipTone.mint,
                    Icons.check_rounded,
                    () => context.push('/group-matches/${group.groupId}'),
                  )
                : isOwner
                    ? (
                        l10n.statusStart,
                        ChipTone.sky,
                        Icons.play_arrow_rounded,
                        open,
                      )
                    : (l10n.statusIdle, ChipTone.neutral, null, open);
    final subtitle = [
      if (group.location?.cityName.isNotEmpty == true) group.location!.cityName,
      if (group.tripStart != null)
        formatTripDates(group.tripStart!, group.tripEnd,
            Localizations.localeOf(context).toLanguageTag()),
      l10n.memberCount(group.members.length),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space12),
      child: Ticket(
        onTap: open,
        padding: EdgeInsets.fromLTRB(
            AppSizes.space16, AppSizes.space12, isOwner ? 0 : AppSizes.space16,
            AppSizes.space12),
        child: Row(
          children: [
            // Fixed width, so titles line up whether a group has one
            // member or many.
            SizedBox(
              width: _AvatarStack.width,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _AvatarStack(memberIds: group.members),
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName ?? l10n.unnamedGroup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: status.$4,
              child: TagChip(label: status.$1, tone: status.$2, icon: status.$3),
            ),
            if (isOwner)
              PopupMenuButton<String>(
                tooltip: l10n.moreOptions,
                icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                onSelected: (_) => _confirmDeleteGroup(group),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      l10n.deleteGroupTitle,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDashboard() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconBadge(icon: Icons.groups_rounded, tone: ChipTone.sky),
            const SizedBox(height: AppSizes.space24),
            Text(
              context.l10n.noGroupsTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              context.l10n.noGroupsBody,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateGroupCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenEdge),
      child: Ticket(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              context.l10n.createNewGroup,
              trailing: TextButton.icon(
                onPressed: _fillFromCalendar,
                icon: const Icon(Icons.event_outlined),
                label: Text(context.l10n.fromCalendar),
              ),
            ),
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: context.l10n.groupNameLabel,
                hintText: context.l10n.groupNameHint,
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            _CityField(
              city: _city,
              onTap: () => showCityPicker(
                context,
                selectedId: _city?.id,
                offerCurrentLocation: false,
                onSelected: (city) => setState(() => _city = city),
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            _TripDatesField(
              dates: _tripDates,
              onTap: _pickTripDates,
              onClear: () => setState(() => _tripDates = null),
            ),
            const SizedBox(height: AppSizes.space16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showCreateGroup = false;
                        _groupNameController.clear();
                        _city = null;
                        _tripDates = null;
                      });
                    },
                    child: Text(context.l10n.cancel),
                  ),
                ),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: _LoadingElevatedButton(
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
    );
  }

  Widget _buildGroupView(
      GroupModel group, String userId, GroupController controller) {
    final isAdmin = group.ownerUid == userId;
    final hasActiveSession = group.activeSessionId != null;
    final hasCompleted = group.hasCompletedSession == true;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;

    // Exactly one orange call to action, picked by the group's state.
    final Widget? primaryAction = hasActiveSession
        ? ElevatedButton.icon(
            icon: const Icon(Icons.swipe),
            label: Text(l10n.continueSwiping),
            onPressed: () => context.push('/swipe/${group.groupId}'),
          )
        : isAdmin
            ? ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.startSession),
                onPressed: _startSession,
              )
            : hasCompleted
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.favorite),
                    label: Text(l10n.viewMatches),
                    onPressed: () =>
                        context.push('/group-matches/${group.groupId}'),
                  )
                : null;
    final Widget? secondaryAction = hasActiveSession && isAdmin
        ? TextButton.icon(
            onPressed: () => controller.endSession(),
            icon: const Icon(Icons.stop_rounded),
            label: Text(l10n.endSessionEarly),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
          )
        : !hasActiveSession && isAdmin && hasCompleted
            ? OutlinedButton.icon(
                icon: const Icon(Icons.favorite_border),
                label: Text(l10n.viewMatches),
                onPressed: () =>
                    context.push('/group-matches/${group.groupId}'),
              )
            : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge, AppSizes.space8,
          AppSizes.screenEdge, AppSizes.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GroupHeroTicket(
            group: group,
            hasActiveSession: hasActiveSession,
            waitingForAdmin: !isAdmin && !hasActiveSession && !hasCompleted,
          ),
          const SizedBox(height: AppSizes.groupGap),
          if (isAdmin && !hasActiveSession) ...[
            SectionLabel(l10n.sessionSetupTitle),
            _SessionSetup(
              isTimeLimit: _isTimeLimit,
              value: _isTimeLimit ? _timeLimit : _swipeLimit,
              onModeChanged: (time) => setState(() => _isTimeLimit = time),
              onValueChanged: (v) => setState(() {
                if (_isTimeLimit) {
                  _timeLimit = v;
                } else {
                  _swipeLimit = v;
                }
              }),
            ),
            const SizedBox(height: AppSizes.space16),
          ],
          if (hasActiveSession) SessionProgressPanel(userId: userId),
          if (primaryAction != null) primaryAction,
          if (secondaryAction != null) ...[
            const SizedBox(height: AppSizes.space8),
            secondaryAction,
          ],
          if (group.members.isNotEmpty) ...[
            const SizedBox(height: AppSizes.groupGap),
            SectionLabel(l10n.membersHeader(group.members.length)),
            Ticket(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space4),
              child: Column(
                children: [
                  for (final (index, memberId) in group.members.indexed) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        indent: AppSizes.space16 + 40 + AppSizes.space12,
                        color: scheme.outlineVariant,
                      ),
                    _MemberRow(
                      memberId: memberId,
                      fallbackName: l10n.memberFallback(index + 1),
                      isMe: memberId == userId,
                      isAdmin: memberId == group.ownerUid,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSizes.groupGap),
          Center(
            child: TextButton.icon(
              onPressed: () => _leaveGroup(group.groupId),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(l10n.leaveGroup),
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                textStyle: text.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fills name, city and dates from an event the user picks in their
  /// calendar. Calendar access is only requested here, on the user's tap.
  Future<void> _fillFromCalendar() async {
    final calendar = ref.read(calendarServiceProvider);
    final trip = await showCalendarTripSheet(
      context,
      loadTrips: calendar.upcomingTrips,
    );
    if (trip == null || !mounted) return;
    final city = PopularCity.findIn([trip.location, trip.title]);
    setState(() {
      _groupNameController.text = trip.title;
      if (city != null) _city = city;
      _tripDates = DateTimeRange(start: trip.start, end: trip.end);
    });
    if (city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.calendarCityNotFound)),
      );
    }
  }

  Future<void> _pickTripDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      initialDateRange: _tripDates,
    );
    if (picked != null && mounted) setState(() => _tripDates = picked);
  }

  void _createGroup() async {
    final groupName = _groupNameController.text.trim();
    final city = _city;
    if (groupName.isEmpty || city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.enterNameAndLocation)),
      );
      return;
    }

    final location = GroupLocation(
      countryCode: city.countryCode,
      countryName: city.countryNameEn,
      // Stable key for the place cache, e.g. "los_angeles".
      cityId: city.id.substring(city.id.indexOf('_') + 1),
      cityName: city.nameEn,
      lat: city.lat,
      lng: city.lng,
    );

    try {
      await ref.read(groupControllerProvider.notifier).createGroupWithSettings(
            groupName: groupName,
            location: location,
            tripStart: _tripDates?.start,
            tripEnd: _tripDates?.end,
          );
      if (mounted) {
        setState(() {
          _showCreateGroup = false;
          _groupNameController.clear();
          _city = null;
          _tripDates = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupCreated),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userMessage(e,
                  fallback: context.l10n.errorCreateGroup, l10n: context.l10n)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  void _startSession() async {
    int? swipeLimit;
    int? timeLimit;

    if (_isTimeLimit) {
      timeLimit = _timeLimit;
      if (timeLimit < 1 || timeLimit > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.timeLimitRange)),
        );
        return;
      }
      swipeLimit = 100; // Large arbitrary limit when using time
    } else {
      swipeLimit = _swipeLimit;
      if (swipeLimit < 1 || swipeLimit > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.swipeLimitRange)),
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
              content: Text(context.l10n.sessionStarted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userMessage(e,
                  fallback: context.l10n.errorStartSession,
                  l10n: context.l10n)),
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
        content: TextField(
          controller: _inviteCodeController,
          autofocus: true,
          maxLength: 6,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(letterSpacing: 6),
          decoration: InputDecoration(
            hintText: 'ABC123',
            helperText: context.l10n.inviteCodeFieldLabel,
            counterText: '',
          ),
          onSubmitted: (_) {
            _joinGroup();
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _inviteCodeController.clear();
              Navigator.pop(context);
            },
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () {
              _joinGroup();
              Navigator.pop(context);
            },
            child: Text(context.l10n.join),
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
              content: Text(context.l10n.joinedGroup)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userMessage(e,
                  fallback: context.l10n.errorJoinGroup, l10n: context.l10n)),
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
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
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
        content: Text(context.l10n
            .deleteGroupBody(group.groupName ?? context.l10n.unnamedGroup)),
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
                    SnackBar(
                        content: Text(userMessage(e,
                            fallback: l10n.errorDeleteGroup, l10n: l10n))),
                  );
                }
              }
            },
            child: Text(context.l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
              content: Text(context.l10n.joinedViaLink)),
        );
        context.go('/group');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(userMessage(e,
                  fallback: context.l10n.errorJoinGroup, l10n: context.l10n)),
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

/// Up to three overlapping member avatars, like a group chat icon.
class _AvatarStack extends ConsumerWidget {
  const _AvatarStack({required this.memberIds});

  final List<String> memberIds;

  static const _size = 30.0;
  static const _overlap = 12.0;

  /// Width of a full stack of three, used as the fixed leading width.
  static const width = _size + 2 * (_size - _overlap);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = memberIds.take(3).toList();
    final ring = Theme.of(context).colorScheme.surface;
    return SizedBox(
      width: _size + (shown.length - 1).clamp(0, 2) * (_size - _overlap),
      height: _size,
      child: Stack(
        children: [
          for (final (i, id) in shown.indexed)
            Positioned(
              left: i * (_size - _overlap),
              child: MemberAvatar(
                id: id,
                name: friendlyMemberName(
                        ref.watch(groupMemberNameProvider(id)).value) ??
                    '',
                size: _size,
                borderColor: ring,
              ),
            ),
        ],
      ),
    );
  }
}

/// The group as a raised ticket: name, place and dates on top, the invite
/// code on a perforated stub below.
class _GroupHeroTicket extends StatelessWidget {
  const _GroupHeroTicket({
    required this.group,
    required this.hasActiveSession,
    required this.waitingForAdmin,
  });

  final GroupModel group;
  final bool hasActiveSession;
  final bool waitingForAdmin;

  static const _stubHeight = 76.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final location = group.location;
    // The code only works while joining is open (the repository refuses
    // joins otherwise), so the stub is shown only then.
    final showInvite = group.invite != null && group.joinEnabled == true;
    // Joining closes when a session starts; only then say so.
    final String? status = hasActiveSession
        ? l10n.joiningDisabled
        : waitingForAdmin
            ? l10n.waitingForAdmin
            : null;

    return Ticket(
      raised: true,
      notchFromBottom: showInvite ? _stubHeight : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.space16,
                AppSizes.space16, AppSizes.space16, AppSizes.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        group.groupName ?? l10n.unnamedGroup,
                        style: text.headlineSmall,
                      ),
                    ),
                    if (hasActiveSession) ...[
                      const SizedBox(width: AppSizes.space8),
                      TagChip(
                        label: l10n.statusLive,
                        tone: ChipTone.peach,
                        icon: Icons.bolt_rounded,
                      ),
                    ],
                  ],
                ),
                if (location != null) ...[
                  const SizedBox(height: AppSizes.space8),
                  _IconLine(
                    icon: Icons.place_outlined,
                    text: '${location.cityName}, ${location.countryName}',
                    style: muted,
                  ),
                ],
                if (group.tripStart != null) ...[
                  const SizedBox(height: AppSizes.space4),
                  _IconLine(
                    icon: Icons.date_range_outlined,
                    text: formatTripDates(group.tripStart!, group.tripEnd,
                        Localizations.localeOf(context).toLanguageTag()),
                    style: muted,
                  ),
                ],
                const SizedBox(height: AppSizes.space4),
                _IconLine(
                  icon: Icons.group_outlined,
                  text: l10n.memberCount(group.members.length),
                  style: muted,
                ),
                if (status != null) ...[
                  const SizedBox(height: AppSizes.space12),
                  Text(status, style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  )),
                ],
              ],
            ),
          ),
          if (showInvite)
            SizedBox(
              height: _stubHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.space24, AppSizes.space12, AppSizes.space8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.inviteCodeTitle.toUpperCase(),
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            group.invite!.code,
                            style: text.headlineSmall
                                ?.copyWith(letterSpacing: 4),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: group.invite!.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.inviteCodeCopied)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.style});

  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: style?.color),
        const SizedBox(width: AppSizes.space8),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// Compact session setup: limit type plus a stepper for its value.
class _SessionSetup extends StatelessWidget {
  const _SessionSetup({
    required this.isTimeLimit,
    required this.value,
    required this.onModeChanged,
    required this.onValueChanged,
  });

  final bool isTimeLimit;
  final int value;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onValueChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final steps = isTimeLimit ? _timeLimitSteps : _swipeLimitSteps;
    final index = steps.indexOf(value);
    final label = isTimeLimit
        ? l10n.sessionMinutesValue(value)
        : l10n.sessionSwipesValue(value);

    return Ticket(
      padding: const EdgeInsets.all(AppSizes.space12),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.limitSwipes),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.limitTimeShort),
                ),
              ],
              selected: {isTimeLimit},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
          ),
          const SizedBox(width: AppSizes.space8),
          IconButton(
            tooltip: l10n.sessionLimitLess,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed:
                index > 0 ? () => onValueChanged(steps[index - 1]) : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.sessionLimitMore,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: index >= 0 && index < steps.length - 1
                ? () => onValueChanged(steps[index + 1])
                : null,
          ),
        ],
      ),
    );
  }
}

/// One member: avatar, friendly name (never an email), admin chip.
class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.memberId,
    required this.fallbackName,
    required this.isMe,
    required this.isAdmin,
  });

  final String memberId;
  final String fallbackName;
  final bool isMe;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = friendlyMemberName(
            ref.watch(groupMemberNameProvider(memberId)).value) ??
        fallbackName;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16, vertical: AppSizes.space8),
      child: Row(
        children: [
          MemberAvatar(id: memberId, name: name, size: 40),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Text(
              isMe ? l10n.memberYou(name) : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (isAdmin)
            TagChip(
              label: l10n.admin,
              tone: ChipTone.gold,
              icon: Icons.star_rounded,
            ),
        ],
      ),
    );
  }
}

/// The theme's orange button with a spinner while [isLoading].
class _LoadingElevatedButton extends StatelessWidget {
  const _LoadingElevatedButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

/// Read-only field that opens the city picker, styled like a text field.
class _CityField extends StatelessWidget {
  const _CityField({required this.city, required this.onTap});

  final PopularCity? city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: city == null,
        decoration: InputDecoration(
          labelText: context.l10n.cityLabel,
          prefixIcon: const Icon(Icons.place_outlined),
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: city == null
            ? null
            : Text('${city!.nameFor(lang)} · ${city!.countryCode}'),
      ),
    );
  }
}

/// Optional travel dates, styled like the city field; opens a range picker.
class _TripDatesField extends StatelessWidget {
  const _TripDatesField({
    required this.dates,
    required this.onTap,
    required this.onClear,
  });

  final DateTimeRange? dates;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final range = dates;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: range == null,
        decoration: InputDecoration(
          labelText: context.l10n.tripDatesLabel,
          prefixIcon: const Icon(Icons.date_range_outlined),
          suffixIcon: range == null
              ? const Icon(Icons.expand_more)
              : IconButton(
                  tooltip: context.l10n.clearTripDates,
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
        ),
        child: range == null
            ? null
            : Text(formatTripDates(range.start, range.end,
                Localizations.localeOf(context).toLanguageTag())),
      ),
    );
  }
}
