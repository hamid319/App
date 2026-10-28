import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

import 'trip_plan.dart';

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

  // New fields from plan
  final String? ownerUid;
  final GroupLocation? location;
  final GroupInvite? invite;

  /// Travel dates, e.g. taken from a calendar event (both days inclusive).
  final DateTime? tripStart;
  final DateTime? tripEnd;

  /// Day plan built from the trip's wishlist, null until someone builds it.
  final TripPlan? tripPlan;

  const GroupModel({
    required this.groupId,
    this.groupName,
    this.members = const [],
    this.sharedFavorites = const [],
    this.createdAt,
    this.ownerUid,
    this.location,
    this.invite,
    this.tripStart,
    this.tripEnd,
    this.tripPlan,
  });

  GroupModel copyWith({
    String? groupId,
    String? groupName,
    List<String>? members,
    List<String>? sharedFavorites,
    DateTime? createdAt,
    String? ownerUid,
    GroupLocation? location,
    GroupInvite? invite,
    DateTime? tripStart,
    DateTime? tripEnd,
    TripPlan? tripPlan,
  }) {
    return GroupModel(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      members: members ?? this.members,
      sharedFavorites: sharedFavorites ?? this.sharedFavorites,
      createdAt: createdAt ?? this.createdAt,
      ownerUid: ownerUid ?? this.ownerUid,
      location: location ?? this.location,
      invite: invite ?? this.invite,
      tripStart: tripStart ?? this.tripStart,
      tripEnd: tripEnd ?? this.tripEnd,
      tripPlan: tripPlan ?? this.tripPlan,
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
      ownerUid: json['ownerUid'] as String?,
      location: json['location'] != null
          ? GroupLocation.fromJson(Map<String, dynamic>.from(json['location']))
          : null,
      invite: json['invite'] != null
          ? GroupInvite.fromJson(Map<String, dynamic>.from(json['invite']))
          : null,
      tripStart: _date(json['tripStart']),
      tripEnd: _date(json['tripEnd']),
      tripPlan: json['tripPlan'] is Map
          ? TripPlan.fromJson(Map<String, dynamic>.from(json['tripPlan']))
          : null,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupName': groupName,
        'members': members,
        'sharedFavorites': sharedFavorites,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'ownerUid': ownerUid,
        if (location != null) 'location': location!.toJson(),
        if (invite != null) 'invite': invite!.toJson(),
        if (tripStart != null) 'tripStart': Timestamp.fromDate(tripStart!),
        if (tripEnd != null) 'tripEnd': Timestamp.fromDate(tripEnd!),
      };
}
