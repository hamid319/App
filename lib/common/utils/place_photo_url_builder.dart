import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/core/config/env.dart';

class PlacePhotoUrlBuilder {
  const PlacePhotoUrlBuilder({required this.apiKey});

  factory PlacePhotoUrlBuilder.fromEnvironment() =>
      PlacePhotoUrlBuilder(apiKey: Env.googlePlacesApiKey);

  final String apiKey;

  String build(String resourceName, {int maxWidthPx = 800}) {
    return Uri.https(
      'places.googleapis.com',
      '/v1/$resourceName/media',
      <String, String>{
        'maxWidthPx': '$maxWidthPx',
        'key': apiKey,
      },
    ).toString();
  }

  List<String> resolve(PlaceModel place, {int maxWidthPx = 800}) {
    if (place.imageUrls.isNotEmpty) return place.imageUrls;
    if (apiKey.isEmpty) return const <String>[];
    return place.photoResourceNames
        .map((name) => build(name, maxWidthPx: maxWidthPx))
        .toList(growable: false);
  }
}

List<String> resolvePlacePhotoUrls(PlaceModel place) =>
    PlacePhotoUrlBuilder.fromEnvironment().resolve(place);
