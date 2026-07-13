import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
  }

  static String get googlePlacesApiKey =>
      dotenv.env['GOOGLE_PLACES_API_KEY']?.trim() ?? '';

  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY']?.trim() ?? '';

  static String get geminiModel {
    final configured = dotenv.env['GEMINI_MODEL']?.trim() ?? '';
    return configured.isEmpty ? 'gemini-2.5-flash' : configured;
  }

  static List<String> get missingDemoVariables => <String>[
        if (googlePlacesApiKey.isEmpty) 'GOOGLE_PLACES_API_KEY',
        if (geminiApiKey.isEmpty) 'GEMINI_API_KEY',
      ];
}
