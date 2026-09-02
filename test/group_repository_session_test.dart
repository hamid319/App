import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/core/services/firestore_service.dart';
import 'package:swipetrip/features/group/data/group_repository.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  group('GroupRepository session transactions', () {
    late FakeFirebaseFirestore firestore;
    late GroupRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = GroupRepository(
        _MockFirestoreService(),
        firestore: firestore,
      );
    });

    test('injected Firestore is used for repository group writes', () async {
      await repository.createGroup(
        const GroupModel(
          groupId: 'group-1',
          members: ['user-1'],
        ),
      );

      final group = await firestore.collection('groups').doc('group-1').get();
      expect(group.exists, isTrue);
      expect(group.data()!['members'], ['user-1']);
      expect(group.data()!['joinEnabled'], isTrue);
    });

    test('session setup freezes participants and place pool', () async {
      await firestore.collection('groups').doc('group-1').set({
        'groupId': 'group-1',
        'members': ['user-1', 'user-2'],
        'sharedFavorites': <String>[],
        'hasCompletedSession': false,
        'activeSessionId': null,
        'joinEnabled': true,
      });

      final sessionId = await repository.startSwipeSession(
        groupId: 'group-1',
        destination: 'Berlin',
        participantUids: ['user-1', 'user-2'],
        swipeLimit: 2,
        placePool: ['place-1', 'place-2'],
      );

      final session = await firestore
          .collection('groups')
          .doc('group-1')
          .collection('sessions')
          .doc(sessionId)
          .get();
      final group = await firestore.collection('groups').doc('group-1').get();

      expect(session.data()!['participants'], ['user-1', 'user-2']);
      expect(session.data()!['placePool'], ['place-1', 'place-2']);
      expect(session.data()!['progressByUser'], {
        'user-1': 0,
        'user-2': 0,
      });
      expect(group.data()!['activeSessionId'], sessionId);
      expect(group.data()!['joinEnabled'], isFalse);
    });

    test('a nonparticipant cannot vote or create partial state', () async {
      final sessionId = await _startSession(
        firestore: firestore,
        repository: repository,
        participants: ['user-1'],
        swipeLimit: 1,
        placePool: ['place-1'],
      );

      await expectLater(
        repository.recordSwipeInSession(
          groupId: 'group-1',
          sessionId: sessionId,
          userId: 'outsider',
          placeId: 'place-1',
          liked: true,
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('not a participant'),
          ),
        ),
      );

      final sessionRef = firestore
          .collection('groups')
          .doc('group-1')
          .collection('sessions')
          .doc(sessionId);
      expect((await sessionRef.get()).data()!['progressByUser'], {'user-1': 0});
      expect(
        (await sessionRef.collection('votes').doc('place-1').get()).exists,
        isFalse,
      );
      expect(
        (await sessionRef.collection('userSwipes').doc('outsider').get())
            .exists,
        isFalse,
      );
    });

    test('first vote writes aggregate and user swipe progress', () async {
      final sessionId = await _startSession(
        firestore: firestore,
        repository: repository,
        participants: ['user-1'],
        swipeLimit: 2,
        placePool: ['place-1', 'place-2'],
      );

      await repository.recordSwipeInSession(
        groupId: 'group-1',
        sessionId: sessionId,
        userId: 'user-1',
        placeId: 'place-1',
        liked: true,
      );

      final sessionRef = firestore
          .collection('groups')
          .doc('group-1')
          .collection('sessions')
          .doc(sessionId);
      final vote =
          (await sessionRef.collection('votes').doc('place-1').get()).data()!;
      final userSwipe =
          (await sessionRef.collection('userSwipes').doc('user-1').get())
              .data()!;
      final session = (await sessionRef.get()).data()!;

      _expectAggregateInvariant(
        vote,
        likedBy: {'user-1'},
        dislikedBy: <String>{},
      );
      expect(userSwipe['swipedPlaceIds'], ['place-1']);
      expect(userSwipe['likedPlaceIds'], ['place-1']);
      expect(session['progressByUser'], {'user-1': 1});
      expect(session['swipeProgress'], {'user-1': 1});
      expect(session['status'], 'in_progress');
    });

    test('duplicate vote does not advance progress twice', () async {
      final sessionId = await _startSession(
        firestore: firestore,
        repository: repository,
        participants: ['user-1'],
        swipeLimit: 2,
        placePool: ['place-1', 'place-2'],
      );

      for (var attempt = 0; attempt < 2; attempt++) {
        await repository.recordSwipeInSession(
          groupId: 'group-1',
          sessionId: sessionId,
          userId: 'user-1',
          placeId: 'place-1',
          liked: true,
        );
      }

      final sessionRef = firestore
          .collection('groups')
          .doc('group-1')
          .collection('sessions')
          .doc(sessionId);
      final session = (await sessionRef.get()).data()!;
      final vote =
          (await sessionRef.collection('votes').doc('place-1').get()).data()!;
      final userSwipe =
          (await sessionRef.collection('userSwipes').doc('user-1').get())
              .data()!;

      expect(session['progressByUser'], {'user-1': 1});
      expect(userSwipe['swipedPlaceIds'], ['place-1']);
      _expectAggregateInvariant(
        vote,
        likedBy: {'user-1'},
        dislikedBy: <String>{},
      );
    });

    test('changing an existing vote updates aggregate without progress',
        () async {
      final sessionId = await _startSession(
        firestore: firestore,
        repository: repository,
        participants: ['user-1'],
        swipeLimit: 2,
        placePool: ['place-1', 'place-2'],
      );

      await repository.recordSwipeInSession(
        groupId: 'group-1',
        sessionId: sessionId,
        userId: 'user-1',
        placeId: 'place-1',
        liked: false,
      );
      await repository.recordSwipeInSession(
        groupId: 'group-1',
        sessionId: sessionId,
        userId: 'user-1',
        placeId: 'place-1',
        liked: true,
      );

      final sessionRef = firestore
          .collection('groups')
          .doc('group-1')
          .collection('sessions')
          .doc(sessionId);
      final session = (await sessionRef.get()).data()!;
      final vote =
          (await sessionRef.collection('votes').doc('place-1').get()).data()!;
      final userSwipe =
          (await sessionRef.collection('userSwipes').doc('user-1').get())
              .data()!;

      expect(session['progressByUser'], {'user-1': 1});
      expect(userSwipe['likedPlaceIds'], ['place-1']);
      _expectAggregateInvariant(
        vote,
        likedBy: {'user-1'},
        dislikedBy: <String>{},
      );
    });

    test('all participants completing marks session and clears group state',
        () async {
      final sessionId = await _startSession(
        firestore: firestore,
        repository: repository,
        participants: ['user-1', 'user-2'],
        swipeLimit: 1,
        placePool: ['place-1'],
      );

      await repository.recordSwipeInSession(
        groupId: 'group-1',
        sessionId: sessionId,
        userId: 'user-1',
        placeId: 'place-1',
        liked: true,
      );
      await repository.recordSwipeInSession(
        groupId: 'group-1',
        sessionId: sessionId,
        userId: 'user-2',
        placeId: 'place-1',
        liked: false,
      );

      final sessionRef = firestore
          .collection('groups')
          .doc('group-1')
          .collection('sessions')
          .doc(sessionId);
      final session = (await sessionRef.get()).data()!;
      final group =
          (await firestore.collection('groups').doc('group-1').get()).data()!;
      final vote =
          (await sessionRef.collection('votes').doc('place-1').get()).data()!;

      expect(session['status'], 'completed');
      expect(session['progressByUser'], {'user-1': 1, 'user-2': 1});
      expect(session['endedAt'], isA<Timestamp>());
      expect(session['endedByUid'], isNull);
      expect(group['activeSessionId'], isNull);
      expect(group['hasCompletedSession'], isTrue);
      _expectAggregateInvariant(
        vote,
        likedBy: {'user-1'},
        dislikedBy: {'user-2'},
      );
    });

    test('manual completion records actor and clears group state', () async {
      final sessionId = await _startSession(
        firestore: firestore,
        repository: repository,
        participants: ['admin', 'user-2'],
        swipeLimit: 2,
        placePool: ['place-1', 'place-2'],
      );

      await repository.endSessionManually(
        groupId: 'group-1',
        sessionId: sessionId,
        adminUid: 'admin',
      );

      final session = (await firestore
              .collection('groups')
              .doc('group-1')
              .collection('sessions')
              .doc(sessionId)
              .get())
          .data()!;
      final group =
          (await firestore.collection('groups').doc('group-1').get()).data()!;

      expect(session['status'], 'completed');
      expect(session['endedAt'], isA<Timestamp>());
      expect(session['endedByUid'], 'admin');
      expect(group['activeSessionId'], isNull);
      expect(group['hasCompletedSession'], isTrue);
    });

    test('invalid session participants do not partially update the group',
        () async {
      await firestore.collection('groups').doc('group-1').set({
        'groupId': 'group-1',
        'members': ['user-1'],
        'sharedFavorites': <String>[],
        'hasCompletedSession': false,
        'activeSessionId': null,
        'joinEnabled': true,
      });

      await expectLater(
        repository.startSwipeSession(
          groupId: 'group-1',
          destination: 'Berlin',
          participantUids: ['user-1', 'outsider'],
          swipeLimit: 1,
          placePool: ['place-1'],
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Participants must be group members'),
          ),
        ),
      );

      final group =
          (await firestore.collection('groups').doc('group-1').get()).data()!;
      final sessions = await firestore
          .collection('groups')
          .doc('group-1')
          .collection('sessions')
          .get();
      expect(sessions.docs, isEmpty);
      expect(group['activeSessionId'], isNull);
      expect(group['joinEnabled'], isTrue);
    });

    test('failed completion transaction leaves no partial vote or progress',
        () async {
      final sessionRef = firestore
          .collection('groups')
          .doc('missing-group')
          .collection('sessions')
          .doc('session-1');
      await sessionRef.set({
        'sessionId': 'session-1',
        'destination': 'Berlin',
        'status': 'in_progress',
        'totalPlacesToSwipe': 1,
        'swipeLimit': 1,
        'participants': ['user-1'],
        'placePool': ['place-1'],
        'swipeProgress': {'user-1': 0},
        'progressByUser': {'user-1': 0},
        'createdAt': Timestamp.now(),
      });

      await expectLater(
        repository.recordSwipeInSession(
          groupId: 'missing-group',
          sessionId: 'session-1',
          userId: 'user-1',
          placeId: 'place-1',
          liked: true,
        ),
        throwsA(anything),
      );

      final session = (await sessionRef.get()).data()!;
      expect(session['status'], 'in_progress');
      expect(session['progressByUser'], {'user-1': 0});
      expect(
        (await sessionRef.collection('votes').doc('place-1').get()).exists,
        isFalse,
      );
      expect(
        (await sessionRef.collection('userSwipes').doc('user-1').get()).exists,
        isFalse,
      );
    });
  });
}

Future<String> _startSession({
  required FakeFirebaseFirestore firestore,
  required GroupRepository repository,
  required List<String> participants,
  required int swipeLimit,
  required List<String> placePool,
}) async {
  await firestore.collection('groups').doc('group-1').set({
    'groupId': 'group-1',
    'members': participants,
    'sharedFavorites': <String>[],
    'hasCompletedSession': false,
    'activeSessionId': null,
    'joinEnabled': true,
  });
  return repository.startSwipeSession(
    groupId: 'group-1',
    destination: 'Berlin',
    participantUids: participants,
    swipeLimit: swipeLimit,
    placePool: placePool,
  );
}

void _expectAggregateInvariant(
  Map<String, dynamic> vote, {
  required Set<String> likedBy,
  required Set<String> dislikedBy,
}) {
  final actualLikedBy = Set<String>.from(vote['likedBy'] as List);
  final actualDislikedBy = Set<String>.from(vote['dislikedBy'] as List);

  expect(actualLikedBy, likedBy);
  expect(actualDislikedBy, dislikedBy);
  expect(vote['likes'], actualLikedBy.length);
  expect(vote['dislikes'], actualDislikedBy.length);
  expect(actualLikedBy.intersection(actualDislikedBy), isEmpty);
}
