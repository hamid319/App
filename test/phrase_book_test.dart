import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/phrase_book.dart';

void main() {
  final book = PhraseBook.fromJson(
      jsonDecode(File('assets/phrases/phrases.json').readAsStringSync())
          as Map<String, dynamic>);

  test('20 languages, each with every phrase (English skips "speak English")',
      () {
    expect(book.languages, hasLength(20));
    for (final lang in book.languages) {
      final missing = book.phrases
          .map((p) => p.id)
          .where((id) => !lang.translations.containsKey(id))
          .toList();
      expect(missing, lang.code == 'en' ? ['speakEnglish'] : isEmpty,
          reason: lang.code);
      expect(
          lang.translations.keys
              .toSet()
              .difference(book.phrases.map((p) => p.id).toSet()),
          isEmpty,
          reason: '${lang.code}: unknown phrase ids');
    }
  });

  test('the name phrase keeps its {name} slot everywhere', () {
    for (final lang in book.languages) {
      final t = lang.translations['name']!;
      expect(t.text, contains('{name}'), reason: lang.code);
      if (t.romanization != null) {
        expect(t.romanization, contains('{name}'), reason: lang.code);
      }
    }
    expect(fillName('Ich heiße {name}', 'Hamid'), 'Ich heiße Hamid');
  });

  test('each country maps to one language', () {
    final seen = <String, String>{};
    for (final lang in book.languages) {
      for (final c in lang.countries) {
        expect(seen[c], isNull, reason: '$c in ${seen[c]} and ${lang.code}');
        seen[c] = lang.code;
      }
    }
    expect(book.languageForCountry('jp')?.code, 'ja');
    expect(book.languageForCountry('AT')?.code, 'de');
    expect(book.languageForCountry('XX'), isNull);
  });
}
