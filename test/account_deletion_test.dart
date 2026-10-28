import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/common/models/user_model.dart';
import 'package:swipetrip/core/services/auth_service.dart';
import 'package:swipetrip/features/auth/data/account_deletion_repository.dart';
import 'package:swipetrip/features/auth/logic/account_deletion_controller.dart';
import 'package:swipetrip/features/auth/logic/auth_controller.dart';
import 'package:swipetrip/main_providers.dart';

const me = 'me';

void main() {
  late FakeFirebaseFirestore db;
  late AccountDeletionRepository repo;
  late _MockStorage storage;
  late List<String> deletedFiles;

  setUp(() {
    db = FakeFirebaseFirestore();
    storage = _MockStorage();
    deletedFiles = [];
    when(() => storage.ref(any())).thenAnswer((call) {
      final path = call.positionalArguments.first as String;
      final ref = _MockReference();
      when(ref.delete).thenAnswer((_) async => deletedFiles.add(path));
      return ref;
    });
    repo = AccountDeletionRepository(firestore: db, storage: storage);
  });

  Future<void> journal(String groupId, String id, String author) =>
      db.collection('groups/$groupId/journal').doc(id).set({
        'authorUid': author,
        'day': '2026-10-30',
        'text': '',
        'photos': [
          {'path': 'trips/$groupId/journal/$id/0.jpg', 'url': 'u'},
        ],
      });

  Future<void> seedGroup(
    String id, {
    required List<String> members,
    required String owner,
    String? code,
  }) async {
    await db.collection('groups').doc(id).set({
      'groupId': id,
      'members': members,
      'ownerUid': owner,
      if (code != null) 'invite': {'code': code},
    });
    if (code != null) {
      await db.collection('inviteCodes').doc(code).set({
        'groupId': id,
        'title': 'Trip',
        'ownerName': 'Owner',
      });
    }
  }

  Future<Map<String, dynamic>?> groupDoc(String id) async =>
      (await db.collection('groups').doc(id).get()).data();

  Future<int> count(String path) async =>
      (await db.collection(path).get()).docs.length;

  group('leaveAllTrips', () {
    test('an owner with other members hands the trip to members[0]',
        () async {
      await seedGroup('g1',
          members: [me, 'early', 'late'], owner: me, code: 'ABC123');
      await db.collection('groups/g1/expenses').doc('e1').set({
        'title': 'Dinner',
        'paidBy': me,
        'participants': [me, 'early'],
      });

      await repo.leaveAllTrips(me);

      final data = await groupDoc('g1');
      expect(data!['members'], ['early', 'late']);
      expect(data['ownerUid'], 'early');
      // Expenses stay so the others' balances are still right.
      expect(await count('groups/g1/expenses'), 1);
      // The invite stays usable, without the leaving owner's name.
      final invite = (await db.collection('inviteCodes').doc('ABC123').get())
          .data();
      expect(invite!['groupId'], 'g1');
      expect(invite.containsKey('ownerName'), isFalse);
    });

    test('the owner alone in a trip deletes it with its contents', () async {
      await seedGroup('solo', members: [me], owner: me, code: 'SOLO11');
      await seedGroup('other', members: ['x'], owner: 'x', code: 'OTHER1');
      final solo = db.collection('groups').doc('solo');
      await solo.collection('ideas').doc('i1').set({'addedBy': 'gone'});
      await solo.collection('polls').doc('p1').set({'createdBy': me});
      await solo.collection('expenses').doc('e1').set({'createdBy': 'gone'});
      final session = solo.collection('sessions').doc('s1');
      await session.set({'status': 'completed'});
      await session.collection('votes').doc('place-1').set({
        'likedBy': [me],
      });
      await session.collection('userSwipes').doc(me).set({
        'swipedPlaceIds': ['place-1'],
      });

      await repo.leaveAllTrips(me);

      expect(await groupDoc('solo'), isNull);
      for (final name in ['ideas', 'polls', 'expenses', 'sessions']) {
        expect(await count('groups/solo/$name'), 0, reason: name);
      }
      expect(await count('groups/solo/sessions/s1/votes'), 0);
      expect(await count('groups/solo/sessions/s1/userSwipes'), 0);
      expect((await db.collection('inviteCodes').doc('SOLO11').get()).exists,
          isFalse);
      // Trips the user is not in are untouched.
      expect(await groupDoc('other'), isNotNull);
      expect((await db.collection('inviteCodes').doc('OTHER1').get()).exists,
          isTrue);
    });

    test('leaving a shared trip deletes only my journal entries and photos',
        () async {
      await seedGroup('g3', members: ['owner', me], owner: 'owner');
      await journal('g3', 'mine', me);
      await journal('g3', 'theirs', 'owner');

      await repo.leaveAllTrips(me);

      final left = await db.collection('groups/g3/journal').get();
      expect(left.docs.map((d) => d.id), ['theirs']);
      expect(deletedFiles, ['trips/g3/journal/mine/0.jpg']);
      expect((await groupDoc('g3'))!['members'], ['owner']);
    });

    test('deleting a solo trip deletes all its journal photos', () async {
      await seedGroup('solo', members: [me], owner: me);
      await journal('solo', 'mine', me);
      await journal('solo', 'leftBehind', 'gone');

      await repo.leaveAllTrips(me);

      expect(await count('groups/solo/journal'), 0);
      expect(deletedFiles, unorderedEquals([
        'trips/solo/journal/mine/0.jpg',
        'trips/solo/journal/leftBehind/0.jpg',
      ]));
      expect(await groupDoc('solo'), isNull);
    });

    test('a plain member just leaves', () async {
      await seedGroup('g2',
          members: ['owner', me, 'friend'], owner: 'owner', code: 'MEMBER');
      await db.collection('groups/g2/ideas').doc('i1').set({'addedBy': me});

      await repo.leaveAllTrips(me);

      final data = await groupDoc('g2');
      expect(data!['members'], ['owner', 'friend']);
      expect(data['ownerUid'], 'owner');
      expect(await count('groups/g2/ideas'), 1);
      final invite =
          (await db.collection('inviteCodes').doc('MEMBER').get()).data();
      expect(invite!['ownerName'], 'Owner');
    });

    test('running twice is harmless', () async {
      await seedGroup('g1', members: [me, 'early'], owner: me);
      await repo.leaveAllTrips(me);
      await repo.leaveAllTrips(me);
      expect((await groupDoc('g1'))!['members'], ['early']);
    });
  });

  test('deletes only the user\'s reviews, solo swipes and profile', () async {
    Future<void> review(String placeId, String uid) => db
        .collection('places/$placeId/reviews')
        .doc(uid)
        .set({'uid': uid, 'placeId': placeId, 'rating': 5});
    await review('p1', me);
    await review('p2', me);
    await review('p1', 'someone');
    await db.collection('swipeResults').doc('${me}_p1').set({'userId': me});
    await db
        .collection('swipeResults')
        .doc('someone_p1')
        .set({'userId': 'someone'});
    await db.collection('users').doc(me).set({'uid': me});
    await db.collection('users').doc('someone').set({'uid': 'someone'});

    await repo.deleteReviews(me);
    await repo.deleteSoloSwipes(me);
    await repo.deleteUserDocument(me);

    expect(await count('places/p1/reviews'), 1);
    expect(await count('places/p2/reviews'), 0);
    expect(await count('swipeResults'), 1);
    expect((await db.collection('users').doc(me).get()).exists, isFalse);
    expect((await db.collection('users').doc('someone').get()).exists, isTrue);
  });

  group('AccountDeletionController', () {
    late _FakeAuthService auth;
    late _RecordingRepository deletion;
    late _FakeAuthController authController;
    late ProviderContainer container;

    void setUpWith({required DateTime lastSignIn, bool anonymous = false}) {
      auth = _FakeAuthService(_user(lastSignIn: lastSignIn, anonymous: anonymous));
      deletion = _RecordingRepository();
      authController = _FakeAuthController();
      container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(auth),
        accountDeletionRepositoryProvider.overrideWithValue(deletion),
        authControllerProvider.overrideWith(() => authController),
      ]);
      addTearDown(container.dispose);
    }

    AccountDeletionController controller() =>
        container.read(accountDeletionControllerProvider.notifier);

    test('asks for the password before deleting anything after an old login',
        () async {
      setUpWith(lastSignIn: DateTime.now().subtract(const Duration(days: 3)));

      final outcome = await controller().deleteAccount();

      expect(outcome, AccountDeletionOutcome.needsPassword);
      expect(deletion.calls, isEmpty);
      expect(auth.deleted, isFalse);
    });

    test('with the password: re-login, data, Auth user, then logout',
        () async {
      setUpWith(lastSignIn: DateTime.now().subtract(const Duration(days: 3)));

      final outcome = await controller().deleteAccount(password: 'secret');

      expect(outcome, AccountDeletionOutcome.deleted);
      expect(auth.reauthPasswords, ['secret']);
      expect(deletion.calls, [me]);
      expect(auth.deleted, isTrue);
      expect(authController.logouts, 1);
    });

    test('a wrong password is reported and nothing is deleted', () async {
      setUpWith(lastSignIn: DateTime.now().subtract(const Duration(days: 3)));
      auth.reauthError = FirebaseAuthException(code: 'invalid-credential');

      await expectLater(controller().deleteAccount(password: 'nope'),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('Wrong password'))));
      expect(deletion.calls, isEmpty);
      expect(auth.deleted, isFalse);
    });

    test('requires-recent-login from Firebase asks for the password',
        () async {
      setUpWith(lastSignIn: DateTime.now());
      auth.deleteError = FirebaseAuthException(code: 'requires-recent-login');

      final outcome = await controller().deleteAccount();

      expect(outcome, AccountDeletionOutcome.needsPassword);
      expect(authController.logouts, 0);
    });

    test('a guest is deleted without a password', () async {
      setUpWith(
          lastSignIn: DateTime.now().subtract(const Duration(days: 30)),
          anonymous: true);

      final outcome = await controller().deleteAccount();

      expect(outcome, AccountDeletionOutcome.deleted);
      expect(auth.reauthPasswords, isEmpty);
      expect(deletion.calls, [me]);
      expect(auth.deleted, isTrue);
      expect(authController.logouts, 1);
    });
  });
}

