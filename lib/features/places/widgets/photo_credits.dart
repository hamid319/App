import 'package:flutter/material.dart';

import '../../../common/models/photo_credit.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/link_launcher.dart';
import '../../../l10n/l10n.dart';

String _authorOf(AppLocalizations l10n, PhotoCredit credit) =>
    credit.author ?? l10n.photoCreditUnknownAuthor;

String _sourceName(AppLocalizations l10n, PhotoCredit credit) =>
    switch (credit.source) {
      PhotoSource.google => l10n.photoCreditGoogle,
      PhotoSource.wikimedia => l10n.photoCreditWikimedia,
    };

/// Small glass chip on the photo naming the author of the visible photo,
/// e.g. "Photo: Jane Doe · CC BY-SA 4.0". Tapping lists all credits.
class PhotoCreditChip extends StatelessWidget {
  const PhotoCreditChip({super.key, required this.credits});

  final List<PhotoCredit> credits;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = credits.first;
    final suffix = first.licenseName ?? _sourceName(l10n, first);
    final label = '${l10n.photoCreditShort(_authorOf(l10n, first))} · $suffix';
    return Semantics(
      button: true,
      label: l10n.photoCreditsTitle,
      child: Material(
        color: PhotoColors.chip,
        shape: const StadiumBorder(
            side: BorderSide(color: PhotoColors.chipBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showPhotoCredits(context, credits),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copyright_rounded,
                    size: 13, color: Colors.white),
                const SizedBox(width: 5),
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing author, licence and source of every photo.
Future<void> showPhotoCredits(BuildContext context, List<PhotoCredit> credits) {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  Future<void> open(String url) async {
    try {
      await LinkLauncher.open(url);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(userMessage(e, fallback: l10n.errorOpenLink, l10n: l10n)),
        ),
      );
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final text = Theme.of(sheetContext).textTheme;
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenEdge,
              0,
              AppSizes.screenEdge,
              AppSizes.space24,
            ),
            children: [
              Text(l10n.photoCreditsTitle, style: text.titleLarge),
              const SizedBox(height: AppSizes.space4),
              Text(
                l10n.photoCreditsHint,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              for (final (index, credit) in credits.indexed) ...[
                const SizedBox(height: AppSizes.space16),
                if (credits.length > 1)
                  Text(
                    l10n.photoCreditNumber(index + 1).toUpperCase(),
                    style: text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                _CreditLink(
                  label: _authorOf(l10n, credit),
                  url: credit.authorUrl,
                  onOpen: open,
                  style: text.titleMedium,
                ),
                Wrap(
                  spacing: AppSizes.space12,
                  children: [
                    if (credit.licenseName != null)
                      _CreditLink(
                        label: credit.licenseName!,
                        url: credit.licenseUrl,
                        onOpen: open,
                      ),
                    _CreditLink(
                      label: _sourceName(l10n, credit),
                      url: credit.sourceUrl,
                      onOpen: open,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Text that becomes an underlined link when [url] is set.
class _CreditLink extends StatelessWidget {
  const _CreditLink({
    required this.label,
    required this.url,
    required this.onOpen,
    this.style,
  });

  final String label;
  final String? url;
  final Future<void> Function(String url) onOpen;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = style ??
        Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant);
    final link = url;
    if (link == null) return Text(label, style: base);
    return InkWell(
      onTap: () => onOpen(link),
      borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: base?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
