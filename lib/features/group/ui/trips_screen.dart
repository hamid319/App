import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../common/models/group_model.dart';
import '../../../common/utils/trip_days.dart';
import '../../../common/widgets/error_view.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/suitcase_view.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../app/theme.dart';
import '../logic/group_controller.dart';
import '../logic/trip_controller.dart';
import '../widgets/join_trip_dialog.dart';
import '../widgets/sync_badge.dart';
import '../widgets/trip_create_sheet.dart';
import '../widgets/trip_ui.dart';

/// "Trips" tab: the next trip as a large card, other planned trips and
/// past trips as grouped lists. "+" plans a new trip or joins one by code.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key, this.openCreate = false});

  /// Opens the "new trip" sheet right away (`/trips?create=1`, e.g. from
  /// "Add to trip" on a place when there is no trip yet).
  final bool openCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trips = ref.watch(userGroupsProvider);
    ref.watch(inviteIndexBackfillProvider);
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
                      if (openCreate) _OnFirstFrame(() => _create(context)),
                      const Padding(
                        padding: EdgeInsets.only(right: 8, bottom: 12),
                        child: TripsSyncBadge(),
                      ),
                      _AddButton(onTap: () => _showAddMenu(context, ref)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (groups.isEmpty)
                    _EmptyHero(
                      onCreate: () => _create(context),
                      onJoin: () => _join(context, ref),
                    ),
                  // Nothing coming up: inspiration for the next trip.
                  if (hero == null) ...[
                    const SizedBox(height: 24),
                    TripSectionHeader(l10n.tripsDestinations),
                    const SizedBox(height: 8),
                    _Destinations(
                        onPick: (city) => _create(context, city: city)),
                  ],
                  if (groups.isEmpty) ...[
                    const SizedBox(height: 24),
                    TripSectionHeader(l10n.tripsHowTitle),
                    const SizedBox(height: 8),
                    const _HowItWorks(),
                  ],
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

  Future<void> _create(BuildContext context, {PopularCity? city}) async {
    final id = await showCreateTripSheet(context, city: city);
    // The sheet already celebrated the new trip.
    if (id != null && context.mounted) context.push('/trip/$id');
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final id = await showJoinTripDialog(context, ref);
    if (id != null && context.mounted) context.push('/trip/$id');
  }
}

/// Runs [action] once after its first frame.
class _OnFirstFrame extends StatefulWidget {
  const _OnFirstFrame(this.action);

  final VoidCallback action;

  @override
  State<_OnFirstFrame> createState() => _OnFirstFrameState();
}

class _OnFirstFrameState extends State<_OnFirstFrame> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.action();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
                      if (openPolls > 0)
                        Text(
                          l10n.tripOpenPolls(openPolls),
                          style:
                              text.labelLarge?.copyWith(color: scheme.primary),
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

/// Start of the tab while there is no trip: where to next, plan or join.
class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    // Brand colours on purpose: the card looks the same in light and dark.
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: BrandColors.navy,
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -36,
              child: Container(
                width: 170,
                height: 170,
                decoration: const BoxDecoration(
                  color: BrandColors.coral,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Positioned(
              right: 14,
              top: 14,
              width: 104,
              height: 104,
              child: ExcludeSemantics(
                child: CustomPaint(painter: SuitcasePainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 120),
                    child: Text(
                      l10n.tripsEmptyTitle,
                      style: text.headlineSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 110),
                    child: Text(
                      l10n.tripsEmptyBody,
                      style: text.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.tripsPlanTrip),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: BrandColors.navy,
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: onJoin,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: Text(l10n.tripsJoin),
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

/// Curated cities to start a trip to; a tap opens "new trip" with the
/// city picked. Covers cost at most three reads per city.
class _Destinations extends StatelessWidget {
  const _Destinations({required this.onPick});

  final ValueChanged<PopularCity> onPick;

  static const _ids = [
    'pt_lisbon',
    'es_barcelona',
    'it_rome',
    'fr_paris',
    'nl_amsterdam',
    'cz_prague',
    'dk_copenhagen',
    'gr_athens',
  ];

  @override
  Widget build(BuildContext context) {
    final cities = [
      for (final id in _ids) ...popularCities.where((c) => c.id == id),
    ];
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: cities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) =>
            _DestinationCard(city: cities[i], onTap: () => onPick(cities[i])),
      ),
    );
  }
}

class _DestinationCard extends ConsumerWidget {
  const _DestinationCard({required this.city, required this.onTap});

  final PopularCity city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = ref.watch(cityCoverProvider(city.id)).value;
    final name = city.nameFor(Localizations.localeOf(context).languageCode);
    final flag = String.fromCharCodes(
        city.countryCode.toUpperCase().codeUnits.map((c) => c + 127397));
    return Semantics(
      button: true,
      label: name,
      child: SizedBox(
        width: 136,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                PlacePhoto(place: cover)
              else
                ColoredBox(color: context.swipeColors.peach),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, -0.1),
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, PhotoColors.scrimBottom],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: ExcludeSemantics(
                  child: Text(
                    '$flag  $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three steps of planning together, for people new to TripFam.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.swipeColors;
    return InsetGroup(
      separatorIndent: 14 + 40 + 12,
      children: [
        _Step(
          icon: Icons.style_rounded,
          tint: colors.peach,
          title: l10n.tripsHowSwipe,
          body: l10n.tripsHowSwipeBody,
        ),
        _Step(
          icon: Icons.map_rounded,
          tint: colors.sky,
          title: l10n.tripsHowDays,
          body: l10n.tripsHowDaysBody,
        ),
        _Step(
          icon: Icons.receipt_long_rounded,
          tint: colors.mint,
          title: l10n.tripsHowCosts,
          body: l10n.tripsHowCostsBody,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: scheme.onSurface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: text.bodyMedium
                      ?.copyWith(fontSize: 14, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
