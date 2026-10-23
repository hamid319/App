import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../common/models/place_model.dart';
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

/// All favorites as markers on a Google map; tapping a marker's label
/// opens the place. Only the map tiles come from Google: no Places API.
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

    Widget message(String text) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space24),
            child: Text(text, textAlign: TextAlign.center),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesMapTitle)),
      body: switch (configured) {
        AsyncData(value: false) => message(l10n.mapsNotConfigured),
        AsyncData() => places.when(
            data: (list) => list.isEmpty
                ? message(l10n.favoritesMapEmpty)
                : _FavoritesMap(places: list),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => message(
              userMessage(e, fallback: l10n.errorLoadFavorites, l10n: l10n),
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
    final lang = Localizations.localeOf(context).languageCode;
    final markers = {
      for (final place in places)
        Marker(
          markerId: MarkerId(place.id),
          position: LatLng(place.lat, place.lng),
          infoWindow: InfoWindow(
            title: place.nameFor(lang),
            onTap: () => context.push('/place/${place.id}'),
          ),
        ),
    };
    final bounds = _boundsOf(places);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: bounds.center, zoom: 12),
      markers: markers,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        if (places.length < 2) return;
        // After the first frame, so the map knows its size.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.animateCamera(
            CameraUpdate.newLatLngBounds(bounds.latLngBounds, 64),
          );
        });
      },
    );
  }
}

({LatLng center, LatLngBounds latLngBounds}) _boundsOf(List<PlaceModel> places) {
  var south = places.first.lat, north = south;
  var west = places.first.lng, east = west;
  for (final p in places) {
    south = math.min(south, p.lat);
    north = math.max(north, p.lat);
    west = math.min(west, p.lng);
    east = math.max(east, p.lng);
  }
  return (
    center: LatLng((south + north) / 2, (west + east) / 2),
    latLngBounds: LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    ),
  );
}
