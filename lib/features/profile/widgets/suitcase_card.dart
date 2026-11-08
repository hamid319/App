import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/utils/suitcase_progress.dart';
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

/// The user's suitcase in the profile: stickers, level, miles to the next
/// level and the next extra. Tap explains how it grows.
class SuitcaseCard extends ConsumerWidget {
  const SuitcaseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(suitcaseProgressProvider);
    if (p == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final next = p.nextExtra;
    final nextAt = p.nextLevelAt;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Material(
        color: scheme.surface,
        child: InkWell(
          onTap: () => _showHow(context, p),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space16),
            child: Row(
              children: [
                SuitcaseView(
                  size: 104,
                  stickers: [
                    for (final s in p.stickers) SuitcaseSticker.fromStamp(s)
                  ],
                  extras: p.extras,
                  semanticLabel: l10n.suitcaseTitle,
                ),
                const SizedBox(width: AppSizes.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.suitcaseLevel(p.level + 1).toUpperCase(),
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(suitcaseLevelName(l10n, p.level),
                          style: text.titleLarge),
                      const SizedBox(height: AppSizes.space8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p.levelProgress,
                          minHeight: 8,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: AppSizes.space4),
                      Text(
                        nextAt == null
                            ? l10n.suitcaseMilesTotal(p.miles)
                            : l10n.suitcaseMiles(p.miles, nextAt),
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSizes.space8),
                      Text(
                        next == null
                            ? l10n.suitcaseAllExtras
                            : l10n.suitcaseNextExtra(
                                _extraName(l10n, next.extra),
                                _goalCount(l10n, next.goal, next.missing)),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
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
