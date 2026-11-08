import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/packing.dart';
import '../../../common/utils/packing_template.dart';
import '../../../main_providers.dart';
import '../../auth/logic/auth_controller.dart';
import '../data/packing_repository.dart';

/// The signed-in member's own list for a trip; null until first changed.
final myPackingListProvider = StreamProvider.autoDispose
    .family<List<PackingItem>?, String>((ref, groupId) {
  final uid = ref.watch(authControllerProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(packingRepositoryProvider).streamMyList(uid, groupId);
});

/// Every member's packing progress on a trip (uid -> progress).
final packingProgressProvider = StreamProvider.autoDispose
    .family<Map<String, PackingProgress>, String>((ref, groupId) =>
        ref.watch(packingRepositoryProvider).streamProgress(groupId));

/// The trip's shared list.
final sharedPackingProvider = StreamProvider.autoDispose
    .family<List<SharedPackingItem>, String>((ref, groupId) =>
        ref.watch(packingRepositoryProvider).streamShared(groupId));

final packingControllerProvider =
    NotifierProvider<PackingController, void>(PackingController.new);

/// Changes to the packing lists. Each change writes the new progress with
/// it, so the group's percentages stay in step. Writes are not awaited by
/// the screen (they apply locally at once, also offline); the methods
/// return right away whether this change finished the packing.
class PackingController extends Notifier<void> {
  @override
  void build() {}

  PackingRepository get _repo => ref.read(packingRepositoryProvider);

  String get _uid {
    final uid = ref.read(authControllerProvider).value?.uid;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  /// The own list as shown: the saved one, else the suggested one.
  List<PackingItem> listOf(GroupModel trip) =>
      ref.read(myPackingListProvider(trip.groupId)).value ??
      suggestedPackingList(
        start: trip.tripStart,
        end: trip.tripEnd,
        countryCode: trip.location?.countryCode,
      );

  List<SharedPackingItem> _shared(String groupId) =>
      ref.read(sharedPackingProvider(groupId)).value ?? const [];

  /// Saves [items] as the own list. [write] gets the save, so the screen
  /// can report a failure.
  bool saveList(GroupModel trip, List<PackingItem> items,
      void Function(Future<void> save) write) {
    final uid = _uid;
    final shared = _shared(trip.groupId);
    final before = packingProgressOf(listOf(trip), shared, uid);
    final after = packingProgressOf(items, shared, uid);
    write(_repo.saveMyList(uid, trip.groupId, items, after));
    return !before.complete && after.complete;
  }

  bool toggle(GroupModel trip, PackingItem item,
          void Function(Future<void>) write) =>
      saveList(
          trip,
          [
            for (final i in listOf(trip))
              i.id == item.id ? i.copyWith(done: !i.done) : i
          ],
          write);

  void addOwn(GroupModel trip, String name, void Function(Future<void>) write) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    saveList(
        trip,
        [
          ...listOf(trip),
          PackingItem(
            id: 'own_${DateTime.now().microsecondsSinceEpoch}',
            category: PackingCategory.own,
            name: trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed,
          ),
        ],
        write);
  }

  void remove(GroupModel trip, PackingItem item,
          void Function(Future<void>) write) =>
      saveList(
          trip,
          [
            for (final i in listOf(trip))
              if (i.id != item.id) i
          ],
          write);

  /// Shared-list changes that move the member's own progress: taking or
  /// handing back an item, or ticking one they bring.
  bool _sharedChange(
    GroupModel trip,
    SharedPackingItem item,
    SharedPackingItem changed,
    Future<void> Function() change,
    void Function(Future<void>) write,
  ) {
    final uid = _uid;
    final mine = listOf(trip);
    final shared = _shared(trip.groupId);
    final before = packingProgressOf(mine, shared, uid);
    final after = packingProgressOf(
        mine, [for (final s in shared) s.id == item.id ? changed : s], uid);
    write(change().then((_) => _repo.saveProgress(uid, trip.groupId, after)));
    return !before.complete && after.complete;
  }

  void take(GroupModel trip, SharedPackingItem item,
          void Function(Future<void>) write) =>
      _sharedChange(trip, item, _with(item, bringer: _uid, packed: false),
          () => _repo.setBringer(trip.groupId, item.id, _uid), write);

  void handBack(GroupModel trip, SharedPackingItem item,
          void Function(Future<void>) write) =>
      _sharedChange(trip, item, _with(item, bringer: null, packed: false),
          () => _repo.setBringer(trip.groupId, item.id, null), write);

  bool toggleShared(GroupModel trip, SharedPackingItem item,
          void Function(Future<void>) write) =>
      _sharedChange(
          trip,
          item,
          _with(item, bringer: item.bringer, packed: !item.packed),
          () => _repo.setSharedPacked(trip.groupId, item.id, !item.packed),
          write);

  void addShared(
          GroupModel trip, String title, void Function(Future<void>) write) =>
      write(_repo.addShared(trip.groupId, title, _uid));

  void deleteShared(GroupModel trip, SharedPackingItem item,
      void Function(Future<void>) write) {
    if (item.bringer == _uid) {
      _sharedChange(trip, item, _with(item, bringer: null, packed: false),
          () => _repo.deleteShared(trip.groupId, item.id), write);
    } else {
      write(_repo.deleteShared(trip.groupId, item.id));
    }
  }

  SharedPackingItem _with(SharedPackingItem s,
          {required String? bringer, required bool packed}) =>
      SharedPackingItem(
        id: s.id,
        title: s.title,
        addedBy: s.addedBy,
        bringer: bringer,
        packed: packed,
        createdAt: s.createdAt,
      );
}
