import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/group_controller.dart';
import 'trip_ui.dart';

/// Asks for an invite code and joins that trip. Returns its group id, or
/// null when cancelled or the code did not work (the error is shown).
Future<String?> showJoinTripDialog(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final code = await showDialog<String>(
    context: context,
    builder: (_) => const _JoinDialog(),
  );
  if (code == null || !context.mounted) return null;
  if (code.isEmpty) {
    showTripSnack(context, l10n.enterInviteCode);
    return null;
  }
  await ref.read(groupControllerProvider.notifier).joinByInviteCodeOnly(code);
  if (!context.mounted) return null;
  final state = ref.read(groupControllerProvider);
  if (state.hasError) {
    showTripSnack(
      context,
      userMessage(state.error!, fallback: l10n.errorJoinGroup, l10n: l10n),
      error: true,
    );
    return null;
  }
  showTripSnack(context, l10n.joinedGroup);
  return ref.read(selectedGroupIdProvider);
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _code.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.joinGroupViaInvite),
      content: TextField(
        controller: _code,
        autofocus: true,
        maxLength: 6,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(letterSpacing: 6),
        decoration: InputDecoration(
          hintText: l10n.inviteCodeHint,
          helperText: l10n.inviteCodeFieldLabel,
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _submit,
          child: Text(l10n.join),
        ),
      ],
    );
  }
}
