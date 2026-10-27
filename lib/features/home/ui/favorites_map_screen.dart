import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/place_model.dart';
import '../../../common/widgets/places_map.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/maps_availability.dart';
import '../../../l10n/l10n.dart';
import '../../../main_providers.dart';
import '../../swipe/logic/swipe_controller.dart';

final _mapsConfiguredProvider =
    FutureProvider<bool>((ref) => MapsAvailability().isConfigured());

final _favoritePlacesProvider =
    FutureProvider.autoDispose.family<List<PlaceModel>, String>((ref, key) {
  final ids = key.isEmpty ? <String>[] : key.split('|');
  return ref.watch(placesRepositoryProvider).loadPlacesByIds(ids);
});

/// All favorites as named pins on a Mapbox map; tapping a pin opens the
/// place. Only the map tiles come from Mapbox: no place data or search.
class FavoritesMapScreen extends ConsumerWidget {
  const FavoritesMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(swipeControllerProvider);
    final ids = ref.read(swipeControllerProvider.notifier).favoritesList;
    final key = ([...ids]..sort()).join('|');
    final configured = ref.watch(_mapsConfiguredProvider);
    final places = ref.watch(_favoritePlacesProvider(key));

    Widget message(String text, IconData icon) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconBadge(icon: icon, tone: ChipTone.sky),
                const SizedBox(height: AppSizes.space24),
                Text(text, textAlign: TextAlign.center),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesMapTitle)),
      body: switch (configured) {
        AsyncData(value: false) => message(l10n.mapsNotConfigured, Icons.map_outlined),
        AsyncData() => places.when(
            data: (list) => list.isEmpty
                ? message(l10n.favoritesMapEmpty, Icons.place_outlined)
                : _FavoritesMap(places: list),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => message(
              userMessage(e, fallback: l10n.errorLoadFavorites, l10n: l10n),
              Icons.cloud_off_rounded,
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _FavoritesMap extends StatelessWidget {
  const _FavoritesMap({required this.places});

  final List<PlaceModel> places;

  @override
  Widget build(BuildContext context) {
    return PlacesMap(
      places: places,
      onTapPlace: (place) => context.push('/place/${place.id}'),
    );
  }
}
