import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/utils/passport_stamps.dart';
import '../../../common/utils/suitcase_progress.dart';
import '../../../main_providers.dart';

/// The signed-in user's passport stamps, one per city they travelled to.
final passportStampsProvider = Provider<AsyncValue<List<PassportStamp>>>((ref) {
  final checkIns = ref.watch(checkInsProvider);
  if (checkIns.hasError) return AsyncError(checkIns.error!, StackTrace.empty);
  if (!checkIns.hasValue) return const AsyncLoading();
  return ref.watch(myTripsProvider).whenData((trips) =>
      passportStamps(trips, DateTime.now(), checkIns: checkIns.value!));
});

/// The user's suitcase level, miles and extras; null while loading.
final suitcaseProgressProvider = Provider<SuitcaseProgress?>((ref) {
  final stamps = ref.watch(passportStampsProvider).value;
  final trips = ref.watch(myTripsProvider).value;
  if (stamps == null || trips == null) return null;
  return suitcaseProgress(trips: trips.length, stamps: stamps);
});
