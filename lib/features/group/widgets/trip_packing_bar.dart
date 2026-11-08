import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/group_model.dart';
import '../../../common/utils/suitcase_progress.dart';
import '../../../common/widgets/suitcase_view.dart';
import '../../../core/constants/sizes.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';
import 'idea_sheet.dart';
import 'trip_members_sheet.dart';
import 'trip_ui.dart';

/// "Suitcase 50 % packed": how far the trip's planning is, with the next
/// step to tap. The handle pulls out as the trip gets packed. Uses only data the
/// trip screen already loads.
class TripPackingBar extends ConsumerWidget {
  const TripPackingBar({
    super.key,
    required this.group,
    required this.uid,
    required this.ideas,
  });

  final GroupModel group;
  final String uid;
  final int ideas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final swiped =
        (ref.watch(tripSwipesProvider(group.groupId)).value ?? const [])
            .any((s) => s.uid == uid && s.votes.isNotEmpty);
    final steps = tripPacking(
      members: group.members.length,
      swiped: swiped,
      ideas: ideas,
      hasDayPlan: !(group.tripPlan?.isEmpty ?? true),
    );
    final done = steps.values.where((d) => d).length;
    final progress = done / steps.length;
    final next = steps.entries.where((e) => !e.value).firstOrNull?.key;

    final (String? label, VoidCallback? onTap) = switch (next) {
      TripPackStep.friends => (
          l10n.tripPackFriends,
          () => copyTripInvite(context, group)
        ),
      TripPackStep.swipe => (
          l10n.tripPackSwipe,
          () => context.push('/trip/${group.groupId}/swipe')
        ),
      TripPackStep.wishlist => (
          l10n.tripPackWishlist,
          () => showIdeaSheet(context, group)
        ),
      // The floating button below builds the plan.
      TripPackStep.dayPlan => (l10n.tripPackDayPlan, null),
      null => (null, null),
    };

    return InsetGroup(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.space12, AppSizes.space12, AppSizes.space16, 14),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    builder: (_, p, __) => CustomPaint(
                      painter: SuitcasePainter(handleOut: p),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next == null
                            ? l10n.tripPackDone
                            : l10n.tripPackTitle((progress * 100).round()),
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                      if (label != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.tripPackNext(label),
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
