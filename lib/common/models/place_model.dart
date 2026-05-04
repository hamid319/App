import 'package:meta/meta.dart';

@immutable
class PlaceModel {
  final String id;
  final String name;
  final String? description;
  final double lat;
  final double lng;
  final String? address;
  final List<String> imageUrls;
  final double? averageRating;
  final List<String> types;

  const PlaceModel({
    required this.id,
    required this.name,
    this.description,
    required this.lat,
    required this.lng,
    this.address,
    this.imageUrls = const [],
    this.averageRating,
    this.types = const [],
  });

  PlaceModel copyWith({
    String? id,
    String? name,
    String? description,
    double? lat,
    double? lng,
    String? address,
    List<String>? imageUrls,
    double? averageRating,
    List<String>? types,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      imageUrls: imageUrls ?? this.imageUrls,
      averageRating: averageRating ?? this.averageRating,
      types: types ?? this.types,
    );
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) => PlaceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        address: json['address'] as String?,
        imageUrls: List<String>.from(json['imageUrls'] ?? (json['images'] ?? [])),
        averageRating: json['averageRating'] != null ? (json['averageRating'] as num).toDouble() : null,
        types: List<String>.from(json['types'] ?? (json['tags'] ?? [])),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'lat': lat,
        'lng': lng,
        'address': address,
        'imageUrls': imageUrls,
        'averageRating': averageRating,
        'types': types,
      };
}
