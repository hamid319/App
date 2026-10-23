import 'package:meta/meta.dart';

import 'photo_credit.dart';
import 'place_prompt.dart';

/// What a place is: a sight from the Wikidata import, or a venue
/// (restaurant, café, bar ...) from OpenStreetMap. Docs without `kind` are
/// sights.
enum PlaceKind {
  sight,
  venue;

  static PlaceKind fromJson(Object? value) =>
      value == 'venue' ? PlaceKind.venue : PlaceKind.sight;
}

@immutable
class PlaceModel {
  final String id;
  final String name;
  final String? description;
  final double lat;
  final double lng;
  final String? address;
  final List<String> imageUrls;
  final List<String> photoResourceNames;
  final double? averageRating;
  final List<String> types;

  final String? cityId;

  /// Prompt tiles for the detail page; empty until the backend fills them.
  final List<PlacePrompt> prompts;

  /// Author and licence per photo, in the same order as the photos.
  final List<PhotoCredit> photoCredits;

  /// Name and description per language code from the curated import
  /// (`names`, `descriptions`); [name] and [description] stay the
  /// English or only text.
  final Map<String, String> names;
  final Map<String, String> descriptions;

  /// Wikipedia article the description was taken from, per language.
  /// The text is CC BY-SA, so the app links its source.
  final Map<String, String> wikipediaUrls;

  /// OpenStreetMap opening_hours value, e.g. "Tu-Su 10:00-18:00".
  final String? openingHours;
  final String? website;

  /// OpenStreetMap element the facts come from (address, hours); the
  /// app must credit "© OpenStreetMap contributors" (ODbL).
  final String? osmUrl;

  final PlaceKind kind;

  /// Import ranking, higher is better known (sights >= 950, venues 0..499).
  final int? popularity;

  /// OpenStreetMap cuisine of a venue, e.g. "italian;pizza".
  final String? cuisine;

  bool get isVenue => kind == PlaceKind.venue;

  const PlaceModel({
    required this.id,
    required this.name,
    this.description,
    required this.lat,
    required this.lng,
    this.address,
    this.imageUrls = const [],
    this.photoResourceNames = const [],
    this.averageRating,
    this.types = const [],
    this.cityId,
    this.prompts = const [],
    this.photoCredits = const [],
    this.names = const {},
    this.descriptions = const {},
    this.wikipediaUrls = const {},
    this.openingHours,
    this.website,
    this.osmUrl,
    this.kind = PlaceKind.sight,
    this.popularity,
    this.cuisine,
  });

  /// Name in [languageCode], else the default name.
  String nameFor(String languageCode) => names[languageCode] ?? name;

  /// Description in [languageCode], else the default description.
  String? descriptionFor(String languageCode) =>
      descriptions[languageCode] ?? description;

  /// Wikipedia source of [descriptionFor], if the text came from there.
  String? wikipediaUrlFor(String languageCode) =>
      descriptions.containsKey(languageCode)
          ? wikipediaUrls[languageCode]
          : wikipediaUrls['en'] ?? wikipediaUrls[languageCode];

  PlaceModel copyWith({
    String? id,
    String? name,
    String? description,
    double? lat,
    double? lng,
    String? address,
    List<String>? imageUrls,
    List<String>? photoResourceNames,
    double? averageRating,
    List<String>? types,
    String? cityId,
    List<PlacePrompt>? prompts,
    List<PhotoCredit>? photoCredits,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      imageUrls: imageUrls ?? this.imageUrls,
      photoResourceNames: photoResourceNames ?? this.photoResourceNames,
      averageRating: averageRating ?? this.averageRating,
      types: types ?? this.types,
      cityId: cityId ?? this.cityId,
      prompts: prompts ?? this.prompts,
      photoCredits: photoCredits ?? this.photoCredits,
      names: names,
      descriptions: descriptions,
      wikipediaUrls: wikipediaUrls,
      openingHours: openingHours,
      website: website,
      osmUrl: osmUrl,
      kind: kind,
      popularity: popularity,
      cuisine: cuisine,
    );
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) => PlaceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        address: json['address'] as String?,
        imageUrls: _imageUrls(json),
        photoResourceNames:
            List<String>.from(json['photoResourceNames'] ?? const <String>[]),
        averageRating: json['averageRating'] != null
            ? (json['averageRating'] as num).toDouble()
            : null,
        types: List<String>.from(json['types'] ?? (json['tags'] ?? [])),
        cityId: json['cityId'] as String?,
        prompts: PlacePrompt.listFromJson(json['prompts']),
        photoCredits: PhotoCredit.listFromPlaceJson(json),
        names: _stringMap(json['names']),
        descriptions: _stringMap(json['descriptions']),
        wikipediaUrls: _stringMap(json['wikipediaUrls']),
        openingHours: _text(json['openingHours']),
        website: _text(json['website']),
        osmUrl: _text(json['osmUrl']),
        kind: PlaceKind.fromJson(json['kind']),
        popularity: _int(json['popularity']),
        cuisine: _text(json['cuisine']),
      );

  static int? _int(Object? value) => switch (value) {
        final int v => v,
        final num v when v.isFinite => v.round(),
        final String v => int.tryParse(v.trim()),
        _ => null,
      };

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String &&
            entry.value is String &&
            (entry.value as String).trim().isNotEmpty)
          entry.key as String: (entry.value as String).trim(),
    };
  }

  static List<String> _imageUrls(Map<String, dynamic> json) {
    final urls =
        List<String>.from(json['imageUrls'] ?? (json['images'] ?? const []));
    return urls.isNotEmpty ? urls : PhotoCredit.pipelineImageUrls(json);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'lat': lat,
        'lng': lng,
        'address': address,
        'photoResourceNames': photoResourceNames,
        'averageRating': averageRating,
        'types': types,
        'cityId': cityId,
        'kind': kind.name,
        if (popularity != null) 'popularity': popularity,
        if (cuisine != null) 'cuisine': cuisine,
      };
}
