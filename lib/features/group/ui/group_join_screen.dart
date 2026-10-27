import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/group_controller.dart';

/// Target of an invite link: joins the trip, then opens it.
class GroupJoinScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String code;

  const GroupJoinScreen({super.key, required this.groupId, required this.code});

  @override
  ConsumerState<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends ConsumerState<GroupJoinScreen> {
  bool _attempted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_attempted) {
      _attempted = true;
      _join();
    }
  }

  Future<void> _join() async {
    await ref
        .read(groupControllerProvider.notifier)
        .joinByInviteLink(widget.groupId, widget.code);
    if (!mounted) return;
    final l10n = context.l10n;
    final state = ref.read(groupControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (state.hasError) {
      messenger.showSnackBar(SnackBar(
        content: Text(
            userMessage(state.error!, fallback: l10n.errorJoinGroup, l10n: l10n)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      context.go('/trips');
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.joinedViaLink)));
    context.go('/trip/${widget.groupId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.l10n.joiningGroup),
          ],
        ),
      ),
    );
  }
}
