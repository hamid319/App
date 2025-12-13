import 'package:meta/meta.dart';

@immutable
class SwipeResultModel {
  final String userId;
  final String placeId;
  final bool liked;

  const SwipeResultModel({
    required this.userId,
    required this.placeId,
    required this.liked,
  });

  SwipeResultModel copyWith({
    String? userId,
    String? placeId,
    bool? liked,
  }) {
    return SwipeResultModel(
      userId: userId ?? this.userId,
      placeId: placeId ?? this.placeId,
      liked: liked ?? this.liked,
    );
  }

  factory SwipeResultModel.fromJson(Map<String, dynamic> json) => SwipeResultModel(
        userId: json['userId'] as String,
        placeId: json['placeId'] as String,
        liked: json['liked'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'placeId': placeId,
        'liked': liked,
      };
}
