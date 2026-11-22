import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'check_in_watcher.dart';
import 'push_watcher.dart';
import 'theme.dart';
import 'routes.dart';
import 'locale_controller.dart';
import 'theme_mode_controller.dart';
import '../l10n/l10n.dart';

class SwipeTripApp extends ConsumerWidget {
  const SwipeTripApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => 'Out We Go',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // The app's pages are cream in both modes: dark status bar icons,
      // except where a page (DarkTabPage, photo headers) sets light ones.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: CheckInWatcher(child: PushWatcher(child: child!)),
      ),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (deviceLocales, _) =>
          resolveAppLocale(deviceLocales),
    );
  }
}
