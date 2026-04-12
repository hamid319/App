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
        return UserModel(uid: uid, email: '', favorites: [], groups: []);
      }
    } catch (e) {
      return UserModel(uid: uid, email: '', favorites: [], groups: []);
    }
  }

  Future<void> createUserProfile(UserModel user) async {
    await _firestoreService.setDocument('users', user.uid, user.toJson());
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestoreService.updateDocument('users', uid, data);
  }

  Future<List<String>> getUserFavorites(String uid) async {
    final profile = await getUserProfile(uid);
    return profile.favorites;
  }
}
