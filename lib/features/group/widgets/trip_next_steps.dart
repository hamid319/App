import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../common/models/group_model.dart';
import '../../../core/constants/colors.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../../../main_providers.dart';
import '../logic/group_controller.dart';
import 'trip_members_sheet.dart';
import 'trip_ui.dart';

/// What is worth doing before the next trip, under its card on the trips
/// tab. Dates and invite tick themselves off from the trip document; swipe
/// and packing stay plain links, since checking them would cost reads.
class TripNextSteps extends ConsumerWidget {
  const TripNextSteps({super.key, required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final uid = ref.watch(currentAccountProvider).value?.uid;
    final id = group.groupId;
    final steps = [
      // Only the owner may change the dates.
      if (group.ownerUid == uid || group.tripStart != null)
        _Step(
          icon: Icons.calendar_month_outlined,
          title: l10n.tripStepDates,
          subtitle: l10n.tripStepDatesBody,
          done: group.tripStart != null,
          onTap: () => _pickDates(context, ref),
        ),
      _Step(
        icon: Icons.person_add_alt_1_outlined,
        title: l10n.tripInviteFriends,
        subtitle: l10n.tripStepInviteBody,
        done: group.members.length > 1,
        onTap: () => copyTripInvite(context, group),
      ),
      _Step(
        icon: Icons.swipe_rounded,
        title: l10n.tripStepSwipe,
        subtitle: l10n.tripStepSwipeBody,
        onTap: () => context.push('/trip/$id/swipe'),
      ),
      _Step(
        icon: Icons.luggage_outlined,
        title: l10n.tripStepPacking,
        subtitle: l10n.tripStepPackingBody,
        onTap: () => context.push('/trip/$id/packing'),
      ),
    ];
    // What is left to do first, what is done below it.
    final ordered = [
      ...steps.where((s) => !s.done),
      ...steps.where((s) => s.done),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TripSectionHeader(l10n.tripNextSteps),
        const SizedBox(height: 8),
        for (final (i, step) in ordered.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 58),
              child: Divider(height: 1, thickness: 1, color: context.pageLine),
            ),
          step,
        ],
      ],
    );
  }

  Future<void> _pickDates(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked == null || !context.mounted) return;
    try {
      await ref
          .read(groupControllerProvider.notifier)
          .setTripDates(group.groupId, picked.start, picked.end);
    } catch (e) {
      if (context.mounted) {
        showTripSnack(
          context,
          userMessage(e, fallback: l10n.errorSaveDates, l10n: l10n),
          error: true,
        );
      }
    }
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.done = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = context.isDarkTabPage;
    const tone = TagTone.done;
    // Rows sit straight on the page, not in a card.
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: done ? null : onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: done ? 56 : 64),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: done
                    ? (dark ? tone.darkFill : tone.fill)
                    : context.pageFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                done ? Icons.check_rounded : icon,
                size: 22,
                color: done ? (dark ? tone.darkInk : tone.ink) : context.onBg,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: done
                  ? Text(
                      title,
                      style: text.bodyLarge?.copyWith(color: context.onBg2),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              text.titleMedium?.copyWith(color: context.onBg),
                        ),
                        Text(
                          subtitle,
                          style:
                              text.bodyMedium?.copyWith(color: context.onBg2),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            if (done)
              TripTag(context.l10n.tripStepDone, tone: tone)
            else
              Icon(Icons.chevron_right_rounded, color: context.onBg2),
          ],
        ),
      ),
    );
  }
}
