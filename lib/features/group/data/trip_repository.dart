import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/sync_status.dart';
import '../../../common/models/trip_expense.dart';
import '../../../common/models/trip_idea.dart';
import '../../../common/models/trip_plan.dart';
import '../../../common/models/trip_poll.dart';

/// Planning data of a trip (a group): wishlist ideas, polls, expenses and
/// the day plan. Everything lives under `groups/{groupId}`.
class TripRepository {
  TripRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _group(String groupId) =>
      _db.collection('groups').doc(groupId);

  CollectionReference<Map<String, dynamic>> _ideas(String groupId) =>
      _group(groupId).collection('ideas');

  CollectionReference<Map<String, dynamic>> _polls(String groupId) =>
      _group(groupId).collection('polls');

  CollectionReference<Map<String, dynamic>> _expenses(String groupId) =>
      _group(groupId).collection('expenses');

  // --- Trips ---

  /// The trips [uid] is a member of. Same query as the trips tab, so the
  /// SDK serves both from one listener and its cache.
  Stream<List<GroupModel>> streamUserTrips(String uid) => _db
      .collection('groups')
      .where('members', arrayContains: uid)
      .snapshots()
      .map((snap) =>
          snap.docs.map((doc) => GroupModel.fromJson(doc.data())).toList());

  // --- Sync state ---

  /// Whether one trip (its document, wishlist, polls and expenses) is
  /// served from the cache or has unsent changes. Listens to the same
  /// queries as the screens with metadata changes, so the SDK shares the
  /// listeners and this costs no extra reads (one for the group document).
  Stream<SyncStatus> streamTripSyncStatus(String groupId) => _syncStatus([
        _group(groupId)
            .snapshots(includeMetadataChanges: true)
            .map((s) => s.metadata),
        for (final c in [_ideas(groupId), _polls(groupId), _expenses(groupId)])
          c.snapshots(includeMetadataChanges: true).map((s) => s.metadata),
      ]);

  /// [streamTripSyncStatus] for the trips list of [uid].
  Stream<SyncStatus> streamTripsSyncStatus(String uid) => _syncStatus([
        _db
            .collection('groups')
            .where('members', arrayContains: uid)
            .snapshots(includeMetadataChanges: true)
            .map((s) => s.metadata),
      ]);

  Stream<SyncStatus> _syncStatus(List<Stream<SnapshotMetadata>> sources) {
    final subs = <StreamSubscription<SnapshotMetadata>>[];
    final latest = <int, ({bool fromCache, bool pendingWrites})>{};
    late final StreamController<SyncStatus> controller;
    controller = StreamController<SyncStatus>(
      onListen: () {
        for (final (i, source) in sources.indexed) {
          subs.add(source.listen(
            (m) {
              latest[i] =
                  (fromCache: m.isFromCache, pendingWrites: m.hasPendingWrites);
              controller.add(SyncStatus.combine(latest.values));
            },
            // Load errors are shown by the screens' own listeners.
            onError: (Object _) {},
          ));
        }
      },
      onCancel: () => Future.wait([for (final s in subs) s.cancel()]),
    );
    return controller.stream.distinct();
  }

  // --- Ideas ---

  /// Wishlist, most liked first.
  Stream<List<TripIdea>> streamIdeas(String groupId) =>
      _ideas(groupId).snapshots().map((snap) => sortIdeasByLikes(
          snap.docs.map((d) => TripIdea.fromJson(d.id, d.data()))));

