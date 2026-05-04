import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

@immutable
class GroupSessionModel {
  final String sessionId;
  final String destination;
  final String status; // 'waiting', 'in_progress', 'completed'
  final int totalPlacesToSwipe;
  final List<String> participants;
  final DateTime createdAt;

  const GroupSessionModel({
    required this.sessionId,
    required this.destination,
    required this.status,
    required this.totalPlacesToSwipe,
    required this.participants,
    required this.createdAt,
  });

  GroupSessionModel copyWith({
    String? sessionId,
    String? destination,
    String? status,
    int? totalPlacesToSwipe,
    List<String>? participants,
    DateTime? createdAt,
  }) {
    return GroupSessionModel(
      sessionId: sessionId ?? this.sessionId,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      totalPlacesToSwipe: totalPlacesToSwipe ?? this.totalPlacesToSwipe,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory GroupSessionModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreatedAt = DateTime.now();
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        parsedCreatedAt = (json['createdAt'] as Timestamp).toDate();
      } else if (json['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(json['createdAt']) ?? DateTime.now();
      }
    }

    return GroupSessionModel(
      sessionId: json['sessionId'] as String,
      destination: json['destination'] as String,
      status: json['status'] as String? ?? 'waiting',
      totalPlacesToSwipe: json['totalPlacesToSwipe'] as int? ?? 20,
      participants: List<String>.from(json['participants'] ?? []),
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'destination': destination,
        'status': status,
        'totalPlacesToSwipe': totalPlacesToSwipe,
        'participants': participants,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
