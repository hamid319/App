import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/journal_entry.dart';
import '../../../common/models/place_model.dart';
import '../../../common/models/sync_status.dart';
import '../../../common/models/trip_expense.dart';
import '../../../common/models/trip_idea.dart';
import '../../../common/models/trip_plan.dart';
import '../../../common/models/trip_poll.dart';
import '../../../common/models/user_model.dart';
import '../../../common/utils/day_route.dart';
import '../../../common/utils/group_swipes.dart';
import '../../../common/utils/passport_stamps.dart';
import '../../../common/utils/trip_days.dart';
import '../../../common/widgets/member_avatar.dart' show friendlyMemberName;
import '../../../core/config/app_config.dart';
import '../../../core/services/maps_availability.dart';
import '../../../main_providers.dart';
import '../../auth/logic/auth_controller.dart';
import '../../swipe/data/places_repository.dart';
import '../data/journal_repository.dart';
import '../data/trip_repository.dart';
import 'group_controller.dart';

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

/// Every member's swipes on the trip's deck.
final tripSwipesProvider = StreamProvider.autoDispose
    .family<List<MemberSwipes>, String>((ref, groupId) =>
        ref.watch(tripRepositoryProvider).streamSwipes(groupId));

/// How the group answered each place it swiped on.
final tripSwipeTallyProvider = Provider.autoDispose
    .family<Map<String, PlaceTally>, String>((ref, groupId) {
  final swipes = ref.watch(tripSwipesProvider(groupId)).value ?? const [];
  final members = ref.watch(tripProvider(groupId)).value?.members ?? const [];
  return tallySwipes(swipes, members);
});

/// The wishlist as the screens show it: the ideas plus the group's swipe
/// matches, best liked first.
final tripWishlistProvider = Provider.autoDispose
    .family<AsyncValue<List<TripIdea>>, String>((ref, groupId) {
  final tally = ref.watch(tripSwipeTallyProvider(groupId));
  final members = ref.watch(tripProvider(groupId)).value?.members ?? const [];
  return ref
      .watch(tripIdeasProvider(groupId))
      .whenData((ideas) => wishlistWithMatches(ideas, tally, members.length));
});

/// The places the group swipes on: the trip city's sights, best known
/// first and in the same order for everyone, so matches come early.
final tripSwipePlacesProvider = FutureProvider.autoDispose
    .family<List<PlaceModel>, String>((ref, groupId) async {
  // Only a change of city reloads the deck, not every trip update.
  final cityId =
      ref.watch(tripProvider(groupId).select((t) => t.value?.location?.cityId));
  final location = ref.read(tripProvider(groupId)).value?.location;
  if (cityId == null || location == null) return const [];
  final repo = ref.read(placesRepositoryProvider);
  final curated =
      await repo.loadCityPlaces(PlacesRepository.curatedCityId(location));
  final sights =
      curated.where((p) => !p.isVenue).take(AppConfig.groupDeckSize).toList();
  if (sights.isNotEmpty) return sights;
  // A city without a curated import: the shared pool, in a fixed order.
  final pool =
      await repo.fetchPlacesForCity(location, limit: AppConfig.maxPlacesLimit);
  return pool..sort((a, b) => a.id.compareTo(b.id));
});

final tripPollsProvider = StreamProvider.autoDispose
    .family<List<TripPoll>, String>((ref, groupId) =>
        ref.watch(tripRepositoryProvider).streamPolls(groupId));

final tripExpensesProvider = StreamProvider.autoDispose
    .family<List<TripExpense>, String>((ref, groupId) =>
        ref.watch(tripRepositoryProvider).streamExpenses(groupId));

/// Whether Mapbox has a token, for the trip maps.
final mapsConfiguredProvider =
    FutureProvider<bool>((ref) => MapsAvailability().isConfigured());

final journalRepositoryProvider =
    Provider<JournalRepository>((ref) => JournalRepository());

/// The trip's journal, by day then time.
final tripJournalProvider = StreamProvider.autoDispose
    .family<List<JournalEntry>, String>((ref, groupId) =>
        ref.watch(journalRepositoryProvider).streamEntries(groupId));

/// Offline / unsent-changes state of one trip, for the trip screens.
final tripSyncStatusProvider = StreamProvider.autoDispose
    .family<SyncStatus, String>((ref, groupId) =>
        ref.watch(tripRepositoryProvider).streamTripSyncStatus(groupId));

/// Offline / unsent-changes state of the trips list.
final tripsSyncStatusProvider = StreamProvider.autoDispose<SyncStatus>((ref) {
  final uid = ref.watch(authControllerProvider).value?.uid;
  if (uid == null) return Stream.value(SyncStatus.synced);
  return ref.watch(tripRepositoryProvider).streamTripsSyncStatus(uid);
});

/// Places by id in the given order; the key is the ids joined with '|'.
final tripPlacesProvider =
    FutureProvider.autoDispose.family<List<PlaceModel>, String>((ref, key) {
  final ids = key.isEmpty ? <String>[] : key.split('|');
  return ref.watch(placesRepositoryProvider).loadPlacesByIds(ids);
});

