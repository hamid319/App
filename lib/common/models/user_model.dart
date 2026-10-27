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

  /// Optional paypal.me name, so trip members can pay back via a link.
  final String? paypalHandle;

  /// True for the invisible guest account (Firebase Anonymous Auth). Comes
  /// from the auth session, so it is never stored in Firestore.
  final bool isAnonymous;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.favorites = const [],
    this.groups = const [],
    this.createdAt,
    this.fcmToken,
    this.paypalHandle,
    this.isAnonymous = false,
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
    String? paypalHandle,
    bool? isAnonymous,
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
      paypalHandle: paypalHandle ?? this.paypalHandle,
      isAnonymous: isAnonymous ?? this.isAnonymous,
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
      paypalHandle: json['paypalHandle'] as String?,
    );
  }

  /// Copy with [handle] as PayPal name; null or blank removes it.
  UserModel withPaypalHandle(String? handle) {
    final value = handle?.trim();
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      favorites: favorites,
      groups: groups,
      createdAt: createdAt,
      fcmToken: fcmToken,
      paypalHandle: value == null || value.isEmpty ? null : value,
      isAnonymous: isAnonymous,
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
        if (paypalHandle != null) 'paypalHandle': paypalHandle,
      };
}
