import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/place_search_entry.dart';
import '../../../common/utils/place_type_labels.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/place_search_controller.dart';

/// Search for a place by name in the city chosen on Discover (or the city
/// near the user). Searches the city's index on the device as you type.
class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final city = ref.watch(searchCityProvider);
    final cityName = city.value?.nameFor(lang);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSizes.screenEdge),
          child: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: cityName == null
                  ? l10n.placeSearchHint
                  : l10n.placeSearchHintCity(cityName),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
      ),
      body: city.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.cloud_off_rounded,
          text: userMessage(e, fallback: l10n.errorLoadPlaces, l10n: l10n),
        ),
        data: (city) => city == null
            ? _Message(icon: Icons.location_city, text: l10n.placeSearchNoCity)
            : _Results(city: city, query: _query),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.city, required this.query});

  final PopularCity city;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final index = ref.watch(placeSearchIndexProvider(city.id));
    return index.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(
        icon: Icons.cloud_off_rounded,
        text: userMessage(e, fallback: l10n.errorLoadPlaces, l10n: l10n),
      ),
      data: (entries) {
        if (query.trim().isEmpty) {
          return _Message(
            icon: Icons.search,
            text: l10n.placeSearchPrompt(city.nameFor(lang)),
          );
        }
        final hits = searchPlaces(entries, query);
        if (hits.isEmpty) {
          return _Message(
            icon: Icons.search_off,
            text: l10n.placeSearchEmpty(query.trim()),
          );
        }
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: hits.length,
          itemBuilder: (context, i) => _ResultTile(entry: hits[i]),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.entry});

  final PlaceSearchEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    final type = entry.type;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSizes.screenEdge),
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        child: Icon(
          entry.isVenue ? Icons.restaurant_rounded : Icons.account_balance,
          size: 20,
        ),
      ),
      title: Text(entry.nameFor(lang)),
      subtitle: type == null ? null : Text(placeTypeLabel(l10n, type)),
      onTap: () => context.push('/place/${entry.id}'),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSizes.space12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
