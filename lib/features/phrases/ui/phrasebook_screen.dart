import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/phrase_book.dart';
import '../../../common/widgets/error_view.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/services/link_launcher.dart';
import '../../../l10n/l10n.dart';
import '../../../main_providers.dart';
import '../logic/phrase_controller.dart';

/// Everyday phrases in one language, read aloud on tap, plus a shortcut to
/// translate a photo (menu, label) with Google Translate.
class PhrasebookScreen extends ConsumerWidget {
  const PhrasebookScreen({super.key, this.language, this.country});

  /// Language code to show; wins over [country].
  final String? language;

  /// Trip country (ISO code); picks the language spoken there.
  final String? country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final book = ref.watch(phraseBookProvider);
    return book.when(
      loading: () => Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
            message: l10n.phrasesLoadError,
            onRetry: () => ref.invalidate(phraseBookProvider)),
      ),
      data: (book) {
        final lang = (language != null ? book.language(language!) : null) ??
            (country != null ? book.languageForCountry(country!) : null) ??
            book.language('en')!;
        return _Phrasebook(book: book, lang: lang);
      },
    );
  }
}

/// The app language the meanings are shown in ('en' or 'de').
String appLanguage(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

/// The signed-in user's first name for "My name is …", or null.
String? userFirstName(WidgetRef ref) {
  final name = ref.read(authServiceProvider).currentUser?.displayName?.trim();
  return name == null || name.isEmpty ? null : name.split(' ').first;
}

/// Reads [text] aloud; tells the user when the device has no such voice.
Future<void> speakPhrase(BuildContext context, WidgetRef ref,
    PhraseLanguage lang, String text) async {
  final l10n = context.l10n;
  final app = appLanguage(context);
  final ok = await ref.read(speechServiceProvider).speak(text, lang.ttsLocale);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.phrasesNoVoice(lang.nameIn(app)))));
  }
}

class _Phrasebook extends ConsumerWidget {
  const _Phrasebook({required this.book, required this.lang});

  final PhraseBook book;
  final PhraseLanguage lang;

  Future<void> _openPhotoTranslate(BuildContext context) async {
    final l10n = context.l10n;
    final base = Uri.parse(AppConfig.photoTranslateUrl);
    final uri = base.replace(queryParameters: {
      ...base.queryParameters,
      'tl': appLanguage(context),
    });
    try {
      await LinkLauncher.open(uri.toString());
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.photoTranslateError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final app = appLanguage(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final phrases = book.phrasesFor(lang);
    final known =
        ref.watch(knownPhrasesProvider(lang.code)).value ?? const <String>{};
    final learned = phrases.where((p) => known.contains(p.id)).length;
    final name = userFirstName(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.nameIn(app)),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate_rounded),
            tooltip: l10n.phrasesChangeLanguage,
            onPressed: () => _pickLanguage(context, book, lang),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSizes.screenEdge, AppSizes.space8,
            AppSizes.screenEdge, AppSizes.space32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: scheme.primary),
              title: Text(l10n.photoTranslateTitle),
              subtitle: Text(l10n.photoTranslateSubtitle),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => _openPhotoTranslate(context),
            ),
          ),
          const SizedBox(height: AppSizes.space16),
          Text(l10n.phrasesProgress(learned, phrases.length),
              style: text.labelLarge),
          const SizedBox(height: AppSizes.space4),
          LinearProgressIndicator(
            value: phrases.isEmpty ? 0 : learned / phrases.length,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSizes.space12),
          FilledButton.icon(
            onPressed: () => context.push(Uri(
                path: '/phrases/practice',
                queryParameters: {'lang': lang.code}).toString()),
            icon: const Icon(Icons.school_outlined, size: 20),
            label: Text(l10n.phrasesPractice),
          ),
          for (final category in PhraseCategory.values)
            if (phrases.any((p) => p.category == category)) ...[
              const SizedBox(height: AppSizes.groupGap),
              Text(categoryLabel(l10n, category), style: text.titleMedium),
              const SizedBox(height: AppSizes.space8),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final p
                        in phrases.where((p) => p.category == category))
                      _PhraseTile(
                        phrase: p,
                        lang: lang,
                        name: name,
                        known: known.contains(p.id),
                      ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

String categoryLabel(AppLocalizations l10n, PhraseCategory c) => switch (c) {
      PhraseCategory.basics => l10n.phrasesCatBasics,
      PhraseCategory.food => l10n.phrasesCatFood,
      PhraseCategory.shopping => l10n.phrasesCatShopping,
      PhraseCategory.directions => l10n.phrasesCatDirections,
      PhraseCategory.emergency => l10n.phrasesCatEmergency,
    };

class _PhraseTile extends ConsumerWidget {
  const _PhraseTile({
    required this.phrase,
    required this.lang,
    required this.name,
    required this.known,
  });

  final Phrase phrase;
  final PhraseLanguage lang;
  final String? name;
  final bool known;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final t = lang.translations[phrase.id]!;
    final shownName = name ?? l10n.phrasesYourName;
    final meaning = fillName(phrase.meaningIn(appLanguage(context)), shownName);

    return ListTile(
      onTap: () =>
          speakPhrase(context, ref, lang, fillName(t.text, name ?? '')),
      leading: IconButton(
        icon: Icon(known ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: known ? scheme.primary : scheme.outline),
        tooltip: l10n.phrasesMarkKnown,
        onPressed: () => ref
            .read(knownPhrasesProvider(lang.code).notifier)
            .setKnown(phrase.id, !known),
      ),
      title: Text(fillName(t.text, shownName),
          textDirection: lang.rtl ? TextDirection.rtl : null,
          style: text.titleMedium),
      subtitle: Text(
        [
          if (t.romanization != null) fillName(t.romanization!, shownName),
          meaning
        ].join('\n'),
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.volume_up_rounded,
          semanticLabel: l10n.phrasesListen, color: scheme.primary),
    );
  }
}

Future<void> _pickLanguage(
    BuildContext context, PhraseBook book, PhraseLanguage current) async {
  final app = appLanguage(context);
  final languages = [...book.languages]
    ..sort((a, b) => a.nameIn(app).compareTo(b.nameIn(app)));
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (ctx, controller) => ListView(
        controller: controller,
        children: [
          for (final l in languages)
            ListTile(
              title: Text(l.nameIn(app)),
              subtitle: Text(l.nativeName),
              trailing: l.code == current.code
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.of(ctx).pop(l.code),
            ),
        ],
      ),
    ),
  );
  if (picked != null && picked != current.code && context.mounted) {
    context.replace(
        Uri(path: '/phrases', queryParameters: {'lang': picked}).toString());
  }
}