/// Key for [tripPlacesProvider]: stable for the same set of ids.
String placesKey(Iterable<String> ids) =>
    (ids.toSet().toList()..sort()).join('|');

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

  /// Checks in at the trip's city for the passport stamp when the device
  /// is near it. Returns null when checked in, else the distance in km.
  Future<int?> checkIn(GroupModel trip) async {
    final uid = _uid;
    final pos =
        await ref.read(locationServiceProvider).getCurrentLocation(real: true);
    final km = _km(pos, trip.location!);
    if (km > AppConfig.checkInRadiusKm) return km.round();
    _checkIn(uid, trip.location!);
    return null;
  }

  /// Checks in silently at those of [trips] the device is near, if the
  /// location is already allowed and on (never asks). Returns those.
  Future<List<GroupModel>> autoCheckIn(List<GroupModel> trips) async {
    final uid = _uid;
    final allowed = await Geolocator.checkPermission();
    if (allowed != LocationPermission.whileInUse &&
        allowed != LocationPermission.always) {
      return const [];
    }
    if (!await Geolocator.isLocationServiceEnabled()) return const [];
    final pos =
        await ref.read(locationServiceProvider).getCurrentLocation(real: true);
    final near = [
      for (final t in trips)
        if (_km(pos, t.location!) <= AppConfig.checkInRadiusKm) t,
    ];
    for (final t in near) {
      _checkIn(uid, t.location!);
    }
    return near;
  }

  double _km(Position pos, GroupLocation place) =>
      Geolocator.distanceBetween(
          pos.latitude, pos.longitude, place.lat, place.lng) /
      1000;

  // Not awaited: offline it is queued and applied locally at once.
  void _checkIn(String uid, GroupLocation place) =>
      unawaited(_repo.checkIn(uid, stampKey(place)));

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

  /// A match from the swipe deck has no idea document: its heart is the
  /// member's swipe vote.
  Future<void> toggleLike(String groupId, TripIdea idea) {
    final uid = _uid;
    if (isSwipeMatchIdea(idea)) {
      return _repo.setSwipeVote(groupId, uid, idea.placeId!,
          idea.isLikedBy(uid) ? SwipeVote.nope : SwipeVote.like);
    }
    return _repo.setIdeaLiked(groupId, idea.id, uid, !idea.isLikedBy(uid));
  }

  /// Records a swipe on [placeId]; null takes it back.
  Future<void> swipe(String groupId, String placeId, SwipeVote? vote) =>
      _repo.setSwipeVote(groupId, _uid, placeId, vote);

  /// Puts the member's one veto on [placeId]; null withdraws it.
  Future<void> setVeto(String groupId, String? placeId) =>
      _repo.setSwipeVeto(groupId, _uid, placeId);

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

  /// Saves an edited expense; only its creator may.
  Future<void> updateExpense(String groupId, TripExpense expense) =>
      _repo.updateExpense(groupId, expense, uid: _uid);

  /// Deletes an expense; only its creator may.
  Future<void> deleteExpense(String groupId, TripExpense expense) =>
      _repo.deleteExpense(groupId, expense, uid: _uid);

  /// Adds a journal entry; [photos] are uploaded first (needs a
  /// connection), [onProgress] counts finished uploads.
  Future<void> addJournalEntry(
    String groupId, {
    required DateTime day,
    required String text,
    List<XFile> photos = const [],
    void Function(int done, int total)? onProgress,
  }) async {
    final uid = _uid;
    final uploads = [for (final f in photos) await _readPhoto(f)];
    await ref.read(journalRepositoryProvider).addEntry(
          groupId,
          authorUid: uid,
          day: journalDayKey(day),
          text: text,
          photos: uploads,
          onProgress: onProgress,
        );
  }

  /// Bytes and pixel size, read from the header without decoding.
  Future<JournalPhotoUpload> _readPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = (width: descriptor.width, height: descriptor.height);
    descriptor.dispose();
    buffer.dispose();
    return (bytes: bytes, width: size.width, height: size.height);
  }

  Future<void> editJournalText(
          String groupId, JournalEntry entry, String text) =>
      ref.read(journalRepositoryProvider).editText(groupId, entry, text);

  Future<void> deleteJournalEntry(String groupId, JournalEntry entry) =>
      ref.read(journalRepositoryProvider).deleteEntry(groupId, entry);

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
}

/// Gives the owner's groups an entry in `inviteCodes` (groups made before
/// that lookup existed have none, so their code could not be resolved).
/// Best effort and once per group per app run; watched by the trips list.
final inviteIndexBackfillProvider = Provider<void>((ref) {
  final me = ref.watch(authControllerProvider).value;
  final uid = me?.uid;
  final groups = ref.watch(userGroupsProvider).value ?? const <GroupModel>[];
  if (uid == null) return;
  final repo = ref.read(groupRepositoryProvider);
  for (final group in groups) {
    if (group.ownerUid != uid || !_indexedInvites.add(group.groupId)) continue;
    repo
        .ensureInviteIndex(group,
            ownerName: friendlyMemberName(me?.displayName))
        .catchError((Object _) {
      // Retried on the next app start.
      _indexedInvites.remove(group.groupId);
    });
  }
});

final Set<String> _indexedInvites = {};
