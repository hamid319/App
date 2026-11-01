import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static Future<void> init() async {
    // .env is not bundled as an asset (see pubspec.yaml), so a release
    // build ships no keys and the getters below return empty values.
    await dotenv.load(fileName: '.env', isOptional: true);
  }

  static String get googlePlacesApiKey =>
      dotenv.env['GOOGLE_PLACES_API_KEY']?.trim() ?? '';
}
