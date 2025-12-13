import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      debugPrint('🔐 Versuche Login mit Email: $email');
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Login erfolgreich: ${cred.user?.email}');
      return cred.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Fehler: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Unerwarteter Fehler beim Login: $e');
      rethrow;
    }
  }

  Future<User?> registerWithEmail(String email, String password) async {
    try {
      debugPrint('📝 Versuche Registrierung mit Email: $email');
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Registrierung erfolgreich: ${cred.user?.email}');
      return cred.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Fehler: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Unerwarteter Fehler bei Registrierung: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
