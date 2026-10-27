import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/trip_expense.dart';
import '../../../common/utils/money.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';
import 'trip_ui.dart';

/// Sheet to add a shared expense: title, amount in euros, who paid
/// (default: me) and who shares it (default: everyone), split equally.
/// With [expense] it edits that one instead, and its creator can delete it.
Future<void> showExpenseSheet(
  BuildContext context,
  GroupModel group,
  String uid, {
  TripExpense? expense,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ExpenseSheet(group: group, uid: uid, expense: expense),
  );
}

/// Asks before deleting [expense]; true when confirmed.
Future<bool> confirmDeleteExpense(
    BuildContext context, TripExpense expense) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.tripExpenseDeleteTitle),
      content: Text(expense.title),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return ok == true;
}

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet({required this.group, required this.uid, this.expense});

  final GroupModel group;
  final String uid;
  final TripExpense? expense;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  late final _title = TextEditingController(text: widget.expense?.title);
  late final _amount = TextEditingController(
      text: widget.expense == null
          ? null
          : centsToAmountInput(widget.expense!.amountCents,
              Localizations.localeOf(context).toLanguageTag()));
  late String _paidBy = _initialPayer();
  // Only current members: someone who left can no longer be split with.
  late final Set<String> _participants = widget.expense == null
      ? {...widget.group.members}
      : {
          for (final m in widget.expense!.participants)
            if (widget.group.members.contains(m)) m,
        };
  String? _error;

  bool get _editing => widget.expense != null;

  String _initialPayer() {
    final members = widget.group.members;
    final paidBy = widget.expense?.paidBy;
    if (paidBy != null && members.contains(paidBy)) return paidBy;
    return members.contains(widget.uid) ? widget.uid : members.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = context.l10n;
    final cents = parseAmountToCents(_amount.text);
    final String? error = _title.text.trim().isEmpty
        ? l10n.tripExpenseTitleMissing
        : cents == null
            ? l10n.tripExpenseAmountInvalid
            : _participants.isEmpty
                ? l10n.tripExpenseNoParticipants
                : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    // Member order, so the list reads like the group.
    final participants = [
      for (final m in widget.group.members)
        if (_participants.contains(m)) m,
    ];
    final actions = ref.read(tripActionsProvider.notifier);
    final groupId = widget.group.groupId;
    final existing = widget.expense;
    // Not awaited: the list and balances update from the local write at
    // once, and offline the write waits in Firestore's queue.
    runTripWrite(
      context,
      () => existing == null
          ? actions.addExpense(
              groupId,
              title: _title.text,
              amountCents: cents!,
              paidBy: _paidBy,
              participants: participants,
            )
          : actions.updateExpense(
              groupId,
              existing.copyWith(
                title: _title.text.trim(),
                amountCents: cents,
                paidBy: _paidBy,
                participants: participants,
              ),
            ),
    );
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final expense = widget.expense!;
    if (!await confirmDeleteExpense(context, expense) || !mounted) return;
    final actions = ref.read(tripActionsProvider.notifier);
    final groupId = widget.group.groupId;
    runTripWrite(context, () => actions.deleteExpense(groupId, expense));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final members = widget.group.members;
    String name(int i) => members[i] == widget.uid
        ? l10n.tripYou
        : memberName(ref, members[i], l10n.memberFallback(i + 1));
    final cents = parseAmountToCents(_amount.text);
    final perPerson = cents == null || _participants.isEmpty
        ? null
        : (cents / _participants.length).ceil();

    InputDecoration plain(String hint, {String? suffix}) => InputDecoration(
          hintText: hint,
          suffixText: suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          counterText: '',
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      _editing ? l10n.tripEditExpense : l10n.tripAddExpense,
                      style: text.headlineSmall),
                ),
                if (_editing)
                  IconButton(
                    onPressed: _delete,
                    tooltip: l10n.delete,
                    color: scheme.error,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            InsetGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _title,
                    autofocus: !_editing,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: plain(l10n.tripExpenseTitleHint),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: plain(l10n.tripExpenseAmountHint,
                        suffix: euroSymbol(locale)),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Label(l10n.tripExpensePaidBy),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, m) in members.indexed)
                  ChoiceChip(
                    label: Text(name(i)),
                    selected: _paidBy == m,
                    onSelected: (_) => setState(() => _paidBy = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _Label(l10n.tripExpenseSplitWith),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, m) in members.indexed)
                  FilterChip(
                    label: Text(name(i)),
                    selected: _participants.contains(m),
                    onSelected: (on) => setState(() =>
                        on ? _participants.add(m) : _participants.remove(m)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              perPerson == null
                  ? l10n.tripExpenseSplitEqually
                  : l10n.tripExpensePerPerson(formatCents(perPerson, locale)),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: text.bodyMedium?.copyWith(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            FloatingPrimaryButton(
              label: _editing ? l10n.save : l10n.tripAddExpense,
              icon: _editing ? Icons.check_rounded : Icons.add_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
