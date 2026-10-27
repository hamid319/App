import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main_providers.dart';
import '../data/auth_repository.dart';

final passwordResetControllerProvider =
    AsyncNotifierProvider.autoDispose<PasswordResetController, String?>(
  PasswordResetController.new,
);

/// Sends the password reset email. State is null until a link was sent,
/// then the address it went to.
class PasswordResetController extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<void> send(String email, {String? languageCode}) async {
    final address = email.trim();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await AuthRepository(ref.read(authServiceProvider))
            .sendPasswordReset(address, languageCode: languageCode);
      } on FirebaseAuthException catch (e) {
        // Same answer whether or not an account exists, so the form cannot
        // be used to find out which addresses are registered.
        if (e.code != 'user-not-found') rethrow;
      }
      return address;
    });
  }

  /// Back to the form, e.g. to correct a typo in the address.
  void editAddress() => state = const AsyncData(null);
}
