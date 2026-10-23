import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../common/models/place_review.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../auth/logic/auth_controller.dart';
import '../logic/review_controller.dart';
import 'review_sheet.dart';

/// Reviews on the place detail page: the average (from
/// [ReviewSummary.minCountForAverage] reviews on), a button to write or
/// edit one's own review, and the latest visible reviews.
class PlaceReviewsSection extends ConsumerWidget {
  const PlaceReviewsSection({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).value;
    final signedIn = user != null && !user.isAnonymous;
    final summary =
        ref.watch(reviewSummaryProvider(placeId)).value ?? ReviewSummary.empty;
    final mine = ref.watch(myReviewProvider(placeId)).value;
    final reviews = ref.watch(placeReviewsProvider(placeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.reviewsTitle, style: text.titleLarge),
        const SizedBox(height: AppSizes.space8),
        _SummaryLine(summary: summary),
        const SizedBox(height: AppSizes.space12),
        OutlinedButton.icon(
          icon: Icon(signedIn
              ? (mine == null ? Icons.rate_review_outlined : Icons.edit_outlined)
              : Icons.login_rounded),
          label: Text(!signedIn
              ? l10n.reviewSignInToWrite
              : mine == null
                  ? l10n.reviewWrite
                  : l10n.reviewEdit),
          onPressed: signedIn
              ? () => showReviewSheet(context, placeId: placeId, existing: mine)
              : () => context.push('/login'),
        ),
        ...reviews.when(
          data: (list) => [
            for (final review in list) ...[
              const SizedBox(height: AppSizes.space16),
              _ReviewTile(
                review: review,
                isMine: review.uid == user?.uid,
                canReport: signedIn && review.uid != user.uid,
              ),
            ],
          ],
          loading: () => const [],
          error: (_, __) => [
            const SizedBox(height: AppSizes.space12),
            Text(l10n.errorLoadReviews,
                style: text.bodyMedium?.copyWith(color: scheme.error)),
          ],
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final style =
        Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    if (summary.count == 0) return Text(l10n.reviewsNone, style: style);
    if (!summary.showsAverage) return Text(l10n.reviewsFew, style: style);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final average = NumberFormat('0.0', locale).format(summary.average);
    return Row(
      children: [
        _Stars(rating: summary.average!.round(), size: 20),
        const SizedBox(width: AppSizes.space8),
        Text(
          average,
          style: style?.copyWith(
              color: scheme.onSurface, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: AppSizes.space8),
        Text(l10n.reviewsCount(summary.count), style: style),
      ],
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({
    required this.review,
    required this.isMine,
    required this.canReport,
  });

  final PlaceReview review;
  final bool isMine;
  final bool canReport;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reviewReportTitle),
        content: Text(l10n.reviewReportBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reviewReport),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(reviewControllerProvider.notifier).report(review);
      messenger.showSnackBar(SnackBar(content: Text(l10n.reviewReported)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(userMessage(e, fallback: l10n.errorSaveReview, l10n: l10n)),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = review.updatedAt ?? review.createdAt;
    final author = isMine
        ? l10n.reviewYou
        : review.authorName.isNotEmpty
            ? review.authorName
            : l10n.reviewAnonymousAuthor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(author,
                  style: text.titleSmall, overflow: TextOverflow.ellipsis),
            ),
            if (date != null)
              Text(DateFormat.yMMMd(locale).format(date),
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            if (canReport)
              PopupMenuButton<void>(
                iconSize: 20,
                padding: EdgeInsets.zero,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: () => _report(context, ref),
                    child: Text(l10n.reviewReport),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSizes.space4),
        _Stars(rating: review.rating, size: 16),
        if (review.text.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space4),
          Text(review.text,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.size});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.reviewStarsLabel(rating),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var star = 1; star <= 5; star++)
              Icon(
                star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: star <= rating
                    ? context.swipeColors.gold
                    : scheme.outlineVariant,
              ),
          ],
        ),
      ),
    );
  }
}
