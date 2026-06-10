import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common/models/place_model.dart';
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(selectedGroupIdProvider.notifier).updateState(widget.groupId);
    });
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

    ref.listen(activeSessionProvider, (_, next) {
      if (next.value?.isCompleted == true) {
        context.go('/group-matches/${widget.groupId}');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionValue?.destination ?? 'Discover Places'),
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
          if (current == null) {
            // No more places to show
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 80, color: Colors.green),
                  const SizedBox(height: 24),
                  Text(
                    'No more places!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have viewed all places',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
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
