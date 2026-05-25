import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../common/models/user_model.dart';
import '../data/profile_repository.dart';
import '../data/image_service.dart';
import '../../../main_providers.dart';

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, UserModel?>(ProfileController.new);

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

class ProfileController extends AsyncNotifier<UserModel?> {
  ProfileRepository get _repo =>
      ProfileRepository(ref.read(firestoreServiceProvider));
  
  ImageService get _imageService => ref.read(imageServiceProvider);

  @override
  Future<UserModel?> build() async {
    return null;
  }

  Future<void> loadProfile(String uid) async {
    if (state.value?.uid == uid) return;
    state = const AsyncLoading();
    try {
      final user = await _repo.getUserProfile(uid);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
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

  Future<String?> pickAndUploadProfileImage(String uid, ImageSource source) async {
    try {
      final XFile? imageFile;
      if (source == ImageSource.gallery) {
        imageFile = await _imageService.pickImageFromGallery();
      } else {
        imageFile = await _imageService.pickImageFromCamera();
      }

      if (imageFile == null) return null;

      final String imageUrl = await _imageService.uploadProfileImage(uid, imageFile);
      
      await updateProfile(uid, {'photoUrl': imageUrl});
      
      return imageUrl;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeProfileImage(String uid) async {
    final currentUser = state.value;
    if (currentUser == null || currentUser.photoUrl == null) return;

    try {
      await _imageService.deleteProfileImage(currentUser.photoUrl!);
      await updateProfile(uid, {'photoUrl': null});
    } catch (e) {
      rethrow;
    }
  }
}
