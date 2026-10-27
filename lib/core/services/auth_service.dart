import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // A getter, so tests can subclass AuthService without a Firebase app.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  Future<User?> registerWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  /// Invisible guest account. Requires the "Anonymous" sign-in provider to be
  /// enabled in the Firebase Console.
  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  /// Turns the signed-in guest into a real email account. The UID stays the
  /// same, so everything the guest saved stays attached to it.
  Future<User?> linkGuestWithEmail(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No guest session to upgrade.');
    }
    final cred = await user.linkWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    return cred.user;
  }

  /// Sends Firebase's password reset email. [languageCode] sets the language
  /// of the email (e.g. "de"); the link opens Firebase's reset page.
  Future<void> sendPasswordResetEmail(
    String email, {
    String? languageCode,
  }) async {
    if (languageCode != null) await _auth.setLanguageCode(languageCode);
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  /// Confirms the signed-in email account's password again. Firebase asks
  /// for this before deleting an account whose last sign-in is not recent.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw StateError('Not authenticated');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// Deletes the signed-in Firebase Auth user (and with it the session).
  /// Throws `requires-recent-login` when the last sign-in is too old.
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    await user.delete();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
