import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/utils/passport_stamps.dart';
import '../../../main_providers.dart';

/// The signed-in user's passport stamps, one per city they travelled to.
final passportStampsProvider = Provider<AsyncValue<List<PassportStamp>>>((ref) {
  final checkIns = ref.watch(checkInsProvider);
  if (checkIns.hasError) return AsyncError(checkIns.error!, StackTrace.empty);
  if (!checkIns.hasValue) return const AsyncLoading();
  return ref.watch(myTripsProvider).whenData((trips) =>
      passportStamps(trips, DateTime.now(), checkIns: checkIns.value!));
});
