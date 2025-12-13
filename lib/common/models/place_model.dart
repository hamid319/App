import 'package:meta/meta.dart';

@immutable
class PlaceModel {
  final String id;
  final String name;
  final String description;
  final double lat;
  final double lng;
  final List<String> images;
  final List<String> tags;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.lat,
    required this.lng,
    this.images = const [],
    this.tags = const [],
  });

  PlaceModel copyWith({
    String? id,
    String? name,
    String? description,
    double? lat,
    double? lng,
    List<String>? images,
    List<String>? tags,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      images: images ?? this.images,
      tags: tags ?? this.tags,
    );
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) => PlaceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        images: List<String>.from(json['images'] ?? []),
        tags: List<String>.from(json['tags'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'lat': lat,
        'lng': lng,
        'images': images,
        'tags': tags,
      };
}
