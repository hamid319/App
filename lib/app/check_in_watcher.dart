import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/utils/passport_stamps.dart';
import '../features/group/logic/trip_controller.dart';
import '../l10n/l10n.dart';
import '../main_providers.dart';
import 'routes.dart';

/// Passport check-ins without a tap: while a trip is on, the app checks in
/// whenever it is opened near the city (if the location is allowed), and
/// a local notification on the first trip day reminds the others.
class CheckInWatcher extends ConsumerStatefulWidget {
  const CheckInWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CheckInWatcher> createState() => _CheckInWatcherState();
}

class _CheckInWatcherState extends ConsumerState<CheckInWatcher> {
  late final AppLifecycleListener _lifecycle;
  bool _running = false;

  /// Trip documents change often; GPS is asked at most every few minutes.
  DateTime? _lastFix;

  @override
  void initState() {
    super.initState();
    final reminders = ref.read(tripReminderServiceProvider);
    reminders.onOpen = (id) => ref.read(routerProvider).go('/trip/$id');
    // No plugin in widget tests (and on unsupported platforms).
    reminders.start().catchError((Object e) => debugPrint('Reminders: $e'));
    _lifecycle = AppLifecycleListener(onResume: _run);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final account = ref.read(currentAccountProvider).value;
    final trips = ref.read(myTripsProvider).value;
    final checkIns = ref.read(checkInsProvider).value;
    if (_running || account == null || account.isGuest) return;
    if (trips == null || checkIns == null) return;
    _running = true;
    try {
      final now = DateTime.now();
      final due = tripsToCheckIn(trips, checkIns, now);
      final fresh = _lastFix != null &&
          now.difference(_lastFix!) < const Duration(minutes: 5);
      if (due.isNotEmpty && !fresh) {
        _lastFix = now;
        final done =
            await ref.read(tripActionsProvider.notifier).autoCheckIn(due);
        if (done.isNotEmpty && mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
              content: Text(
                  context.l10n.checkInDone(done.first.location!.cityName))));
        }
      }
      if (!mounted) return;
      final l10n = context.l10n;
      final times = checkInReminderTimes(trips, checkIns, now);
      final service = ref.read(tripReminderServiceProvider);
      // Asked only once there is a reminder to show, i.e. right after
      // creating or joining a dated trip; the system asks only once.
      if (times.isNotEmpty) await service.requestPermission();
      await service.sync([
        // iOS keeps at most 64 pending notifications per app.
        for (final t in times.take(20))
          (
            groupId: t.trip.groupId,
            at: t.at,
            title: l10n.checkInReminderTitle(t.trip.location!.cityName),
            body: l10n.checkInReminderBody,
          ),
      ]);
    } catch (e) {
      debugPrint('Check-in watcher: $e');
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Runs again when trips or check-ins change (a new trip, a check-in).
    ref.listen(myTripsProvider, (_, __) => _run());
    ref.listen(checkInsProvider, (_, __) => _run());
    return widget.child;
  }
}
