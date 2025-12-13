import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../common/models/user_model.dart';
import '../data/auth_repository.dart';
import '../../../main_providers.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, UserModel?>(AuthController.new);

class AuthController extends AsyncNotifier<UserModel?> {
  late final AuthRepository _repo;

  @override
  Future<UserModel?> build() async {
    _repo = AuthRepository(ref.read(authServiceProvider));
    // Listen to auth changes, could implement logic, but return null for startup
    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      debugPrint('🔐 AuthController: Starte Login für $email');
      final user = await _repo.login(email, password);
      if (user != null) {
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
        );
        debugPrint('✅ AuthController: Login erfolgreich, User: ${userModel.email}');
        state = AsyncData(userModel);
      } else {
        debugPrint('⚠️ AuthController: Login zurückgegeben, aber user ist null');
        state = const AsyncData(null);
      }
    } catch (e, st) {
      debugPrint('❌ AuthController: Login Fehler: $e');
      debugPrint('Stack Trace: $st');
      state = AsyncError(e, st);
    }
  }

  Future<void> signup(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user = await _repo.signup(email, password);
      state = AsyncData(user == null ? null : UserModel(uid: user.uid, email: user.email ?? '', displayName: user.displayName));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}
