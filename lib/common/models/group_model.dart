import 'package:meta/meta.dart';

@immutable
class GroupModel {
  final String groupId;
  final String? groupName;
  final List<String> members;
  final List<String> sharedFavorites;

  const GroupModel({
    required this.groupId,
    this.groupName,
    this.members = const [],
    this.sharedFavorites = const [],
  });

  GroupModel copyWith({
    String? groupId,
    String? groupName,
    List<String>? members,
    List<String>? sharedFavorites,
  }) {
    return GroupModel(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      members: members ?? this.members,
      sharedFavorites: sharedFavorites ?? this.sharedFavorites,
    );
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        groupId: json['groupId'] as String,
        groupName: json['groupName'] as String?,
        members: List<String>.from(json['members'] ?? []),
        sharedFavorites: List<String>.from(json['sharedFavorites'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupName': groupName,
        'members': members,
        'sharedFavorites': sharedFavorites,
      };
}
