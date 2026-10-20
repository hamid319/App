import 'package:meta/meta.dart';

enum PhotoSource { wikimedia, google }

/// Who took a place photo and under which licence. Wikimedia licences
/// (CC BY / BY-SA) and the Google Maps terms both require showing this next
/// to the photo.
@immutable
class PhotoCredit {
  const PhotoCredit({
    required this.source,
    this.author,
    this.authorUrl,
    this.licenseName,
    this.licenseUrl,
    this.sourceUrl,
  });

  final PhotoSource source;

  /// Plain-text author name; null when the source does not name one.
  final String? author;
  final String? authorUrl;
  final String? licenseName;
  final String? licenseUrl;

  /// Page of the original file (Wikimedia Commons file page).
  final String? sourceUrl;

  /// Reads the credits a place document carries, in photo order:
  /// `photos` from the Wikidata pipeline, `photoAttributions` from the
  /// Google Places Cloud Function.
  static List<PhotoCredit> listFromPlaceJson(Map<String, dynamic> json) {
    final credits = <PhotoCredit>[];
    final photos = json['photos'];
    if (photos is List) {
      for (final photo in photos) {
        if (photo is! Map) continue;
        credits.add(PhotoCredit(
          source: PhotoSource.wikimedia,
          author: _text(photo['creator']),
          licenseName: _text(photo['licenseName']),
          licenseUrl: _text(photo['licenseUrl']),
          sourceUrl: _text(photo['commonsFilePageUrl']),
        ));
      }
    }
    final google = json['photoAttributions'];
    if (google is List) {
      for (final attribution in google) {
        if (attribution is! Map) continue;
        credits.add(PhotoCredit(
          source: PhotoSource.google,
          author: _text(attribution['displayName']),
          authorUrl: _text(attribution['uri']),
        ));
      }
    }
    return credits;
  }

  /// Public image URLs of pipeline photos, used when a document has no
  /// `imageUrls`.
  static List<String> pipelineImageUrls(Map<String, dynamic> json) {
    final photos = json['photos'];
    if (photos is! List) return const [];
    return [
      for (final photo in photos)
        if (photo is Map)
          if (_text(photo['publicUrl']) case final url?) url,
    ];
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
