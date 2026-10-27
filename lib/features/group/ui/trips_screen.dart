import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common/models/group_model.dart';
import '../../../common/utils/trip_days.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/group_controller.dart';
import '../logic/trip_controller.dart';
import '../widgets/join_trip_dialog.dart';
import '../widgets/trip_create_sheet.dart';
import '../widgets/trip_ui.dart';

/// "Trips" tab: the next trip as a large card, other planned trips and
/// past trips as grouped lists. "+" plans a new trip or joins one by code.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trips = ref.watch(userGroupsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: trips.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorView(
            message: userMessage(e, fallback: l10n.errorLoadGroups, l10n: l10n),
            onRetry: () => ref.invalidate(userGroupsProvider),
          ),
          data: (groups) {
            final split = splitTrips(groups, DateTime.now());
            final hero = split.upcoming.isEmpty ? null : split.upcoming.first;
            final planned = split.upcoming.skip(1).toList();
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(userGroupsProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(l10n.tripsTitle, style: text.displaySmall),
                      ),
                      _AddButton(onTap: () => _showAddMenu(context, ref)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (groups.isEmpty)
                    _EmptyTrips(
                      onCreate: () => _create(context),
                      onJoin: () => _join(context, ref),
                    ),
                  if (hero != null) _HeroTripCard(group: hero),
                  if (planned.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    TripSectionHeader(l10n.tripsPlanned),
                    const SizedBox(height: 8),
                    InsetGroup(
                      separatorIndent: 14 + 56 + 12,
                      children: [
                        for (final g in planned)
                          _TripRow(group: g, past: false),
                      ],
                    ),
                  ],
                  if (split.past.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    TripSectionHeader(l10n.tripsPast),
                    const SizedBox(height: 8),
                    InsetGroup(
                      separatorIndent: 14 + 56 + 12,
                      children: [
                        for (final g in split.past)
                          _TripRow(group: g, past: true),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddMenu(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InsetGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_location_alt_outlined),
                  title: Text(l10n.tripNewTitle),
                  onTap: () => Navigator.pop(sheetContext, 0),
                ),
                ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: Text(l10n.tripJoinByCode),
                  onTap: () => Navigator.pop(sheetContext, 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 0) await _create(context);
    if (choice == 1 && context.mounted) await _join(context, ref);
  }

  Future<void> _create(BuildContext context) async {
    final id = await showCreateTripSheet(context);
    if (id != null && context.mounted) {
      showTripSnack(context, context.l10n.groupCreated);
      context.push('/trip/$id');
    }
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final id = await showJoinTripDialog(context, ref);
    if (id != null && context.mounted) context.push('/trip/$id');
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.tripNewTitle,
      child: Material(
        color: scheme.surface,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: const Color(0x14000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(Icons.add_rounded, color: scheme.primary, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Countdown on the hero photo: "in 3 days", "today", "on the road".
String? _countdown(BuildContext context, GroupModel group) {
  final start = group.tripStart;
  if (start == null) return null;
  final days = daysUntil(start, DateTime.now());
  if (days >= 0) return context.l10n.tripCountdown(days);
  return context.l10n.tripOngoing;
}

class _HeroTripCard extends ConsumerWidget {
  const _HeroTripCard({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final countdown = _countdown(context, group);
    final openPolls = ref.watch(openPollCountProvider(group.groupId));
    final subtitle = [
      tripDatesLabel(context, group) ?? group.location?.cityName,
      l10n.tripPeopleCount(group.members.length),
    ].whereType<String>().join(' · ');

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: const Color(0x0F000000),
      child: InkWell(
        onTap: () => context.push('/trip/${group.groupId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 196,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TripCover(group: group),
                  if (countdown != null)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          countdown,
                          style: text.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName ?? l10n.unnamedGroup,
                    style: text.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      AvatarRow(memberIds: group.members),
                      const Spacer(),
                      if (group.activeSessionId != null)
                        Text(
                          l10n.tripSwipeLive,
                          style: text.labelLarge
                              ?.copyWith(color: scheme.primary),
                        )
                      else if (openPolls > 0)
                        Text(
                          l10n.tripOpenPolls(openPolls),
                          style: text.labelLarge
                              ?.copyWith(color: scheme.primary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.group, required this.past});

  final GroupModel group;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final start = group.tripStart;
    final when = start == null
        ? null
        : past
            ? DateFormat.yMMMM(locale).format(start)
            : tripDatesLabel(context, group);
    final subtitle = [
      when ?? group.location?.cityName,
      l10n.tripPeopleCount(group.members.length),
    ].whereType<String>().join(' · ');

    return InkWell(
      onTap: () => context.push('/trip/${group.groupId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 56,
                child: TripCover(group: group),
              ),
            ),
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
                    style: text.bodyMedium?.copyWith(
                        fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return TripCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.luggage_rounded, size: 44, color: scheme.primary),
          const SizedBox(height: 16),
          Text(l10n.tripsEmptyTitle,
              textAlign: TextAlign.center, style: text.headlineSmall),
          const SizedBox(height: 6),
          Text(
            l10n.tripsEmptyBody,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FloatingPrimaryButton(
            label: l10n.tripNewTitle,
            icon: Icons.add_rounded,
            onPressed: onCreate,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onJoin, child: Text(l10n.tripJoinByCode)),
        ],
      ),
    );
  }
}
