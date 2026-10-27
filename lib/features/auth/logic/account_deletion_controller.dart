import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main_providers.dart';
import '../data/account_deletion_repository.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

final accountDeletionRepositoryProvider =
    Provider<AccountDeletionRepository>((ref) => AccountDeletionRepository());

final accountDeletionControllerProvider =
    AsyncNotifierProvider<AccountDeletionController, void>(
        AccountDeletionController.new);

enum AccountDeletionOutcome {
  deleted,

  /// Firebase wants a recent sign-in: ask for the password and call
  /// [AccountDeletionController.deleteAccount] again with it.
  needsPassword,
}

/// Deletes the signed-in account (App Store guideline 5.1.1(v)): the user's
/// data via [AccountDeletionRepository], then the Firebase Auth user, then
/// starts a fresh guest session like a logout.
class AccountDeletionController extends AsyncNotifier<void> {
  /// Firebase rejects deleting an account whose last sign-in is older than
  /// about five minutes. Checked up front so the data is not deleted while
  /// the Auth user stays.
  static const recentSignIn = Duration(minutes: 5);

  @override
  Future<void> build() async {}

  AuthRepository get _auth => AuthRepository(ref.read(authServiceProvider));

  /// Throws when the deletion fails; the error is also kept in [state].
  Future<AccountDeletionOutcome> deleteAccount({String? password}) async {
    state = const AsyncLoading();
    try {
      final outcome = await _delete(password);
      state = const AsyncData(null);
      return outcome;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<AccountDeletionOutcome> _delete(String? password) async {
    final user = _auth.firebaseUser;
    if (user == null) throw StateError('Not authenticated');
    final usesPassword =
        !user.isAnonymous && (user.email?.isNotEmpty ?? false);

    if (usesPassword) {
      if (password != null) {
        await _reauthenticate(password);
      } else if (!_signedInRecently(user)) {
        return AccountDeletionOutcome.needsPassword;
      }
    }

    await ref.read(accountDeletionRepositoryProvider).deleteUserData(user.uid);

    try {
      await _auth.deleteCurrentUser();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      // The data is gone already; after the password the cleanup runs again
      // (it is idempotent) and the Auth user is deleted.
      if (usesPassword) return AccountDeletionOutcome.needsPassword;
      // A guest cannot sign in again. Its data is deleted, so only the
      // empty anonymous Auth user remains; signing out abandons it.
    }

    await ref.read(authControllerProvider.notifier).logout();
    return AccountDeletionOutcome.deleted;
  }

  bool _signedInRecently(User user) {
    final last = user.metadata.lastSignInTime;
    return last != null && DateTime.now().difference(last) < recentSignIn;
  }

  Future<void> _reauthenticate(String password) async {
    try {
      await _auth.reauthenticate(password);
    } on FirebaseAuthException catch (e) {
      const wrongPassword = {
        'wrong-password',
        'invalid-credential',
        'invalid-login-credentials',
        'INVALID_LOGIN_CREDENTIALS',
      };
      if (wrongPassword.contains(e.code)) throw Exception('Wrong password');
      rethrow;
    }
  }
}
