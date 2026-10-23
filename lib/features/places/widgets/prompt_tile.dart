import 'package:flutter/material.dart';

import '../../../common/models/place_prompt.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../l10n/l10n.dart';

String placePromptLabel(AppLocalizations l10n, PlacePromptKind kind) =>
    switch (kind) {
      PlacePromptKind.bestTime => l10n.promptBestTime,
      PlacePromptKind.insiderTip => l10n.promptInsiderTip,
      PlacePromptKind.dontMiss => l10n.promptDontMiss,
      PlacePromptKind.goodFor => l10n.promptGoodFor,
      PlacePromptKind.funFact => l10n.promptFunFact,
    };

/// A short question with a personal answer, e.g. "Best time – just before
/// sunset". Gives a reason to like a place instead of a list of facts.
class PromptTile extends StatelessWidget {
  const PromptTile({super.key, required this.prompt});

  final PlacePrompt prompt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = placePromptLabel(context.l10n, prompt.kind);
    final answer = prompt.textFor(Localizations.localeOf(context).languageCode);
    return Ticket(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.space16,
        AppSizes.space12,
        AppSizes.space16,
        AppSizes.space16,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            Text(answer, style: AppTypography.prompt(scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
