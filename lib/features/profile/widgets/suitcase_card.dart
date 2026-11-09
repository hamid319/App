import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/utils/suitcase_progress.dart';
import '../../../common/widgets/suitcase_3d.dart';
import '../../../common/widgets/suitcase_view.dart';
import '../../../core/constants/sizes.dart';
import '../../../l10n/l10n.dart';
import '../logic/passport_controller.dart';

String suitcaseLevelName(AppLocalizations l10n, int level) => switch (level) {
      0 => l10n.suitcaseLevel0,
      1 => l10n.suitcaseLevel1,
      2 => l10n.suitcaseLevel2,
      3 => l10n.suitcaseLevel3,
      _ => l10n.suitcaseLevel4,
    };

String _extraName(AppLocalizations l10n, SuitcaseExtra e) => switch (e) {
      SuitcaseExtra.tag => l10n.suitcaseExtraTag,
      SuitcaseExtra.strap => l10n.suitcaseExtraStrap,
      SuitcaseExtra.goldWheels => l10n.suitcaseExtraGoldWheels,
      SuitcaseExtra.goldHandle => l10n.suitcaseExtraGoldHandle,
    };

String _goalCount(AppLocalizations l10n, SuitcaseGoal goal, int n) =>
    switch (goal) {
      SuitcaseGoal.trips => l10n.suitcaseTrips(n),
      SuitcaseGoal.cities => l10n.suitcaseCities(n),
      SuitcaseGoal.countries => l10n.suitcaseCountries(n),
    };

/// The suitcase stage at the top of the profile: level, the suitcase with
/// its city stickers, the next extra still locked, miles to the next level
/// and how to earn more. Tap explains how it grows.
class SuitcaseCard extends ConsumerWidget {
  const SuitcaseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(suitcaseProgressProvider);
    if (p == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onPrimaryContainer;
    final next = p.nextExtra;
    final nextAt = p.nextLevelAt;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: scheme.primaryContainer,
        child: InkWell(
          onTap: () => _showHow(context, p),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.suitcaseLevel(p.level + 1),
                        style: text.labelLarge
                            ?.copyWith(color: scheme.onPrimary, fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    Text(suitcaseLevelName(l10n, p.level),
                        style: text.titleMedium?.copyWith(color: on)),
                  ],
                ),
                SizedBox(
                  height: 196,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Suitcase3D(
                        size: 188,
                        stickers: [
                          for (final s in p.stickers)
                            SuitcaseSticker.fromStamp(s)
                        ],
                        extras: p.extras,
                        semanticLabel: l10n.suitcaseTitle,
                      ),
                      if (next != null)
                        Positioned(
                          right: 0,
                          top: 16,
                          child: _LockedExtra(
                            name: _extraName(l10n, next.extra),
                            missing: l10n.suitcaseStillNeeded(
                                _goalCount(l10n, next.goal, next.missing)),
                          ),
                        ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: p.levelProgress,
                    minHeight: 10,
                    color: scheme.primary,
                    backgroundColor: on.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(l10n.suitcaseMilesTotal(p.miles),
                        style: text.labelLarge?.copyWith(color: on)),
                    const Spacer(),
                    Text(
                      nextAt == null
                          ? l10n.suitcaseAllExtras
                          : l10n.suitcaseNextLevelAt(p.level + 2, nextAt),
                      style: text.bodySmall
                          ?.copyWith(color: on.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space12),
                Row(
                  children: [
                    for (final (miles, label) in [
                      (milesPerCity, l10n.suitcaseChipCity),
                      (milesPerCheckIn, l10n.suitcaseChipCheckIn),
                      (milesPerPackedTrip, l10n.suitcaseChipPacked),
                    ]) ...[
                      if (miles != milesPerCity) const SizedBox(width: 8),
                      Expanded(child: _EarnChip(miles: miles, label: label)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHow(BuildContext context, SuitcaseProgress p) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget row(IconData icon, String label, String trailing,
            {bool muted = false}) =>
        ListTile(
          dense: true,
          leading:
              Icon(icon, color: muted ? scheme.outlineVariant : scheme.primary),
          title: Text(label, style: text.bodyLarge),
          trailing: Text(trailing,
              style: text.titleSmall?.copyWith(color: scheme.primary)),
        );
    Widget group(List<Widget> rows) => ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Material(color: scheme.surface, child: Column(children: rows)),
        );

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge,
              AppSizes.space8, AppSizes.screenEdge, AppSizes.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.suitcaseHowTitle, style: text.titleLarge),
              const SizedBox(height: AppSizes.space16),
              Text(l10n.suitcaseEarnHeader, style: text.titleSmall),
              const SizedBox(height: AppSizes.space8),
              group([
                for (final (icon, label, miles) in [
                  (Icons.luggage_rounded, l10n.suitcaseEarnTrip, milesPerTrip),
                  (
                    Icons.location_city_rounded,
                    l10n.suitcaseEarnCity,
                    milesPerCity
                  ),
                  (
                    Icons.where_to_vote_rounded,
                    l10n.suitcaseEarnCheckIn,
                    milesPerCheckIn
                  ),
                  (
                    Icons.public_rounded,
                    l10n.suitcaseEarnCountry,
                    milesPerCountry
                  ),
                  (
                    Icons.checklist_rounded,
                    l10n.suitcaseEarnPacked,
                    milesPerPackedTrip
                  ),
                ])
                  row(icon, label, '+$miles'),
              ]),
              const SizedBox(height: AppSizes.space16),
              Text(l10n.suitcaseExtrasHeader, style: text.titleSmall),
              const SizedBox(height: AppSizes.space8),
              group([
                for (final e in suitcaseExtraRules.entries)
                  row(
                    p.extras.contains(e.key)
                        ? Icons.check_circle_rounded
                        : Icons.lock_outline_rounded,
                    _extraName(l10n, e.key),
                    _goalCount(l10n, e.value.goal, e.value.need),
                    muted: !p.extras.contains(e.key),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// The next extra, still locked, hanging beside the suitcase.
class _LockedExtra extends StatelessWidget {
  const _LockedExtra({required this.name, required this.missing});

  final String name;
  final String missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(height: 2),
          Text(name,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text(missing,
              textAlign: TextAlign.center,
              style: text.labelSmall
                  ?.copyWith(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// "+30 New city": one way to earn miles.
class _EarnChip extends StatelessWidget {
  const _EarnChip({required this.miles, required this.label});

  final int miles;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('+$miles',
              style: text.titleMedium?.copyWith(color: scheme.primary)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
