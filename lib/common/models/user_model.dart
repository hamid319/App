import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

@immutable
class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final List<String> favorites;
  final List<String> groups;
  final DateTime? createdAt;
  final String? fcmToken;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.favorites = const [],
    this.groups = const [],
    this.createdAt,
    this.fcmToken,
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    List<String>? favorites,
    List<String>? groups,
    DateTime? createdAt,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      favorites: favorites ?? this.favorites,
      groups: groups ?? this.groups,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        parsedCreatedAt = (json['createdAt'] as Timestamp).toDate();
      } else if (json['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(json['createdAt']);
      }
    }

    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      favorites: List<String>.from(json['favorites'] ?? []),
      groups: List<String>.from(json['groups'] ?? []),
      createdAt: parsedCreatedAt,
      fcmToken: json['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'favorites': favorites,
        'groups': groups,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'fcmToken': fcmToken,
      };
}
