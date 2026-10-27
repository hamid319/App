import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/place_model.dart';
import '../../../common/models/trip_expense.dart';
import '../../../common/models/trip_idea.dart';
import '../../../common/models/trip_plan.dart';
import '../../../common/models/trip_poll.dart';
import '../../../common/models/user_model.dart';
import '../../../common/utils/day_route.dart';
import '../../../common/utils/trip_days.dart';
import '../../../main_providers.dart';
import '../../auth/logic/auth_controller.dart';
import '../../swipe/data/places_repository.dart';
import '../data/trip_repository.dart';
import 'group_controller.dart';

final tripRepositoryProvider =
    Provider<TripRepository>((ref) => TripRepository());

/// One trip (group) of the signed-in user, live from [userGroupsProvider].
/// Data is null when the user is not (or no longer) a member.
final tripProvider =
    Provider.family<AsyncValue<GroupModel?>, String>((ref, groupId) {
  return ref.watch(userGroupsProvider).whenData((groups) {
    for (final g in groups) {
      if (g.groupId == groupId) return g;
    }
    return null;
  });
});

final tripIdeasProvider = StreamProvider.autoDispose
    .family<List<TripIdea>, String>((ref, groupId) =>
        ref.watch(tripRepositoryProvider).streamIdeas(groupId));

final tripPollsProvider = StreamProvider.autoDispose
    .family<List<TripPoll>, String>((ref, groupId) =>
        ref.watch(tripRepositoryProvider).streamPolls(groupId));

final tripExpensesProvider = StreamProvider.autoDispose
    .family<List<TripExpense>, String>((ref, groupId) =>
        ref.watch(tripRepositoryProvider).streamExpenses(groupId));

/// Places by id in the given order; the key is the ids joined with '|'.
final tripPlacesProvider = FutureProvider.autoDispose
    .family<List<PlaceModel>, String>((ref, key) {
  final ids = key.isEmpty ? <String>[] : key.split('|');
  return ref.watch(placesRepositoryProvider).loadPlacesByIds(ids);
});

/// Key for [tripPlacesProvider]: stable for the same set of ids.
String placesKey(Iterable<String> ids) => (ids.toSet().toList()..sort()).join('|');

/// Curated places of the trip's city, best-known first: the cover photo
/// and suggestions for new ideas. Empty for cities without the import.
final tripCityPlacesProvider =
    FutureProvider.family<List<PlaceModel>, String>((ref, cityKey) async {
  if (cityKey.isEmpty) return const [];
  try {
    return await ref
        .read(placesRepositoryProvider)
        .loadCityPlaces(cityKey, limit: 60);
  } catch (_) {
    return const [];
  }
});

/// [tripCityPlacesProvider] key of a trip, '' without a location.
String tripCityKey(GroupModel group) => group.location == null
    ? ''
    : PlacesRepository.curatedCityId(group.location!);

/// A member's profile, for their PayPal handle.
final memberProfileProvider =
    FutureProvider.autoDispose.family<UserModel, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).getUserProfile(uid);
});

/// Number of open polls of a trip, for the trips list.
final openPollCountProvider =
    Provider.autoDispose.family<int, String>((ref, groupId) {
  final polls = ref.watch(tripPollsProvider(groupId)).value ?? const [];
  return polls.where((p) => !p.closed).length;
});

final tripActionsProvider =
    NotifierProvider<TripActions, void>(TripActions.new);

/// Writes of the trip planning screens. Every action needs a signed-in user.
class TripActions extends Notifier<void> {
  @override
  void build() {}

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  String get _uid {
    final uid = ref.read(authControllerProvider).value?.uid;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  Future<void> addIdea(String groupId, String title, {String? placeId}) {
    final text = title.trim();
    final isLink = text.startsWith('http://') || text.startsWith('https://');
    return _repo.addIdea(
      groupId,
      title: text,
      uid: _uid,
      placeId: placeId,
      source: placeId == null && isLink ? IdeaSource.link : IdeaSource.manual,
    );
  }

  Future<void> toggleLike(String groupId, TripIdea idea) {
    final uid = _uid;
    return _repo.setIdeaLiked(groupId, idea.id, uid, !idea.isLikedBy(uid));
  }

  Future<void> deleteIdea(String groupId, String ideaId) =>
      _repo.deleteIdea(groupId, ideaId);

  Future<void> createPoll(
          String groupId, String question, List<String> options) =>
      _repo.createPoll(groupId,
          question: question, options: options, uid: _uid);

  /// Votes for [optionId]; tapping the own vote again takes it back.
  Future<void> vote(String groupId, TripPoll poll, String optionId) {
    final uid = _uid;
    final current = poll.voteOf(uid);
    return _repo.vote(
        groupId, poll.id, uid, current == optionId ? null : optionId);
  }

  Future<void> setPollClosed(String groupId, String pollId, bool closed) =>
      _repo.setPollClosed(groupId, pollId, closed);

  Future<void> addExpense(
    String groupId, {
    required String title,
    required int amountCents,
    required String paidBy,
    required List<String> participants,
  }) {
    final uid = _uid;
    return _repo.addExpense(
      groupId,
      TripExpense(
        id: '',
        title: title.trim(),
        amountCents: amountCents,
        paidBy: paidBy,
        participants: participants,
        createdBy: uid,
      ),
    );
  }

  Future<void> deleteExpense(String groupId, String expenseId) =>
      _repo.deleteExpense(groupId, expenseId);

  /// Builds the trip's day plan from the wishlist ideas that have a place,
  /// most liked first, spread over the trip days as short walking routes.
  Future<TripPlan> buildPlan(GroupModel group, List<TripIdea> ideas) async {
    final ranked = sortIdeasByLikes(ideas.where((i) => i.placeId != null));
    final places = await ref
        .read(placesRepositoryProvider)
        .loadPlacesByIds([for (final i in ranked) i.placeId!]);
    final byId = {for (final p in places) p.id: p};
    final stops = [
      for (final idea in ranked)
        if (byId[idea.placeId] case final p?)
          RouteStop(id: p.id, lat: p.lat, lng: p.lng),
    ];
    if (stops.isEmpty) throw StateError('No ideas with a place');
    final plan = TripPlan(
      days: distributeStopsOverDays(
          stops, tripDayCount(group.tripStart, group.tripEnd)),
    );
    await _repo.saveTripPlan(group.groupId, plan);
    return plan;
  }

  /// Adds the places the group matched on in its last finished swipe
  /// session to the wishlist, skipping places already on it. Returns how
  /// many ideas were added.
  Future<int> importSwipeMatches(
    GroupModel group,
    List<TripIdea> existing,
    String languageCode,
  ) async {
    final uid = _uid;
    final groupRepo = ref.read(groupRepositoryProvider);
    final sessions = await groupRepo.getCompletedSessions(group.groupId);
    if (sessions.isEmpty) return 0;
    final session = sessions.first;
    final votes = await groupRepo.getQualifiedPlaces(
      groupId: group.groupId,
      sessionId: session.sessionId,
      participantCount: session.participants.length,
    );
    final known = {for (final i in existing) i.placeId};
    final ids = [
      for (final v in votes)
        if (v['placeId'] is String && !known.contains(v['placeId']))
          v['placeId'] as String,
    ];
    final places =
        await ref.read(placesRepositoryProvider).loadPlacesByIds(ids);
    for (final place in places) {
      await _repo.addIdea(
        group.groupId,
        title: place.nameFor(languageCode),
        uid: uid,
        placeId: place.id,
        source: IdeaSource.swipe,
      );
    }
    return places.length;
  }
}
