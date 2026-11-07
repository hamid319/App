import 'package:flutter_tts/flutter_tts.dart';

/// Reads text aloud with the device's own voices (free, works offline when
/// the voice is installed).
class SpeechService {
  final FlutterTts _tts = FlutterTts();

  /// Speaks [text] in [locale] (e.g. 'ja-JP'). Returns false when the device
  /// has no voice for that language.
  Future<bool> speak(String text, String locale) async {
    if (await _tts.isLanguageAvailable(locale) != true) return false;
    await _tts.stop();
    await _tts.setLanguage(locale);
    // A little slower than normal, for learners.
    await _tts.setSpeechRate(0.42);
    await _tts.speak(text);
    return true;
  }

  Future<void> stop() => _tts.stop();
}
