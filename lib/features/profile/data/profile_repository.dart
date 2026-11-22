import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/firestore_service.dart';
import '../../../common/models/user_model.dart';

class ProfileRepository {
  final FirestoreService _firestoreService;
  const ProfileRepository(this._firestoreService);

  Future<UserModel> getUserProfile(String uid) async {
    try {
      final doc = await _firestoreService.getDocument('users', uid);
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      } else {
        return UserModel(uid: uid, email: '', favorites: [], groups: [], createdAt: DateTime.now());
      }
    } catch (e) {
      debugPrint('Reading profile $uid failed: $e');
      return UserModel(uid: uid, email: '', favorites: [], groups: [], createdAt: DateTime.now());
    }
  }

  Future<void> createUserProfile(UserModel user) async {
    await _firestoreService.setDocument('users', user.uid, user.toJson());
    await syncPublicProfile(user);
  }

  /// Fields other trip members may see. They live in
  /// `publicProfiles/{uid}`; `users/{uid}` (email, favorites, push token)
  /// is readable only by its owner.
  static const publicFields = {'displayName', 'photoUrl'};

  /// Name and photo of another user, for trip screens. The
  /// other fields of the returned model are empty.
  Future<UserModel> getPublicProfile(String uid) async {
    try {
      final doc = await _firestoreService.getDocument('publicProfiles', uid);
      final data = doc.data() ?? const {};
      return UserModel(
        uid: uid,
        email: '',
        displayName: data['displayName'] as String?,
        photoUrl: data['photoUrl'] as String?,
      );
    } catch (e) {
      debugPrint('Reading public profile $uid failed: $e');
      return UserModel(uid: uid, email: '');
    }
  }

  /// Writes the public fields of [user] (also fills the public profile of
  /// accounts made before it existed).
  Future<void> syncPublicProfile(UserModel user) => _mirrorPublic(user.uid, {
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
      });

  /// Copies the public fields in [data], if any, to `publicProfiles/{uid}`.
  Future<void> _mirrorPublic(String uid, Map<String, dynamic> data) async {
    final public = {
      for (final e in data.entries)
        if (publicFields.contains(e.key)) e.key: e.value,
    };
    if (public.isEmpty) return;
    await _firestoreService.setDocument('publicProfiles', uid, {
      ...public,
      'paypalHandle': FieldValue.delete(),
    }, merge: true);
  }

  /// Reads a payment handle through the server's trip membership check.
  Future<String?> getTripPaymentHandle(String groupId, String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null) return null;
    final projectId = Firebase.app().options.projectId;
    final uri = Uri.https('europe-west3-$projectId.cloudfunctions.net',
        '/getTripPaymentHandle');
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'data': {'groupId': groupId, 'uid': uid}});
    final client = http.Client();
    try {
      final response = await client.send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final payload = jsonDecode(response.body);
      return switch (payload) {
        {'result': final String handle} => handle,
        _ => null,
      };
    } finally {
      client.close();
    }
  }

  /// Creates the profile only if it is missing, so a returning guest keeps
  /// the favorites already stored under their UID.
  Future<void> ensureUserProfile(UserModel user) async {
    final doc = await _firestoreService.getDocument('users', user.uid);
    if (doc.exists) return;
    // Merge without the list fields: if two callers race here, the second
    // write cannot reset favorites the first session already added.
    final data = user.toJson()
      ..remove('favorites')
      ..remove('groups');
    await upsertUserProfile(user.uid, data);
  }

  /// Merges [data] into the profile, creating it when missing. `uid` is always
  /// written because the update rule requires `uid == userId`.
  Future<void> upsertUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestoreService.setDocument(
      'users',
      uid,
      {...data, 'uid': uid},
      merge: true,
    );
    await _mirrorPublic(uid, data);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestoreService.updateDocument('users', uid, data);
    await _mirrorPublic(uid, data);
  }

  // Favorites are changed one ID at a time on the server. Writing the whole
  // array from a local copy wiped every favorite whenever that copy was empty
  // because an earlier profile read had failed.
  Future<void> addFavorite(String uid, String placeId) async {
    await _firestoreService.updateDocument('users', uid, {
      'favorites': FieldValue.arrayUnion([placeId]),
    });
  }

  Future<void> removeFavorite(String uid, String placeId) async {
    await _firestoreService.updateDocument('users', uid, {
      'favorites': FieldValue.arrayRemove([placeId]),
    });
  }

  Future<List<String>> getUserFavorites(String uid) async {
    final profile = await getUserProfile(uid);
    return profile.favorites;
  }
}
