import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

@immutable
class GroupModel {
  final String groupId;
  final String? groupName;
  final List<String> members;
  final List<String> sharedFavorites;
  final DateTime? createdAt;
  final String? activeSessionId; // To track if a swipe session is ongoing

  const GroupModel({
    required this.groupId,
    this.groupName,
    this.members = const [],
    this.sharedFavorites = const [],
    this.createdAt,
    this.activeSessionId,
  });

  GroupModel copyWith({
    String? groupId,
    String? groupName,
    List<String>? members,
    List<String>? sharedFavorites,
    DateTime? createdAt,
    String? activeSessionId,
  }) {
    return GroupModel(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      members: members ?? this.members,
      sharedFavorites: sharedFavorites ?? this.sharedFavorites,
      createdAt: createdAt ?? this.createdAt,
      activeSessionId: activeSessionId ?? this.activeSessionId,
    );
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        parsedCreatedAt = (json['createdAt'] as Timestamp).toDate();
      } else if (json['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(json['createdAt']);
      }
    }

    return GroupModel(
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String?,
      members: List<String>.from(json['members'] ?? []),
      sharedFavorites: List<String>.from(json['sharedFavorites'] ?? []),
      createdAt: parsedCreatedAt,
      activeSessionId: json['activeSessionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupName': groupName,
        'members': members,
        'sharedFavorites': sharedFavorites,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'activeSessionId': activeSessionId,
      };
}
