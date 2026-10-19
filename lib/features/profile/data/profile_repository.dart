import 'package:cloud_firestore/cloud_firestore.dart';
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
      return UserModel(uid: uid, email: '', favorites: [], groups: [], createdAt: DateTime.now());
    }
  }

  Future<void> createUserProfile(UserModel user) async {
    await _firestoreService.setDocument('users', user.uid, user.toJson());
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
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestoreService.updateDocument('users', uid, data);
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
