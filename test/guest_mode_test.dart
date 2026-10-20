import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/app/routes.dart';
import 'package:swipetrip/core/services/auth_service.dart';
import 'package:swipetrip/core/services/firestore_service.dart';
import 'package:swipetrip/features/auth/logic/auth_controller.dart';
import 'package:swipetrip/features/profile/data/profile_repository.dart';
import 'package:swipetrip/main_providers.dart';

class _FakeUser implements User {
  _FakeUser({required this.uid, required this.isAnonymous, this.email});

  @override
  final String uid;
  @override
  final bool isAnonymous;
  @override
  final String? email;
  @override
  String? get displayName => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.anonymousError});

  final FirebaseAuthException? anonymousError;
  final _changes = StreamController<User?>.broadcast();
  User? _user;
  int linkCalls = 0;
  int registerCalls = 0;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  @override
  Future<User?> signInAnonymously() async {
    if (anonymousError != null) throw anonymousError!;
    _user = _FakeUser(uid: 'guest-uid', isAnonymous: true);
    return _user;
  }

  @override
  Future<User?> linkGuestWithEmail(String email, String password) async {
    linkCalls++;
    _user = _FakeUser(uid: _user!.uid, isAnonymous: false, email: email);
    return _user;
  }

  @override
  Future<User?> registerWithEmail(String email, String password) async {
    registerCalls++;
    _user = _FakeUser(uid: 'new-uid', isAnonymous: false, email: email);
    return _user;
  }

  @override
  Future<User?> signInWithEmail(String email, String password) async {
    _user = _FakeUser(uid: 'existing-uid', isAnonymous: false, email: email);
    return _user;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  Future<void> sendPasswordResetEmail(String email, {String? languageCode}) async {}

  @override
  Future<void> signOut() async => _user = null;
}

/// Routes the profile repository's calls to an in-memory Firestore so the
/// real merge/arrayUnion semantics are exercised.
class _FakeFirestoreService implements FirestoreService {
  _FakeFirestoreService(this.db);
  final FakeFirebaseFirestore db;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
          String collection, String docId) =>
      db.collection(collection).doc(docId).get();

  @override
  Future<void> setDocument(
          String collection, String docId, Map<String, dynamic> data,
          {bool merge = false}) =>
      db.collection(collection).doc(docId).set(data, SetOptions(merge: merge));

  @override
  Future<void> updateDocument(
          String collection, String docId, Map<String, dynamic> data) =>
      db.collection(collection).doc(docId).update(data);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('resolveAuthRedirect', () {
    String? redirect(String path,
            {bool session = true, bool account = false}) =>
        resolveAuthRedirect(
          path: path,
          hasSeenOnboarding: true,
          hasSession: session,
          hasAccount: account,
        );

    test('guests swipe without being sent to login', () {
      expect(redirect('/'), '/home');
      expect(redirect('/home'), isNull);
      expect(redirect('/place/abc'), isNull);
    });

    test('guests may open login and register to upgrade', () {
      expect(redirect('/login'), isNull);
      expect(redirect('/register'), isNull);
    });

    test('real accounts are sent away from the auth screens', () {
      expect(redirect('/login', account: true), '/home');
      expect(redirect('/register', account: true), '/home');
      expect(redirect('/profile', account: true), isNull);
    });

    test('without any session (guest sign-in failed) login is required', () {
      expect(redirect('/home', session: false), '/login');
      expect(redirect('/favorites', session: false), '/login');
      expect(redirect('/login', session: false), isNull);
      expect(redirect('/register', session: false), isNull);
    });

    test('nothing happens before onboarding was seen', () {
      expect(
        resolveAuthRedirect(
          path: '/home',
          hasSeenOnboarding: false,
          hasSession: false,
          hasAccount: false,
        ),
        isNull,
      );
    });
  });

  group('AuthController guest mode', () {
    late FakeFirebaseFirestore db;

    ProviderContainer makeContainer(_FakeAuthService auth) {
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(
          ProfileRepository(_FakeFirestoreService(db)),
        ),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() => db = FakeFirebaseFirestore());

    test('signs in anonymously and creates the guest profile', () async {
      final container = makeContainer(_FakeAuthService());

      final user = await container.read(authControllerProvider.future);

      expect(user, isNotNull);
      expect(user!.isAnonymous, isTrue);
      final doc = await db.collection('users').doc('guest-uid').get();
      expect(doc.exists, isTrue);
      // The update rule requires uid == userId.
      expect(doc.data()!['uid'], 'guest-uid');
    });

    test('falls back to no session when Anonymous Auth is disabled', () async {
      final container = makeContainer(_FakeAuthService(
        anonymousError: FirebaseAuthException(code: 'operation-not-allowed'),
      ));

      expect(await container.read(authControllerProvider.future), isNull);
    });

    test('sign-up as guest links the account and keeps UID and favorites',
        () async {
      final auth = _FakeAuthService();
      final container = makeContainer(auth);
      await container.read(authControllerProvider.future);
      await db.collection('users').doc('guest-uid').update({
        'favorites': FieldValue.arrayUnion(['place-1']),
      });

      await container
          .read(authControllerProvider.notifier)
          .signup('a@b.com', 'secret1', displayName: 'Alex');

      final user = container.read(authControllerProvider).value!;
      expect(auth.linkCalls, 1);
      expect(auth.registerCalls, 0);
      expect(user.uid, 'guest-uid');
      expect(user.isAnonymous, isFalse);
      expect(user.favorites, ['place-1']);
      final data = (await db.collection('users').doc('guest-uid').get()).data()!;
      expect(data['email'], 'a@b.com');
      expect(data['displayName'], 'Alex');
      expect(data['favorites'], ['place-1']);
    });

    test('logging in as guest switches to the existing account', () async {
      final container = makeContainer(_FakeAuthService());
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login('old@b.com', 'secret1');

      final user = container.read(authControllerProvider).value!;
      expect(user.uid, 'existing-uid');
      expect(user.isAnonymous, isFalse);
    });

    test('merging profile fields never wipes favorites',
        () async {
      final repo = ProfileRepository(_FakeFirestoreService(db));
      await db.collection('users').doc('guest-uid').set({
        'uid': 'guest-uid',
        'email': '',
        'favorites': ['place-1'],
        'groups': <String>[],
      });

      await repo.upsertUserProfile('guest-uid', {'email': ''});

      final data = (await db.collection('users').doc('guest-uid').get()).data()!;
      expect(data['favorites'], ['place-1']);
    });
  });
}
