import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> updateExpense(String groupId, TripExpense expense) async {
    _validate(expense);
    final data = expense.toJson()..remove('createdAt');
    await _expenses(groupId).doc(expense.id).update(data);
  }

  Future<void> deleteExpense(String groupId, String expenseId) =>
      _expenses(groupId).doc(expenseId).delete();

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
