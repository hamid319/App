import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