  Future<String> addIdea(
    String groupId, {
    required String title,
    required String uid,
    String? placeId,
    IdeaSource source = IdeaSource.manual,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('An idea needs a title');
    final ref = _ideas(groupId).doc();
    await ref.set(TripIdea(
      id: ref.id,
      placeId: placeId,
      title: trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed,
      addedBy: uid,
      // Whoever adds an idea likes it.
      likedBy: [uid],
      source: source,
    ).toJson());
    return ref.id;
  }

  /// Whether the trip's wishlist already has an idea for [placeId]. Live,
  /// so a pending local add shows up at once (also offline).
  Stream<bool> streamHasPlaceIdea(String groupId, String placeId) =>
      _ideas(groupId)
          .where('placeId', isEqualTo: placeId)
          .limit(1)
          .snapshots()
          .map((snap) => snap.docs.isNotEmpty);

  /// Adds [placeId] to the trip's wishlist unless an idea for it is
  /// already there. Returns the idea's id and whether it was new.
  Future<({String id, bool added})> addPlaceIdea(
    String groupId, {
    required String placeId,
    required String title,
    required String uid,
  }) async {
    final existing = await _ideas(groupId)
        .where('placeId', isEqualTo: placeId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return (id: existing.docs.first.id, added: false);
    }
    final id =
        await addIdea(groupId, title: title, uid: uid, placeId: placeId);
    return (id: id, added: true);
  }

  /// Adds or removes only [uid] in the idea's likes.
  Future<void> setIdeaLiked(
      String groupId, String ideaId, String uid, bool liked) {
    return _ideas(groupId).doc(ideaId).update({
      'likedBy': liked
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> deleteIdea(String groupId, String ideaId) =>
      _ideas(groupId).doc(ideaId).delete();

  // --- Polls ---

  /// Open polls first, newest first within each.
  Stream<List<TripPoll>> streamPolls(String groupId) =>
      _polls(groupId).snapshots().map((snap) {
        final polls =
            snap.docs.map((d) => TripPoll.fromJson(d.id, d.data())).toList();
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        polls.sort((a, b) {
          if (a.closed != b.closed) return a.closed ? 1 : -1;
          return (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch);
        });
        return polls;
      });

  Future<String> createPoll(
    String groupId, {
    required String question,
    required List<String> options,
    required String uid,
  }) async {
    final labels = [
      for (final o in options)
        if (o.trim().isNotEmpty) o.trim(),
    ];
    if (question.trim().isEmpty || labels.length < 2) {
      throw ArgumentError('A poll needs a question and two options');
    }
    final ref = _polls(groupId).doc();
    await ref.set(TripPoll(
      id: ref.id,
      question: question.trim(),
      options: [
        for (final (i, label) in labels.take(TripPoll.maxOptions).indexed)
          PollOption(id: 'o$i', label: label),
      ],
      createdBy: uid,
    ).toJson());
    return ref.id;
  }

  /// Sets [uid]'s one vote to [optionId], or removes it when null.
  Future<void> vote(
      String groupId, String pollId, String uid, String? optionId) {
    return _polls(groupId).doc(pollId).update({
      FieldPath(['votes', uid]): optionId ?? FieldValue.delete(),
    });
  }

  Future<void> setPollClosed(String groupId, String pollId, bool closed) =>
      _polls(groupId).doc(pollId).update({'closed': closed});

  Future<void> deletePoll(String groupId, String pollId) =>
      _polls(groupId).doc(pollId).delete();

  // --- Expenses ---

  /// Newest first.
  Stream<List<TripExpense>> streamExpenses(String groupId) =>
      _expenses(groupId).snapshots().map((snap) {
        final list =
            snap.docs.map((d) => TripExpense.fromJson(d.id, d.data())).toList();
        final far = DateTime(9999);
        // Pending server timestamps (null) are the newest.
        list.sort(
            (a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
        return list;
      });

  Future<String> addExpense(String groupId, TripExpense expense) async {
    _validate(expense);
    final ref = _expenses(groupId).doc();
    await ref.set(expense.toJson());
    return ref.id;
  }

  /// Saves the edited [expense]. Only its creator may: the rules enforce
  /// that on the server, this guard keeps the client from even trying.
  /// Creator and creation time never change.
  Future<void> updateExpense(
    String groupId,
    TripExpense expense, {
    required String uid,
  }) async {
    _checkCreator(expense, uid);
    _validate(expense);
    final data = expense.toJson()
      ..remove('createdAt')
      ..remove('createdBy');
    await _expenses(groupId).doc(expense.id).update(data);
  }

  /// Deletes [expense]; only its creator may.
  Future<void> deleteExpense(
    String groupId,
    TripExpense expense, {
    required String uid,
  }) async {
    _checkCreator(expense, uid);
    await _expenses(groupId).doc(expense.id).delete();
  }

  void _checkCreator(TripExpense expense, String uid) {
    if (expense.id.isEmpty || !expense.isEditableBy(uid)) {
      throw StateError(TripExpense.notCreatorMessage);
    }
  }

  void _validate(TripExpense expense) {
    if (expense.title.trim().isEmpty) {
      throw ArgumentError('An expense needs a title');
    }
    if (expense.amountCents <= 0) {
      throw ArgumentError('The amount must be positive');
    }
    if (expense.participants.isEmpty) {
      throw ArgumentError('An expense needs participants');
    }
  }

  // --- Day plan ---

  Future<void> saveTripPlan(String groupId, TripPlan plan) =>
      _group(groupId).update({'tripPlan': plan.toJson()});
}
