// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase erfolgreich initialisiert');
  } catch (e, stackTrace) {
    debugPrint('❌ Firebase Initialisierungsfehler: $e');
    debugPrint('Stack Trace: $stackTrace');
    // App trotzdem starten, damit der Fehler sichtbar ist
  }
  runApp(const ProviderScope(child: MobileApp()));
}
