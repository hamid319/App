import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

@immutable
class SwipeResultModel {
  final String id;
  final String userId;
  final String placeId;
  final bool liked;
  final DateTime timestamp;

  const SwipeResultModel({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.liked,
    required this.timestamp,
  });

  SwipeResultModel copyWith({
    String? id,
    String? userId,
    String? placeId,
    bool? liked,
    DateTime? timestamp,
  }) {
    return SwipeResultModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      placeId: placeId ?? this.placeId,
      liked: liked ?? this.liked,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory SwipeResultModel.fromJson(Map<String, dynamic> json) {
    final timestampValue = json['timestamp'];
    DateTime parsedTimestamp;
    if (timestampValue is Timestamp) {
      parsedTimestamp = timestampValue.toDate();
    } else if (timestampValue is String) {
      parsedTimestamp = DateTime.parse(timestampValue);
    } else {
      parsedTimestamp = DateTime.now();
    }

    return SwipeResultModel(
      id: json['id'] as String? ?? '${json['userId']}_${json['placeId']}',
      userId: json['userId'] as String,
      placeId: json['placeId'] as String,
      liked: json['liked'] as bool,
      timestamp: parsedTimestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'placeId': placeId,
        'liked': liked,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
