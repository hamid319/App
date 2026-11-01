import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/preferences_service.dart';
import '../main_providers.dart';
import 'routes.dart';

/// Trip push notifications: registers this device once the account is in a
/// trip (so the permission prompt makes sense), keeps the language of the
/// texts current, and opens the trip when a push is tapped.
class PushWatcher extends ConsumerStatefulWidget {
  const PushWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushWatcher> createState() => _PushWatcherState();
}

class _PushWatcherState extends ConsumerState<PushWatcher> {
  /// 'uid:lang' last registered, so it is not repeated on every rebuild.
  String? _registered;

  @override
  void initState() {
    super.initState();
    final local = ref.read(tripReminderServiceProvider);
    ref
        .read(pushServiceProvider)
        .start(
          onOpen: (route) => ref.read(routerProvider).go(route),
          onForeground: local.show,
        )
        // No plugin in widget tests (and on unsupported platforms).
        .catchError((Object e) => debugPrint('Push: $e'));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  Future<void> _sync() async {
    final account = ref.read(currentAccountProvider).value;
    final trips = ref.read(myTripsProvider).value ?? const [];
    if (account == null || account.isGuest || trips.isEmpty) return;
    final lang = Localizations.localeOf(context).languageCode;
    final key = '${account.uid}:$lang';
    if (_registered == key) return;
    _registered = key;
    try {
      if (!await PreferencesService.isPushEnabled()) return;
      await ref.read(pushServiceProvider).register(account.uid, lang);
    } catch (e) {
      _registered = null;
      debugPrint('Push registration: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentAccountProvider, (_, __) => _sync());
    ref.listen(myTripsProvider, (_, __) => _sync());
    return widget.child;
  }
}
