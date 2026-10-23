import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/group_session_model.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../l10n/l10n.dart';
import '../logic/group_controller.dart';

/// Live progress of the running session: your own count large on top, then
/// every participant with a bar, so the group sees who is still swiping.
class SessionProgressPanel extends ConsumerWidget {
  const SessionProgressPanel({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).value;
    if (session == null || session.isCompleted) return const SizedBox.shrink();

    final limit = session.swipeLimit ?? session.totalPlacesToSwipe;
    final progress = session.progressByUser ?? session.swipeProgress;
    int countFor(String uid) => (progress[uid] ?? 0).clamp(0, limit);
    final mine = countFor(userId);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;

    // Sits inside the group screen's 16 px edges, so no side padding here.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            l10n.sessionLive,
            trailing: session.endTime == null
                ? null
                : _TimeLeft(endTime: session.endTime!),
          ),
          Ticket(
            notchFromTop: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 76,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.space16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$mine', style: text.headlineMedium),
                            Text(
                              ' / $limit',
                              style: text.titleMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const Spacer(),
                            Text(
                              l10n.yourProgress,
                              style: text.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.space8),
                        _Bar(value: limit == 0 ? 0 : mine / limit, height: 8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSizes.space16,
                      AppSizes.space12, AppSizes.space16, AppSizes.space8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.whoIsSwiping, style: text.titleSmall),
                      for (final uid in session.participants)
                        _MemberProgress(
                          uid: uid,
                          isMe: uid == userId,
                          count: countFor(uid),
                          limit: limit,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberProgress extends ConsumerWidget {
  const _MemberProgress({
    required this.uid,
    required this.isMe,
    required this.count,
    required this.limit,
  });

  final String uid;
  final bool isMe;
  final int count;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name =
        friendlyMemberName(ref.watch(groupMemberNameProvider(uid)).value) ??
            '…';
    final done = limit > 0 && count >= limit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.space8),
      child: Row(
        children: [
          MemberAvatar(id: uid, name: name),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? l10n.memberYou(name) : name,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSizes.space4),
                _Bar(value: limit == 0 ? 0 : count / limit, height: 5),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space12),
          if (done)
            TagChip(
              label: l10n.memberDone,
              tone: ChipTone.mint,
              icon: Icons.check_rounded,
            )
          else
            Text(
              '$count/$limit',
              style: text.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.height});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: scheme.surfaceContainerHighest,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

/// "18 min left", refreshed every 30 seconds.
class _TimeLeft extends StatefulWidget {
  const _TimeLeft({required this.endTime});

  final DateTime endTime;

  @override
  State<_TimeLeft> createState() => _TimeLeftState();
}

class _TimeLeftState extends State<_TimeLeft> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endTime.difference(DateTime.now());
    final minutes = left.isNegative ? 0 : (left.inSeconds / 60).ceil();
    return Text(
      context.l10n.sessionTimeLeft(minutes),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

/// Exposed for tests: how far a participant is, capped at the limit.
@visibleForTesting
double sessionProgressFor(GroupSessionModel session, String uid) {
  final limit = session.swipeLimit ?? session.totalPlacesToSwipe;
  if (limit == 0) return 0;
  final progress = session.progressByUser ?? session.swipeProgress;
  return ((progress[uid] ?? 0) / limit).clamp(0.0, 1.0);
}
