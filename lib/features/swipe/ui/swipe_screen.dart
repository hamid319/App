import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../group/logic/group_controller.dart';
import '../../auth/logic/auth_controller.dart';
import '../logic/swipe_controller.dart';
import '../widgets/swipe_card.dart';

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
                child: Text(sessionValue?.destination ?? 'Discover Places')),
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
                    title: const Text('End session?'),
                    content: const Text(
                      'This will end the session for all participants.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('End'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(groupControllerProvider.notifier).endSession();
                }
              },
              child: const Text('End session'),
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
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(swipeControllerProvider),
                child: const Text('Try again'),
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
                        ? 'Time is up!'
                        : 'No more places!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (sessionValue?.endTime != null &&
                            _timeRemaining <= Duration.zero)
                        ? 'Waiting for session to end...'
                        : 'You have viewed all places',
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
                      label: const Text('Reload'),
                    ),
                ],
              ),
            );
          }

          // Build the swipeable card stack
          return TinderSwipeCardStack(
            place: current,
            onLike: () {
              ctrl.like();
              _showSnackBar(context, 'Added to favorites!', Colors.green);
            },
            onSkip: () {
              ctrl.skip();
              _showSnackBar(context, 'Skipped', Colors.orange);
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
