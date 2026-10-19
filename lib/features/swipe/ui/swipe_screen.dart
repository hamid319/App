import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../group/logic/group_controller.dart';
import '../../auth/logic/auth_controller.dart';
import '../logic/swipe_controller.dart';
import '../widgets/swipe_card.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';

/// Main Swipe Screen - displays the card stack and handles state
class SwipeScreen extends ConsumerStatefulWidget {
  final String groupId;
  const SwipeScreen({super.key, required this.groupId});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(selectedGroupIdProvider.notifier).updateState(widget.groupId);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded(DateTime? endTime) {
    if (endTime == null) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      if (now.isAfter(endTime)) {
        timer.cancel();
        setState(() {
          _timeRemaining = Duration.zero;
        });
        _handleTimeUp();
      } else {
        setState(() {
          _timeRemaining = endTime.difference(now);
        });
      }
    });
  }

  void _handleTimeUp() async {
    final session = ref.read(activeSessionProvider).value;
    final currentUser = ref.read(authControllerProvider).value;
    final isAdmin = session?.participants.isNotEmpty == true &&
        session!.participants.first == currentUser?.uid;

    if (isAdmin) {
      try {
        await ref.read(groupControllerProvider.notifier).endSession();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(swipeControllerProvider);
    final ctrl = ref.read(swipeControllerProvider.notifier);
    final session = ref.watch(activeSessionProvider);
    final sessionValue = session.value;
    final currentUser = ref.watch(authControllerProvider).value;
    final isAdmin = sessionValue?.participants.isNotEmpty == true &&
        sessionValue!.participants.first == currentUser?.uid;

    ref.listen(activeSessionProvider, (prev, next) {
      if (next.value?.isCompleted == true) {
        context.go('/group-matches/${widget.groupId}');
      } else if (next.value?.endTime != null && _timer == null) {
        _startTimerIfNeeded(next.value!.endTime);
        setState(() {
          _timeRemaining = next.value!.endTime!.difference(DateTime.now());
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
                child: Text(sessionValue?.destination ?? context.l10n.discoverTitle)),
            if (sessionValue?.endTime != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_timeRemaining.inMinutes.toString().padLeft(2, '0')}:${(_timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (isAdmin)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(context.l10n.endSessionTitle),
                    content: Text(
                      context.l10n.endSessionBody,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(context.l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(context.l10n.end),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(groupControllerProvider.notifier).endSession();
                }
              },
              child: Text(context.l10n.endSession),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Badge(
                label: Text('${ctrl.favoritesList.length}'),
                child: const Icon(Icons.favorite),
              ),
            ),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(userMessage(e, fallback: context.l10n.errorLoadPlaces, l10n: context.l10n)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(swipeControllerProvider),
                child: Text(context.l10n.tryAgain),
              ),
            ],
          ),
        ),
        data: (places) {
          final current = ctrl.currentPlace;
          if (current == null ||
              (sessionValue?.endTime != null &&
                  _timeRemaining <= Duration.zero)) {
            // No more places to show or time is up
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 80, color: Colors.green),
                  const SizedBox(height: 24),
                  Text(
                    (sessionValue?.endTime != null &&
                            _timeRemaining <= Duration.zero)
                        ? context.l10n.timeIsUp
                        : context.l10n.noMorePlacesTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (sessionValue?.endTime != null &&
                            _timeRemaining <= Duration.zero)
                        ? context.l10n.waitingForSessionEnd
                        : context.l10n.viewedAllPlaces,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
                  if (sessionValue?.endTime == null ||
                      _timeRemaining > Duration.zero)
                    ElevatedButton.icon(
                      onPressed: () => ref.refresh(swipeControllerProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.reload),
                    ),
                ],
              ),
            );
          }

          // Build the swipeable card stack
          return TinderSwipeCardStack(
            place: current,
            onLike: () {
              // In a group session a like only casts a vote; it is not
              // saved to the user's favorites.
              final inSession =
                  ref.read(activeSessionProvider).value != null;
              ctrl.like();
              _showSnackBar(
                context,
                inSession ? context.l10n.liked : context.l10n.addedToFavorites,
                Colors.green,
              );
            },
            onSkip: () {
              ctrl.skip();
              _showSnackBar(context, context.l10n.skipped, Colors.orange);
            },
            onDetail: () {
              context.push('/place/${current.id}');
            },
          );
        },
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
