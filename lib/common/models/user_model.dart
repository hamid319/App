import 'package:meta/meta.dart';

@immutable
class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final List<String> favorites;
  final List<String> groups;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.favorites = const [],
    this.groups = const [],
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    List<String>? favorites,
    List<String>? groups,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      favorites: favorites ?? this.favorites,
      groups: groups ?? this.groups,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
        favorites: List<String>.from(json['favorites'] ?? []),
        groups: List<String>.from(json['groups'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'favorites': favorites,
        'groups': groups,
      };
}
