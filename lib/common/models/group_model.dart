import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

@immutable
class GroupLocation {
  final String countryCode;
  final String countryName;
  final String cityId;
  final String cityName;
  final double lat;
  final double lng;

  const GroupLocation({
    required this.countryCode,
    required this.countryName,
    required this.cityId,
    required this.cityName,
    required this.lat,
    required this.lng,
  });

  factory GroupLocation.fromJson(Map<String, dynamic> json) {
    return GroupLocation(
      countryCode: json['countryCode'] as String? ?? '',
      countryName: json['countryName'] as String? ?? '',
      cityId: json['cityId'] as String? ?? '',
      cityName: json['cityName'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'countryCode': countryCode,
        'countryName': countryName,
        'cityId': cityId,
        'cityName': cityName,
        'lat': lat,
        'lng': lng,
      };
}

@immutable
class GroupInvite {
  final String code;
  final DateTime? createdAt;

  const GroupInvite({
    required this.code,
    this.createdAt,
  });

  factory GroupInvite.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        parsedCreatedAt = (json['createdAt'] as Timestamp).toDate();
      } else if (json['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(json['createdAt']);
      }
    }
    return GroupInvite(
      code: json['code'] as String? ?? '',
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      };
}

@immutable
class GroupModel {
  final String groupId;
  final String? groupName;
  final List<String> members;
  final List<String> sharedFavorites;
  final DateTime? createdAt;
  final String? activeSessionId; // To track if a swipe session is ongoing
  final bool hasCompletedSession;

  // New fields from plan
  final String? ownerUid;
  final GroupLocation? location;
  final int? likeThreshold;
  final bool? joinEnabled;
  final GroupInvite? invite;

  const GroupModel({
    required this.groupId,
    this.groupName,
    this.members = const [],
    this.sharedFavorites = const [],
    this.createdAt,
    this.activeSessionId,
    this.hasCompletedSession = false,
    this.ownerUid,
    this.location,
    this.likeThreshold,
    this.joinEnabled,
    this.invite,
  });

  GroupModel copyWith({
    String? groupId,
    String? groupName,
    List<String>? members,
    List<String>? sharedFavorites,
    DateTime? createdAt,
    String? activeSessionId,
    bool? hasCompletedSession,
    String? ownerUid,
    GroupLocation? location,
    int? likeThreshold,
    bool? joinEnabled,
    GroupInvite? invite,
  }) {
    return GroupModel(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      members: members ?? this.members,
      sharedFavorites: sharedFavorites ?? this.sharedFavorites,
      createdAt: createdAt ?? this.createdAt,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      hasCompletedSession: hasCompletedSession ?? this.hasCompletedSession,
      ownerUid: ownerUid ?? this.ownerUid,
      location: location ?? this.location,
      likeThreshold: likeThreshold ?? this.likeThreshold,
      joinEnabled: joinEnabled ?? this.joinEnabled,
      invite: invite ?? this.invite,
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
      hasCompletedSession: json['hasCompletedSession'] as bool? ?? false,
      ownerUid: json['ownerUid'] as String?,
      location: json['location'] != null
          ? GroupLocation.fromJson(Map<String, dynamic>.from(json['location']))
          : null,
      likeThreshold: json['likeThreshold'] as int?,
      joinEnabled: json['joinEnabled'] as bool?,
      invite: json['invite'] != null
          ? GroupInvite.fromJson(Map<String, dynamic>.from(json['invite']))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupName': groupName,
        'members': members,
        'sharedFavorites': sharedFavorites,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'activeSessionId': activeSessionId,
        'hasCompletedSession': hasCompletedSession,
        'ownerUid': ownerUid,
        if (location != null) 'location': location!.toJson(),
        if (likeThreshold != null) 'likeThreshold': likeThreshold,
        if (joinEnabled != null) 'joinEnabled': joinEnabled,
        if (invite != null) 'invite': invite!.toJson(),
      };
}
