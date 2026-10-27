import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/group_controller.dart';
import 'trip_ui.dart';

/// Swipe limits the admin can step through when starting a session.
const _swipeLimitSteps = [5, 10, 15, 20, 25, 30, 40, 50];

/// Time limits (minutes) the admin can step through.
const _timeLimitSteps = [1, 2, 3, 5, 10, 15, 20, 30, 45, 60];

/// Admin sheet to start a group swipe round for the selected trip
/// ([selectedGroupIdProvider]). Returns true once the session started.
Future<bool> showStartSessionSheet(BuildContext context) async {
  final started = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _StartSessionSheet(),
  );
  return started == true;
}

class _StartSessionSheet extends ConsumerStatefulWidget {
  const _StartSessionSheet();

  @override
  ConsumerState<_StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends ConsumerState<_StartSessionSheet> {
  int _swipeLimit = 10;
  int _timeLimit = 5;
  bool _isTimeLimit = false;
  bool _busy = false;

  Future<void> _start() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(groupControllerProvider.notifier).startSessionWithLimit(
            // A large limit when the round is timed.
            swipeLimit: _isTimeLimit ? 100 : _swipeLimit,
            durationMinutes: _isTimeLimit ? _timeLimit : null,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showTripSnack(
        context,
        userMessage(e, fallback: l10n.errorStartSession, l10n: l10n),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.tripSwipeTitle, style: text.headlineSmall),
          const SizedBox(height: 4),
          Text(
            l10n.tripSwipeSheetBody,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SessionSetup(
            isTimeLimit: _isTimeLimit,
            value: _isTimeLimit ? _timeLimit : _swipeLimit,
            onModeChanged: (time) => setState(() => _isTimeLimit = time),
            onValueChanged: (v) => setState(() {
              if (_isTimeLimit) {
                _timeLimit = v;
              } else {
                _swipeLimit = v;
              }
            }),
          ),
          const SizedBox(height: 20),
          FloatingPrimaryButton(
            label: l10n.startSession,
            icon: Icons.play_arrow_rounded,
            loading: _busy,
            onPressed: _start,
          ),
        ],
      ),
    );
  }
}

/// Compact session setup: limit type plus a stepper for its value.
class SessionSetup extends StatelessWidget {
  const SessionSetup({
    super.key,
    required this.isTimeLimit,
    required this.value,
    required this.onModeChanged,
    required this.onValueChanged,
  });

  final bool isTimeLimit;
  final int value;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int> onValueChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final steps = isTimeLimit ? _timeLimitSteps : _swipeLimitSteps;
    final index = steps.indexOf(value);
    final label = isTimeLimit
        ? l10n.sessionMinutesValue(value)
        : l10n.sessionSwipesValue(value);

    return TripCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TripSegmentedControl(
              segments: [
                TripSegment(l10n.limitSwipes),
                TripSegment(l10n.limitTimeShort),
              ],
              selected: isTimeLimit ? 1 : 0,
              onSelected: (i) => onModeChanged(i == 1),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.sessionLimitLess,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed:
                index > 0 ? () => onValueChanged(steps[index - 1]) : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.sessionLimitMore,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: index >= 0 && index < steps.length - 1
                ? () => onValueChanged(steps[index + 1])
                : null,
          ),
        ],
      ),
    );
  }
}
