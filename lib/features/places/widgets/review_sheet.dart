import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../common/models/place_review.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/review_controller.dart';

/// Lets the signed-in user write, change or delete their review of
/// [placeId]. [existing] fills in their earlier review.
Future<void> showReviewSheet(
  BuildContext context, {
  required String placeId,
  PlaceReview? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ReviewSheet(placeId: placeId, existing: existing),
  );
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.placeId, this.existing});

  final String placeId;
  final PlaceReview? existing;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  bool _busy = false;
  bool _showRatingError = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await action();
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text(userMessage(e, fallback: l10n.errorSaveReview, l10n: l10n)),
      ));
    }
  }

  void _save() {
    if (_rating == 0) {
      setState(() => _showRatingError = true);
      return;
    }
    final controller = ref.read(reviewControllerProvider.notifier);
    final language = Localizations.localeOf(context).languageCode;
    _run(
      () => controller.save(
        placeId: widget.placeId,
        rating: _rating,
        text: _text.text,
        language: language,
      ),
      context.l10n.reviewSaved,
    );
  }

  void _delete() {
    final controller = ref.read(reviewControllerProvider.notifier);
    _run(() => controller.delete(widget.placeId), context.l10n.reviewDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenEdge,
            0,
            AppSizes.screenEdge,
            AppSizes.space16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.reviewSheetTitle, style: text.titleLarge),
              const SizedBox(height: AppSizes.space12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      iconSize: 40,
                      tooltip: l10n.reviewStarsLabel(star),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _rating = star;
                                _showRatingError = false;
                              }),
                      icon: Icon(
                        star <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: star <= _rating
                            ? context.swipeColors.gold
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (_showRatingError)
                Text(
                  l10n.reviewRatingRequired,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              const SizedBox(height: AppSizes.space12),
              TextField(
                controller: _text,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                maxLength: PlaceReview.maxTextLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: l10n.reviewTextHint),
              ),
              const SizedBox(height: AppSizes.space8),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(l10n.save),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: AppSizes.space8),
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: Text(l10n.reviewDeleteButton),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
