import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/auth_service.dart';
import 'core/services/calendar_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/location_service.dart';
import 'common/models/group_model.dart';
import 'features/group/data/trip_repository.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/swipe/data/places_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());
final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.read(firestoreServiceProvider)),
);
final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(),
);
final calendarServiceProvider =
    Provider<CalendarService>((ref) => CalendarService());

/// Trip planning data (ideas, polls, expenses). Global because screens of
/// other features (place detail, discover) add places to a trip.
final tripRepositoryProvider =
    Provider<TripRepository>((ref) => TripRepository());

/// The signed-in Firebase account for shared widgets outside the auth
/// feature: its uid and whether it is a guest. Null when signed out.
final currentAccountProvider =
    StreamProvider<({String uid, bool isGuest})?>((ref) {
  return ref.watch(authServiceProvider).userChanges().map((user) =>
      user == null ? null : (uid: user.uid, isGuest: user.isAnonymous));
});

/// The signed-in user's trips, the same data as the trips tab.
final myTripsProvider = StreamProvider<List<GroupModel>>((ref) {
  final uid = ref.watch(currentAccountProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(tripRepositoryProvider).streamUserTrips(uid);
});

/// Whether a trip's wishlist already has an idea for a place.
final placeInTripProvider = StreamProvider.autoDispose
    .family<bool, ({String groupId, String placeId})>((ref, key) => ref
        .watch(tripRepositoryProvider)
        .streamHasPlaceIdea(key.groupId, key.placeId));
