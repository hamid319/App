import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../common/models/phrase_book.dart';

/// The bundled phrasebook and, per language, which phrases the user knows
/// (kept on the device only).
class PhraseRepository {
  static const _asset = 'assets/phrases/phrases.json';

  Future<PhraseBook> load() async => PhraseBook.fromJson(
      jsonDecode(await rootBundle.loadString(_asset)) as Map<String, dynamic>);

  String _knownKey(String language) => 'phrases_known_$language';

  Future<Set<String>> known(String language) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_knownKey(language)) ?? const []).toSet();
  }

  Future<void> saveKnown(String language, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_knownKey(language), ids.toList());
  }
}
