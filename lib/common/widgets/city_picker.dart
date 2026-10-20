import 'package:flutter/material.dart';

import '../../core/constants/popular_cities.dart';
import '../../core/constants/sizes.dart';
import '../../l10n/l10n.dart';

/// "Where to?" sheet: optional "Current location", a search field and the
/// popular destinations. Returns the chosen city, or null for the current
/// location; returns without calling [onSelected] when dismissed.
Future<void> showCityPicker(
  BuildContext context, {
  required ValueChanged<PopularCity?> onSelected,
  String? selectedId,
  bool offerCurrentLocation = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _CityPicker(
      onSelected: onSelected,
      selectedId: selectedId,
      offerCurrentLocation: offerCurrentLocation,
    ),
  );
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({
    required this.onSelected,
    required this.selectedId,
    required this.offerCurrentLocation,
  });

  final ValueChanged<PopularCity?> onSelected;
  final String? selectedId;
  final bool offerCurrentLocation;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';

  void _choose(PopularCity? city) {
    widget.onSelected(city);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final q = _query.trim().toLowerCase();
    final cities = popularCities
        .where((c) =>
            q.isEmpty ||
            c.nameEn.toLowerCase().contains(q) ||
            c.nameDe.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.nameFor(lang).compareTo(b.nameFor(lang)));

    Widget check(bool on) =>
        on ? Icon(Icons.check, color: scheme.primary) : const SizedBox.shrink();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenEdge,
              0,
              AppSizes.screenEdge,
              AppSizes.space12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.locationTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSizes.space12),
                TextField(
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l10n.searchCity,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                if (widget.offerCurrentLocation && q.isEmpty)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(Icons.near_me, color: scheme.primary),
                    ),
                    title: Text(l10n.currentLocation),
                    subtitle: Text(l10n.currentLocationSubtitle),
                    trailing: check(widget.selectedId == null),
                    onTap: () => _choose(null),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenEdge,
                    AppSizes.space16,
                    AppSizes.screenEdge,
                    AppSizes.space4,
                  ),
                  child: Text(
                    l10n.popularDestinations.toUpperCase(),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (cities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.screenEdge),
                    child: Text(
                      l10n.noCityFound,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                for (final c in cities)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: Text(
                        c.countryCode,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                      ),
                    ),
                    title: Text(c.nameFor(lang)),
                    trailing: check(widget.selectedId == c.id),
                    onTap: () => _choose(c),
                  ),
                const SizedBox(height: AppSizes.space24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
