import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/interest.dart';
import '../../../common/widgets/city_picker.dart';
import '../../../core/constants/sizes.dart';
import '../../../l10n/l10n.dart';
import '../logic/discover_preferences_controller.dart';

String interestLabel(AppLocalizations l10n, Interest interest) =>
    switch (interest) {
      Interest.culture => l10n.interestCulture,
      Interest.nature => l10n.interestNature,
      Interest.history => l10n.interestHistory,
      Interest.beach => l10n.interestBeach,
      Interest.views => l10n.interestViews,
      Interest.family => l10n.interestFamily,
      Interest.nightlife => l10n.interestNightlife,
      Interest.shopping => l10n.interestShopping,
    };

IconData interestIcon(Interest interest) => switch (interest) {
      Interest.culture => Icons.museum_outlined,
      Interest.nature => Icons.park_outlined,
      Interest.history => Icons.account_balance_outlined,
      Interest.beach => Icons.beach_access_outlined,
      Interest.views => Icons.landscape_outlined,
      Interest.family => Icons.family_restroom_outlined,
      Interest.nightlife => Icons.nightlife_outlined,
      Interest.shopping => Icons.shopping_bag_outlined,
    };

/// "Nearby" or the chosen city's name in the current language.
String placeLabel(BuildContext context, DiscoverPreferences prefs) {
  final city = prefs.city;
  if (city == null) return context.l10n.nearby;
  return city.nameFor(Localizations.localeOf(context).languageCode);
}

/// "📍 Lisbon ▾" chip in the Discover app bar.
class DiscoverLocationChip extends ConsumerWidget {
  const DiscoverLocationChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(discoverPreferencesProvider).value ??
        const DiscoverPreferences();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${context.l10n.locationTitle} ${placeLabel(context, prefs)}',
      child: Material(
        color: scheme.surface,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showLocationPicker(context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    prefs.city == null
                        ? Icons.near_me_outlined
                        : Icons.place_outlined,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      placeLabel(context, prefs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.expand_more,
                      size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round filter button with a count badge while filters are active.
class DiscoverFilterButton extends ConsumerWidget {
  const DiscoverFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(discoverPreferencesProvider).value ??
        const DiscoverPreferences();
    final active = prefs.activeFilterCount;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: context.l10n.filtersTitle,
      style: IconButton.styleFrom(
        backgroundColor: active > 0 ? scheme.primaryContainer : scheme.surface,
        side: BorderSide(
          color: active > 0 ? scheme.primaryContainer : scheme.outlineVariant,
        ),
      ),
      onPressed: () => showFilterSheet(context, ref),
      icon: Badge(
        isLabelVisible: active > 0,
        label: Text('$active'),
        child: Icon(
          Icons.tune,
          size: 20,
          color: active > 0 ? scheme.primary : scheme.onSurface,
        ),
      ),
    );
  }
}

/// Where the solo deck looks for places.
Future<void> showLocationPicker(BuildContext context, WidgetRef ref) =>
    showCityPicker(
      context,
      selectedId: ref.read(discoverPreferencesProvider).value?.city?.id,
      onSelected: (city) =>
          ref.read(discoverPreferencesProvider.notifier).setCity(city),
    );

/// Interests (multi-select) and distance; applied together.
Future<void> showFilterSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late Set<Interest> _interests;
  late int _radius;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(discoverPreferencesProvider).value ??
        const DiscoverPreferences();
    _interests = {...prefs.interests};
    _radius = prefs.radiusKm;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenEdge,
          0,
          AppSizes.screenEdge,
          AppSizes.space16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.filtersTitle, style: text.headlineSmall),
            const SizedBox(height: AppSizes.space24),
            Text(l10n.interestsTitle, style: text.titleMedium),
            const SizedBox(height: AppSizes.space4),
            Text(
              l10n.interestsHint,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSizes.space12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in Interest.values)
                  FilterChip(
                    avatar: Icon(interestIcon(i), size: 18),
                    label: Text(interestLabel(l10n, i)),
                    selected: _interests.contains(i),
                    showCheckmark: false,
                    selectedColor: scheme.primaryContainer,
                    side: BorderSide(
                      color: _interests.contains(i)
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                    onSelected: (on) => setState(() {
                      on ? _interests.add(i) : _interests.remove(i);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.groupGap),
            Text(l10n.radiusTitle, style: text.titleMedium),
            const SizedBox(height: AppSizes.space12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final km in DiscoverPreferences.radiusOptions)
                    ButtonSegment(value: km, label: Text(l10n.radiusKm(km))),
                ],
                selected: {_radius},
                onSelectionChanged: (s) => setState(() => _radius = s.first),
              ),
            ),
            const SizedBox(height: AppSizes.space32),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _interests = {};
                    _radius = DiscoverPreferences.defaultRadiusKm;
                  }),
                  child: Text(l10n.resetFilters),
                ),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      ref.read(discoverPreferencesProvider.notifier).setFilters(
                            interests: _interests,
                            radiusKm: _radius,
                          );
                      Navigator.pop(context);
                    },
                    child: Text(l10n.applyFilters),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
