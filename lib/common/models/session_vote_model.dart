import 'package:meta/meta.dart';

@immutable
class SessionVoteModel {
  final String placeId;
  final int likes;
  final int dislikes;
  final List<String> likedBy;
  final List<String> dislikedBy;

  const SessionVoteModel({
    required this.placeId,
    this.likes = 0,
    this.dislikes = 0,
    this.likedBy = const [],
    this.dislikedBy = const [],
  });

  SessionVoteModel copyWith({
    String? placeId,
    int? likes,
    int? dislikes,
    List<String>? likedBy,
    List<String>? dislikedBy,
  }) {
    return SessionVoteModel(
      placeId: placeId ?? this.placeId,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      likedBy: likedBy ?? this.likedBy,
      dislikedBy: dislikedBy ?? this.dislikedBy,
    );
  }

  factory SessionVoteModel.fromJson(Map<String, dynamic> json) {
    return SessionVoteModel(
      placeId: json['placeId'] as String,
      likes: json['likes'] as int? ?? 0,
      dislikes: json['dislikes'] as int? ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      dislikedBy: List<String>.from(json['dislikedBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'likes': likes,
        'dislikes': dislikes,
        'likedBy': likedBy,
        'dislikedBy': dislikedBy,
      };
}
