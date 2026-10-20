// main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
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
      () => Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ))();
  (runApplication ?? runApp)(const ProviderScope(child: SwipeTripApp()));
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
