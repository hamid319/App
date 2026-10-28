import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/utils/passport_stamps.dart';
import '../../../main_providers.dart';

/// The signed-in user's passport stamps, one per city they travelled to.
final passportStampsProvider = Provider<AsyncValue<List<PassportStamp>>>(
  (ref) => ref
      .watch(myTripsProvider)
      .whenData((trips) => passportStamps(trips, DateTime.now())),
);
