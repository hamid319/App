import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/sync_status.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';

/// Small pill for the trip screens: "Offline" without a connection,
/// "Syncing…" while local changes are still on their way. Nothing when
/// everything is saved.
class TripSyncBadge extends ConsumerWidget {
  const TripSyncBadge({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SyncBadge(
        status:
            ref.watch(tripSyncStatusProvider(groupId)).value ?? SyncStatus.synced,
      );
}

/// [TripSyncBadge] for the trips list.
class TripsSyncBadge extends ConsumerWidget {
  const TripsSyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SyncBadge(
        status: ref.watch(tripsSyncStatusProvider).value ?? SyncStatus.synced,
      );
}

/// Shows [status] once it has lasted a moment: right after opening a
/// screen the first snapshot often comes from the cache, and a short write
/// round trip should not flash either.
class SyncBadge extends StatefulWidget {
  const SyncBadge({super.key, required this.status});

  final SyncStatus status;

  static const delay = Duration(milliseconds: 1500);

  @override
  State<SyncBadge> createState() => _SyncBadgeState();
}

class _SyncBadgeState extends State<SyncBadge> {
  SyncStatus _shown = SyncStatus.synced;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(SyncBadge old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.status == SyncStatus.synced) {
      if (_shown != SyncStatus.synced) setState(() => _shown = SyncStatus.synced);
      return;
    }
    _timer = Timer(SyncBadge.delay, () {
      if (mounted) setState(() => _shown = widget.status);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final Widget child = switch (_shown) {
      SyncStatus.synced => const SizedBox.shrink(key: ValueKey('synced')),
      final status => Tooltip(
          key: ValueKey(status),
          message: l10n.tripOfflineHint,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status == SyncStatus.offline
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_sync_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  status == SyncStatus.offline
                      ? l10n.tripOffline
                      : l10n.tripSyncing,
                  style: text.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}
