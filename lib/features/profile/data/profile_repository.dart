import '../../../core/services/firestore_service.dart';
import '../../../common/models/user_model.dart';

class ProfileRepository {
  final FirestoreService _firestoreService;
  const ProfileRepository(this._firestoreService);

  Future<UserModel> getUserProfile(String uid) async {
    final doc = await _firestoreService.getDocument('users', uid);
    return UserModel.fromJson(doc.data()!);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestoreService.updateDocument('users', uid, data);
  }
}
