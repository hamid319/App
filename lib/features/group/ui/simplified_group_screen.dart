import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../logic/group_controller.dart';
import '../../../common/models/group_model.dart';
import '../../../common/widgets/primary_button.dart';
import '../../../common/widgets/error_view.dart';
import '../../auth/logic/auth_controller.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../app/theme.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/member_avatar.dart';
import '../widgets/session_progress_panel.dart';
import '../../../common/widgets/city_picker.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../common/utils/trip_dates.dart';
import '../../../main_providers.dart';
import '../widgets/calendar_trip_sheet.dart';

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

  /// Destination of the group being created.
  PopularCity? _city;

  /// Optional travel dates of the group being created.
  DateTimeRange? _tripDates;

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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    void open() =>
        ref.read(selectedGroupIdProvider.notifier).updateState(group.groupId);

    final (String label, Color fg, Color bg, VoidCallback onTap) status = isLive
        ? (
            l10n.statusLive,
            context.swipeColors.like,
            context.swipeColors.like.withValues(alpha: 0.14),
            () => context.push('/swipe/${group.groupId}'),
          )
        : hasCompleted
            ? (
                l10n.statusDone,
                scheme.onSurfaceVariant,
                scheme.surfaceContainerHighest,
                () => context.push('/group-matches/${group.groupId}'),
              )
            : isOwner
                ? (
                    l10n.statusStart,
                    scheme.primary,
                    scheme.primaryContainer,
                    open,
                  )
                : (
                    l10n.statusIdle,
                    scheme.onSurfaceVariant,
                    scheme.surfaceContainerHighest,
                    open,
                  );
    final subtitle = [
      if (group.location?.cityName.isNotEmpty == true) group.location!.cityName,
      if (group.tripStart != null)
        formatTripDates(group.tripStart!, group.tripEnd,
            Localizations.localeOf(context).toLanguageTag()),
      l10n.memberCount(group.members.length),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
            child: Row(
              children: [
                _AvatarStack(memberIds: group.members),
                const SizedBox(width: 12),
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
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: status.$4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: status.$3,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLive) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: status.$2,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          status.$1,
                          style: text.labelMedium?.copyWith(
                            color: status.$2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDashboard() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.groups_rounded, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.noGroupsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _fillFromCalendar,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(context.l10n.fromCalendar),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: context.l10n.groupNameLabel,
                  hintText: context.l10n.groupNameHint,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _CityField(
                city: _city,
                onTap: () => showCityPicker(
                  context,
                  selectedId: _city?.id,
                  offerCurrentLocation: false,
                  onSelected: (city) => setState(() => _city = city),
                ),
              ),
              const SizedBox(height: 16),
              _TripDatesField(
                dates: _tripDates,
                onTap: _pickTripDates,
                onClear: () => setState(() => _tripDates = null),
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
                          _city = null;
                          _tripDates = null;
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
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (group.location != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              '${group.location!.cityName}, '
                                  '${group.location!.countryName}',
                              if (group.tripStart != null)
                                formatTripDates(
                                  group.tripStart!,
                                  group.tripEnd,
                                  Localizations.localeOf(context)
                                      .toLanguageTag(),
                                ),
                            ].join(' · '),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (group.invite != null && group.joinEnabled == true) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.inviteCodeTitle.toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  group.invite!.code,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(letterSpacing: 3),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(context)
                                .copyButtonLabel,
                            icon: const Icon(Icons.copy_rounded),
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
                                  suffixText: _isTimeLimit
                                      ? context.l10n.minutesSuffix
                                      : null,
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
                              foregroundColor:
                                  Theme.of(context).colorScheme.error),
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
                final label =
                    memberId == userId ? context.l10n.memberYou(name) : name;
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
                else if (group.hasCompletedSession == true)
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
                    child: Text(context.l10n.leaveGroup,
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
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
            backgroundColor: context.swipeColors.like,
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
      final valStr = _timeLimitController.text.trim();
      timeLimit = int.tryParse(valStr) ?? 5;
      if (timeLimit < 1 || timeLimit > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.timeLimitRange)),
        );
        return;
      }
      swipeLimit = 100; // Large arbitrary limit when using time
    } else {
      final limitStr = _swipeLimitController.text.trim();
      swipeLimit = int.tryParse(limitStr) ?? 10;
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
              content: Text(context.l10n.sessionStarted),
              backgroundColor: context.swipeColors.like),
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
              content: Text(context.l10n.joinedGroup),
              backgroundColor: context.swipeColors.like),
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
              content: Text(context.l10n.joinedViaLink),
              backgroundColor: context.swipeColors.like),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const size = 34.0;
    const overlap = 12.0;
    final shown = memberIds.take(3).toList();
    final ring = Theme.of(context).colorScheme.surface;
    return SizedBox(
      width: size + (shown.length - 1).clamp(0, 2) * (size - overlap),
      height: size,
      child: Stack(
        children: [
          for (final (i, id) in shown.indexed)
            Positioned(
              left: i * (size - overlap),
              child: MemberAvatar(
                id: id,
                name: ref.watch(groupMemberNameProvider(id)).value ?? '',
                size: size,
                borderColor: ring,
              ),
            ),
        ],
      ),
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
