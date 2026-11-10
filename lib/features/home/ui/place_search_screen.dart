import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/place_search_entry.dart';
import '../../../common/utils/place_type_labels.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../main_providers.dart';
import '../logic/place_search_controller.dart';

/// Search for a place by name in the city chosen on Discover (or the city
/// near the user). Searches the city's index on the device as you type.
/// With [groupId] it searches the trip's city and each result gets a
/// button that puts it on the trip's wishlist.
class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key, this.groupId});

  final String? groupId;

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final groupId = widget.groupId;
    final city = groupId == null
        ? ref.watch(searchCityProvider)
        : ref.watch(tripSearchCityProvider(groupId));
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
            : _Results(city: city, query: _query, groupId: groupId),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.city, required this.query, this.groupId});

  final PopularCity city;
  final String query;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final index = ref.watch(placeSearchIndexProvider(city.id));
    final inTrip = groupId == null
        ? null
        : ref.watch(tripPlaceIdsProvider(groupId!)).value ?? const <String>{};
    return index.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(
        icon: Icons.cloud_off_rounded,
        text: userMessage(e, fallback: l10n.errorLoadPlaces, l10n: l10n),
      ),
      data: (entries) {
        Widget tile(PlaceSearchEntry e) => _ResultTile(
              entry: e,
              groupId: groupId,
              inTrip: inTrip?.contains(e.id) ?? false,
            );
        if (query.trim().isEmpty) {
          // The index is sorted best-known first: suggest the top sights.
          final top = entries.where((e) => !e.isVenue).take(5).toList();
          if (top.isEmpty) {
            return _Message(
              icon: Icons.search,
              text: l10n.placeSearchPrompt(city.nameFor(lang)),
            );
          }
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge,
                    AppSizes.space16, AppSizes.screenEdge, AppSizes.space8),
                child: Text(
                  l10n.placeSearchTop(city.nameFor(lang)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final e in top) tile(e),
            ],
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
          itemBuilder: (context, i) => tile(hits[i]),
        );
      },
    );
  }
}

class _ResultTile extends ConsumerWidget {
  const _ResultTile({required this.entry, this.groupId, this.inTrip = false});

  final PlaceSearchEntry entry;

  /// Trip mode: the trailing button adds the place to this trip.
  final String? groupId;
  final bool inTrip;

  void _add(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final uid = ref.read(currentAccountProvider).value?.uid;
    if (uid == null) return;
    final title = entry.nameFor(Localizations.localeOf(context).languageCode);
    // Not awaited: Firestore shows the idea at once (also offline).
    ref
        .read(tripRepositoryProvider)
        .addPlaceIdea(groupId!, placeId: entry.id, title: title, uid: uid)
        .catchError((Object e) {
      messenger.showSnackBar(SnackBar(
        content: Text(userMessage(e, fallback: l10n.errorGeneric, l10n: l10n)),
        backgroundColor: errorColor,
      ));
      return (id: '', added: false);
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.placeSearchAdded(title))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      trailing: groupId == null
          ? null
          : inTrip
              ? Tooltip(
                  message: l10n.placeSearchInTrip,
                  child: Icon(Icons.check_circle, color: scheme.primary),
                )
              : IconButton.filledTonal(
                  tooltip: l10n.placeSearchAddTooltip,
                  icon: const Icon(Icons.add),
                  onPressed: () => _add(context, ref),
                ),
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
