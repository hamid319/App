import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/features/places/data/place_photo_url_builder.dart';

void main() {
  test('cache serialization stores photo names without media credentials', () {
    const place = PlaceModel(
      id: 'google-place-id',
      name: 'Demo Place',
      lat: 1,
      lng: 2,
      photoResourceNames: <String>[
        'places/google-place-id/photos/photo-1',
      ],
    );

    final json = place.toJson();

    expect(json['photoResourceNames'], isNotEmpty);
    expect(json.containsKey('imageUrls'), isFalse);
    expect(json.toString(), isNot(contains('key=')));
  });

  test('legacy imageUrls remain readable but are not written back', () {
    final place = PlaceModel.fromJson(<String, dynamic>{
      'id': 'legacy-place',
      'name': 'Legacy Place',
      'lat': 1,
      'lng': 2,
      'imageUrls': <String>['https://example.test/legacy.jpg'],
    });

    expect(place.imageUrls, <String>['https://example.test/legacy.jpg']);
    expect(place.toJson().containsKey('imageUrls'), isFalse);
  });

  test('runtime helper builds encoded photo media URLs', () {
    const builder = PlacePhotoUrlBuilder(apiKey: 'runtime-value');

    final url = builder.build(
      'places/place id/photos/photo/value',
      maxWidthPx: 640,
    );

    expect(
      url,
      'https://places.googleapis.com/v1/places/place%20id/photos/photo/value/media?maxWidthPx=640&key=runtime-value',
    );
  });
}
