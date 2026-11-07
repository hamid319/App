import 'package:meta/meta.dart';

/// Topic a phrase belongs to; the order here is the order on screen.
enum PhraseCategory { basics, food, shopping, directions, emergency }

/// One everyday phrase, with its meaning in the app languages.
@immutable
class Phrase {
  final String id;
  final PhraseCategory category;

  /// Meaning per app language ('en', 'de'); may contain `{name}`.
  final Map<String, String> meaning;

  const Phrase(
      {required this.id, required this.category, required this.meaning});

  String meaningIn(String appLanguage) =>
      meaning[appLanguage] ?? meaning['en']!;
}

/// A phrase in a target language: the text and, for non-Latin scripts,
/// how to say it.
@immutable
class PhraseTranslation {
  final String text;
  final String? romanization;

  const PhraseTranslation(this.text, [this.romanization]);
}

/// A language of the phrasebook.
@immutable
class PhraseLanguage {
  final String code;

  /// Locale for text to speech, e.g. 'ja-JP'.
  final String ttsLocale;
  final String nativeName;
  final Map<String, String> name;
  final bool rtl;

  /// ISO country codes where this language is spoken.
  final List<String> countries;

  /// Phrase id → translation; a missing id is left out for this language.
  final Map<String, PhraseTranslation> translations;

  const PhraseLanguage({
    required this.code,
    required this.ttsLocale,
    required this.nativeName,
    required this.name,
    required this.rtl,
    required this.countries,
    required this.translations,
  });

  String nameIn(String appLanguage) => name[appLanguage] ?? name['en']!;
}

/// The whole bundled phrasebook (`assets/phrases/phrases.json`).
@immutable
class PhraseBook {
  final List<Phrase> phrases;
  final List<PhraseLanguage> languages;

  const PhraseBook({required this.phrases, required this.languages});

  factory PhraseBook.fromJson(Map<String, dynamic> json) {
    return PhraseBook(
      phrases: [
        for (final p in json['phrases'] as List)
          Phrase(
            id: p['id'] as String,
            category: PhraseCategory.values.byName(p['cat'] as String),
            meaning: {'en': p['en'] as String, 'de': p['de'] as String},
          ),
      ],
      languages: [
        for (final l in json['languages'] as List)
          PhraseLanguage(
            code: l['code'] as String,
            ttsLocale: l['tts'] as String,
            nativeName: l['native'] as String,
            name: Map<String, String>.from(l['name'] as Map),
            rtl: l['rtl'] as bool? ?? false,
            countries: List<String>.from(l['countries'] as List),
            translations: {
              for (final MapEntry(:key, :value)
                  in (l['t'] as Map<String, dynamic>).entries)
                key: PhraseTranslation((value as List)[0] as String,
                    value.length > 1 ? value[1] as String : null),
            },
          ),
      ],
    );
  }

  PhraseLanguage? language(String code) =>
      languages.where((l) => l.code == code).firstOrNull;

  /// The language spoken in [countryCode], or null if the book has none.
  PhraseLanguage? languageForCountry(String countryCode) => languages
      .where((l) => l.countries.contains(countryCode.toUpperCase()))
      .firstOrNull;

  /// Phrases [language] has a translation for, in book order.
  List<Phrase> phrasesFor(PhraseLanguage language) =>
      phrases.where((p) => language.translations.containsKey(p.id)).toList();
}

/// Puts [name] into a phrase's `{name}` slot.
String fillName(String text, String name) => text.replaceAll('{name}', name);
