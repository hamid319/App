import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/phrase_book.dart';
import '../../../core/constants/sizes.dart';
import '../../../l10n/l10n.dart';
import '../logic/phrase_controller.dart';
import 'phrasebook_screen.dart';

/// Flashcards: the meaning first, the phrase on "show answer". "I know it"
/// marks the phrase as learned, "again" puts it at the back of the queue.
class PhrasePracticeScreen extends ConsumerStatefulWidget {
  const PhrasePracticeScreen({super.key, required this.language});

  final String language;

  @override
  ConsumerState<PhrasePracticeScreen> createState() =>
      _PhrasePracticeScreenState();
}

class _PhrasePracticeScreenState extends ConsumerState<PhrasePracticeScreen> {
  /// Phrases still to go; null until the book and known ids are loaded.
  List<Phrase>? _queue;
  int _total = 0;
  bool _revealed = false;

  Future<void> _start() async {
    final book = await ref.read(phraseBookProvider.future);
    final lang = book.language(widget.language) ?? book.language('en')!;
    final known = await ref.read(knownPhrasesProvider(lang.code).future);
    final all = book.phrasesFor(lang)..shuffle();
    // Practise what is not learned yet; once all are, go through all again.
    final open = all.where((p) => !known.contains(p.id)).toList();
    final queue = open.isEmpty ? all : open;
    if (mounted) {
      setState(() {
        _queue = queue;
        _total = queue.length;
        _revealed = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _answer(PhraseLanguage lang, bool knowIt) {
    final phrase = _queue!.first;
    if (knowIt) {
      ref
          .read(knownPhrasesProvider(lang.code).notifier)
          .setKnown(phrase.id, true);
    }
    setState(() {
      _queue = [..._queue!.skip(1), if (!knowIt) phrase];
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appLanguage(context);
    final book = ref.watch(phraseBookProvider).value;
    final lang = book?.language(widget.language) ?? book?.language('en');
    final queue = _queue;

    return Scaffold(
      appBar: AppBar(title: Text(lang?.nameIn(app) ?? '')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenEdge),
          child: lang == null || queue == null
              ? const Center(child: CircularProgressIndicator())
              : queue.isEmpty
                  ? _Done(total: _total, onRestart: _start)
                  : _Card(
                      phrase: queue.first,
                      lang: lang,
                      progress: (_total - queue.length) / _total,
                      revealed: _revealed,
                      onReveal: () {
                        setState(() => _revealed = true);
                        final t = lang.translations[queue.first.id]!;
                        speakPhrase(context, ref, lang,
                            fillName(t.text, userFirstName(ref) ?? ''));
                      },
                      onAnswer: (knowIt) => _answer(lang, knowIt),
                    ),
        ),
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({
    required this.phrase,
    required this.lang,
    required this.progress,
    required this.revealed,
    required this.onReveal,
    required this.onAnswer,
  });

  final Phrase phrase;
  final PhraseLanguage lang;
  final double progress;
  final bool revealed;
  final VoidCallback onReveal;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final app = appLanguage(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final t = lang.translations[phrase.id]!;
    final name = userFirstName(ref) ?? l10n.phrasesYourName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
            value: progress, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: AppSizes.space8),
        Text(categoryLabel(l10n, phrase.category),
            style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: AppSizes.space16),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.space24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.phrasesHowToSay(lang.nameIn(app)),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: AppSizes.space8),
                  Text(fillName(phrase.meaningIn(app), name),
                      textAlign: TextAlign.center, style: text.headlineSmall),
                  if (revealed) ...[
                    const Divider(height: AppSizes.space32 * 2),
                    Text(fillName(t.text, name),
                        textAlign: TextAlign.center,
                        textDirection: lang.rtl ? TextDirection.rtl : null,
                        style: text.headlineMedium
                            ?.copyWith(color: scheme.primary)),
                    if (t.romanization != null) ...[
                      const SizedBox(height: AppSizes.space8),
                      Text(fillName(t.romanization!, name),
                          textAlign: TextAlign.center, style: text.bodyLarge),
                    ],
                    const SizedBox(height: AppSizes.space8),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded),
                      tooltip: l10n.phrasesListen,
                      onPressed: () => speakPhrase(context, ref, lang,
                          fillName(t.text, userFirstName(ref) ?? '')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!revealed)
          FilledButton(onPressed: onReveal, child: Text(l10n.phrasesShowAnswer))
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => onAnswer(false),
                    child: Text(l10n.phrasesAgain)),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: FilledButton(
                    onPressed: () => onAnswer(true),
                    child: Text(l10n.phrasesKnowIt)),
              ),
            ],
          ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.total, required this.onRestart});

  final int total;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration_rounded,
              size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: AppSizes.space16),
          Text(l10n.phrasesDoneTitle, style: text.headlineSmall),
          const SizedBox(height: AppSizes.space8),
          Text(l10n.phrasesDoneBody(total), textAlign: TextAlign.center),
          const SizedBox(height: AppSizes.space24),
          FilledButton(onPressed: onRestart, child: Text(l10n.phrasesRestart)),
        ],
      ),
    );
  }
}
