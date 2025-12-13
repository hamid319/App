import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/user_model.dart';
import '../data/profile_repository.dart';
import '../../../main_providers.dart';

final profileControllerProvider = AsyncNotifierProvider<ProfileController, UserModel?>(ProfileController.new);

class ProfileController extends AsyncNotifier<UserModel?> {
  late final ProfileRepository _repo;

  @override
  Future<UserModel?> build() async {
    _repo = ProfileRepository(ref.read(firestoreServiceProvider));
    return null;
  }

  Future<void> loadProfile(String uid) async {
    state = const AsyncLoading();
    try {
      final user = await _repo.getUserProfile(uid);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    if (state.value == null) return;
    state = const AsyncLoading();
    try {
      await _repo.updateUserProfile(uid, data);
      final updated = state.value!.copyWith(
        email: data['email'] ?? state.value!.email,
        displayName: data['displayName'] ?? state.value!.displayName,
        photoUrl: data['photoUrl'] ?? state.value!.photoUrl,
        favorites: data['favorites'] ?? state.value!.favorites,
      );
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
