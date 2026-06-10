import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/user_model.dart';
import '../data/profile_repository.dart';
import '../../../main_providers.dart';
import '../../auth/logic/auth_controller.dart';
final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, UserModel?>(ProfileController.new);

class ProfileController extends AsyncNotifier<UserModel?> {
  ProfileRepository get _repo =>
      ProfileRepository(ref.read(firestoreServiceProvider));

  @override
  Future<UserModel?> build() async {
    final userAsync = ref.watch(authControllerProvider);
    final user = userAsync.value;
    if (user != null) {
      return _repo.getUserProfile(user.uid);
    }
    return null;
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    final previousState = state.value;
    state = const AsyncLoading();
    try {
      await _repo.updateUserProfile(uid, data);

      final currentUser = previousState ?? await _repo.getUserProfile(uid);
      final updated = currentUser.copyWith(
        email: data['email'] as String? ?? currentUser.email,
        displayName: data['displayName'] as String? ?? currentUser.displayName,
        photoUrl: data['photoUrl'] as String? ?? currentUser.photoUrl,
        favorites: data['favorites'] != null
            ? List<String>.from(data['favorites'])
            : currentUser.favorites,
        groups: data['groups'] != null
            ? List<String>.from(data['groups'])
            : currentUser.groups,
      );
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addFavorite(String uid, String placeId) async {
    final currentUser = state.value;
    if (currentUser == null) return;

    final newFavorites = List<String>.from(currentUser.favorites);
    if (!newFavorites.contains(placeId)) {
      newFavorites.add(placeId);
      await updateProfile(uid, {'favorites': newFavorites});
    }
  }

  Future<void> removeFavorite(String uid, String placeId) async {
    final currentUser = state.value;
    if (currentUser == null) return;

    final newFavorites = List<String>.from(currentUser.favorites)
      ..remove(placeId);
    await updateProfile(uid, {'favorites': newFavorites});
  }
}
