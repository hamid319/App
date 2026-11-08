// main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/config/env.dart';
import 'firebase_options.dart';

Future<void> main() async {
  await bootstrapApp();
}

@visibleForTesting
Future<void> bootstrapApp({
  Future<void> Function()? initializeEnv,
  Future<void> Function()? initializeFirebase,
  void Function(Widget app)? runApplication,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  await (initializeEnv ?? Env.init)();
  await (initializeFirebase ??
      () async {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _configureFirestoreCache();
        await _activateAppCheck();
      })();
  (runApplication ?? runApp)(const ProviderScope(child: SwipeTripApp()));
}

/// Offline use of the trip screens: keeps Firestore's cache on with a set
/// size. Must run before the first Firestore call.
void _configureFirestoreCache() {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: AppConfig.firestoreCacheBytes,
  );
}

/// App Check guards the receipt scan (Firebase AI Logic enforces it).
/// Debug builds use the debug provider; its token is passed with
/// --dart-define=APP_CHECK_DEBUG_TOKEN=... and registered in the console.
/// A failure must not block the start: only the scan needs it.
Future<void> _activateAppCheck() async {
  const token = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');
  final debugToken = token.isEmpty ? null : token;
  try {
    await FirebaseAppCheck.instance.activate(
      providerApple: kDebugMode
          ? AppleDebugProvider(debugToken: debugToken)
          : const AppleDeviceCheckProvider(),
      providerAndroid: kDebugMode
          ? AndroidDebugProvider(debugToken: debugToken)
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
    debugPrint('App Check not active: $e');
  }
}

/// The bundled fonts are SIL OFL 1.1, which asks that the licence travels
/// with the font. This lists both on Flutter's licence page.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Figtree', 'assets/fonts/Figtree-OFL.txt'),
      ('Bricolage Grotesque', 'assets/fonts/BricolageGrotesque-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString(file));
    }
  });
}
