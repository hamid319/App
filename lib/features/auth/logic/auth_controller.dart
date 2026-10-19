import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/models/user_model.dart';
import '../../../features/profile/data/profile_repository.dart';
import '../data/auth_repository.dart';
import '../../../main_providers.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, UserModel?>(AuthController.new);

/// State is `null` only when nobody is signed in AND the guest session could
/// not be started (e.g. Anonymous Auth disabled in the Console). The router
/// then falls back to the login screen. A guest is a [UserModel] with
/// `isAnonymous == true`.
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
          final current = state.value;
          if (current != null &&
              current.uid == firebaseUser.uid &&
              current.isAnonymous == firebaseUser.isAnonymous) {
            return;
          }
          state = AsyncData(await _hydrate(firebaseUser));
        } else {
          state = const AsyncData(null);
        }
      });
    });

    final currentUser = _authRepo.firebaseUser;
    if (currentUser != null) {
      return _hydrate(currentUser);
    }

    return _startGuestSession();
  }

  bool get isGuest => state.value?.isAnonymous ?? false;

  Future<UserModel?> _startGuestSession() async {
    try {
      final guest = await _authRepo.signInAsGuest();
      if (guest == null) return null;
      return _hydrate(guest);
    } catch (e) {
      // operation-not-allowed / admin-restricted-operation mean the Anonymous
      // provider is off in the Firebase Console. Returning null sends the
      // user to the login screen, the pre-guest-mode behaviour.
      debugPrint('Guest sign-in unavailable: $e');
      return null;
    }
  }

  Future<UserModel> _hydrate(User firebaseUser) async {
    if (firebaseUser.isAnonymous) {
      try {
        // Rules only allow creating the caller's own /users doc; liking and
        // favoriting use update(), which needs the doc to exist.
        await _profileRepo.ensureUserProfile(UserModel(
          uid: firebaseUser.uid,
          email: '',
          createdAt: DateTime.now(),
        ));
      } catch (e) {
        debugPrint('Could not create guest profile: $e');
      }
    }
    final userModel = await _profileRepo.getUserProfile(firebaseUser.uid);
    return userModel.copyWith(
      email: firebaseUser.email ?? userModel.email,
      displayName: firebaseUser.displayName ?? userModel.displayName,
      isAnonymous: firebaseUser.isAnonymous,
    );
  }

  /// Signs into an existing account. When called as a guest, the guest
  /// session is replaced: its swipes and likes stay with the old anonymous
  /// UID and are not carried over. That is intended; only [signup] merges.
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user = await _authRepo.login(email, password);
      if (user != null) {
        state = AsyncData(await _hydrate(user));
      } else {
        state = const AsyncData(null);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Creates an account. A guest is upgraded in place via linkWithCredential
  /// so UID, swipe history and favorites are kept.
  Future<void> signup(String email, String password, {String? displayName}) async {
    state = const AsyncLoading();
    try {
      final current = _authRepo.firebaseUser;
      final isUpgrade = current != null && current.isAnonymous;
      final user = isUpgrade
          ? await _authRepo.upgradeGuest(email, password)
          : await _authRepo.signup(email, password);
      if (user == null) {
        state = const AsyncData(null);
        return;
      }

      if (displayName != null && displayName.isNotEmpty) {
        try {
          await _authRepo.updateDisplayName(displayName);
        } catch (e) {
          debugPrint('Could not set display name: $e');
        }
      }

      if (isUpgrade) {
        // Merge so the guest's favorites and groups survive the upgrade.
        await _profileRepo.upsertUserProfile(user.uid, {
          'email': user.email ?? email,
          'displayName': displayName ?? user.displayName,
        });
        final profile = await _profileRepo.getUserProfile(user.uid);
        state = AsyncData(profile.copyWith(
          email: user.email ?? email,
          displayName: displayName ?? user.displayName,
          isAnonymous: false,
        ));
        return;
      }

      final newUserModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: displayName ?? user.displayName,
        favorites: [],
        groups: [],
        createdAt: DateTime.now(),
      );
      await _profileRepo.createUserProfile(newUserModel);
      state = AsyncData(newUserModel);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Signs out and drops straight back into a fresh guest session.
  Future<void> logout() async {
    await _authRepo.logout();
    state = const AsyncData(null);
    final guest = await _startGuestSession();
    state = AsyncData(guest);
  }
}
