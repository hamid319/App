import 'package:meta/meta.dart';

import 'photo_credit.dart';
import 'place_prompt.dart';

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
  });

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
      );

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
      };
}
