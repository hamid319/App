import '../../../core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final AuthService _authService;
  const AuthRepository(this._authService);

  User? get firebaseUser => _authService.currentUser;
  Stream<User?> authStateChanges() => _authService.authStateChanges();

  Future<User?> login(String email, String password) => _authService.signInWithEmail(email, password);

  Future<User?> signup(String email, String password) => _authService.registerWithEmail(email, password);

  Future<User?> signInAsGuest() => _authService.signInAnonymously();

  Future<User?> upgradeGuest(String email, String password) =>
      _authService.linkGuestWithEmail(email, password);

  Future<void> sendPasswordReset(String email, {String? languageCode}) =>
      _authService.sendPasswordResetEmail(email, languageCode: languageCode);

  Future<void> updateDisplayName(String displayName) =>
      _authService.updateDisplayName(displayName);

  Future<void> logout() => _authService.signOut();

  Future<void> reauthenticate(String password) =>
      _authService.reauthenticateWithPassword(password);

  Future<void> deleteCurrentUser() => _authService.deleteCurrentUser();
}
