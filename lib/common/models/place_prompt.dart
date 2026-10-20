import 'package:meta/meta.dart';

/// The question a prompt tile answers. The label is translated in the app;
/// only the answer comes from the data.
enum PlacePromptKind {
  bestTime('bestTime'),
  insiderTip('insiderTip'),
  dontMiss('dontMiss'),
  goodFor('goodFor'),
  funFact('funFact');

  const PlacePromptKind(this.key);

  /// Value stored in Firestore.
  final String key;

  static PlacePromptKind? fromKey(String? key) {
    for (final kind in values) {
      if (kind.key == key) return kind;
    }
    return null;
  }
}

/// A short, personal line about a place, shown as a tile (Hinge style).
///
/// Firestore shape, one entry of `places/{id}.prompts`:
/// `{kind: 'bestTime', text: {en: '...', de: '...'}}`. A plain string is
/// accepted for `text` too and used for every language.
@immutable
class PlacePrompt {
  const PlacePrompt({required this.kind, required this.text});

  final PlacePromptKind kind;

  /// Answer by language code.
  final Map<String, String> text;

  /// Answer in [languageCode], falling back to English, then to any
  /// language that has one.
  String textFor(String languageCode) {
    final exact = text[languageCode]?.trim();
    if (exact != null && exact.isNotEmpty) return exact;
    final english = text['en']?.trim();
    if (english != null && english.isNotEmpty) return english;
    for (final value in text.values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  /// Parses one entry; returns null for unknown kinds or empty answers, so
  /// new kinds written by a newer backend never break an older app.
  static PlacePrompt? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final kind = PlacePromptKind.fromKey(json['kind'] as String?);
    if (kind == null) return null;
    final raw = json['text'];
    final Map<String, String> text;
    if (raw is String) {
      text = {'en': raw};
    } else if (raw is Map) {
      text = {
        for (final entry in raw.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } else {
      return null;
    }
    final prompt = PlacePrompt(kind: kind, text: text);
    return prompt.textFor('en').isEmpty ? null : prompt;
  }

  static List<PlacePrompt> listFromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final entry in json)
        if (tryFromJson(entry) case final prompt?) prompt,
    ];
  }
}
