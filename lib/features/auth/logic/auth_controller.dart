import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/user_model.dart';
import '../../../features/profile/data/profile_repository.dart';
import '../data/auth_repository.dart';
import '../../../main_providers.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, UserModel?>(AuthController.new);

class AuthController extends AsyncNotifier<UserModel?> {
  late final AuthRepository _authRepo;
  late final ProfileRepository _profileRepo;
  StreamSubscription<User?>? _authSubscription;

  @override
  Future<UserModel?> build() async {
    _authRepo = AuthRepository(ref.read(authServiceProvider));
    _profileRepo = ref.read(profileRepositoryProvider);

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    _authSubscription = _authRepo.authStateChanges().listen((firebaseUser) async {
      // Delay state update to avoid modifying provider during widget build
      Future.microtask(() async {
        if (firebaseUser != null) {
          final userModel = await _profileRepo.getUserProfile(firebaseUser.uid);
          final hydratedUser = userModel.copyWith(
            email: firebaseUser.email ?? userModel.email,
            displayName: firebaseUser.displayName ?? userModel.displayName,
          );
          state = AsyncData(hydratedUser);
        } else {
          state = const AsyncData(null);
        }
      });
    });

    final currentUser = _authRepo.firebaseUser;
    if (currentUser != null) {
      final userModel = await _profileRepo.getUserProfile(currentUser.uid);
      return userModel.copyWith(
        email: currentUser.email ?? userModel.email,
        displayName: currentUser.displayName ?? userModel.displayName,
      );
    }

    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user = await _authRepo.login(email, password);
      if (user != null) {
        final userModel = await _profileRepo.getUserProfile(user.uid);
        final hydratedUser = userModel.copyWith(
          email: user.email ?? userModel.email,
          displayName: user.displayName ?? userModel.displayName,
        );
        state = AsyncData(hydratedUser);
      } else {
        state = const AsyncData(null);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signup(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user = await _authRepo.signup(email, password);
      if (user != null) {
        final newUserModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          favorites: [],
          groups: [],
        );
        await _profileRepo.createUserProfile(newUserModel);
        state = AsyncData(newUserModel);
      } else {
        state = const AsyncData(null);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> logout() async {
    await _authRepo.logout();
    state = const AsyncData(null);
  }
}