class _MockUser extends Mock implements User {}

class _MockStorage extends Mock implements FirebaseStorage {}

class _MockReference extends Mock implements Reference {}

class _MockMetadata extends Mock implements UserMetadata {}

User _user({required DateTime lastSignIn, bool anonymous = false}) {
  final metadata = _MockMetadata();
  when(() => metadata.lastSignInTime).thenReturn(lastSignIn);
  final user = _MockUser();
  when(() => user.uid).thenReturn(me);
  when(() => user.isAnonymous).thenReturn(anonymous);
  when(() => user.email).thenReturn(anonymous ? null : 'me@example.com');
  when(() => user.metadata).thenReturn(metadata);
  return user;
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.user);

  final User user;
  final reauthPasswords = <String>[];
  FirebaseAuthException? reauthError;
  FirebaseAuthException? deleteError;
  bool deleted = false;

  @override
  User? get currentUser => deleted ? null : user;

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    if (reauthError != null) throw reauthError!;
    reauthPasswords.add(password);
  }

  @override
  Future<void> deleteCurrentUser() async {
    if (deleteError != null) throw deleteError!;
    deleted = true;
  }
}

class _RecordingRepository extends AccountDeletionRepository {
  final calls = <String>[];

  @override
  Future<void> deleteUserData(String uid) async => calls.add(uid);
}

class _FakeAuthController extends AuthController {
  int logouts = 0;

  @override
  Future<UserModel?> build() async => null;

  @override
  Future<void> logout() async => logouts++;
}
