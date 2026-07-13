// main.dart
import 'package:flutter/material.dart';
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
  await (initializeEnv ?? Env.init)();
  await (initializeFirebase ??
      () => Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ))();
  (runApplication ?? runApp)(const ProviderScope(child: MobileApp()));
}
