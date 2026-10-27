import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/group_model.dart';
import '../../../common/utils/money.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';
import 'trip_ui.dart';

/// Sheet to add a shared expense: title, amount in euros, who paid
/// (default: me) and who shares it (default: everyone), split equally.
Future<void> showExpenseSheet(
    BuildContext context, GroupModel group, String uid) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ExpenseSheet(group: group, uid: uid),
  );
}

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet({required this.group, required this.uid});

  final GroupModel group;
  final String uid;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  late String _paidBy = widget.group.members.contains(widget.uid)
      ? widget.uid
      : widget.group.members.first;
  late final Set<String> _participants = {...widget.group.members};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(tripActionsProvider.notifier).addExpense(
            widget.group.groupId,
            title: _title.text,
            amountCents: cents!,
            paidBy: _paidBy,
            // Member order, so the list reads like the group.
            participants: [
              for (final m in widget.group.members)
                if (_participants.contains(m)) m,
            ],
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = userMessage(e, fallback: l10n.errorGeneric, l10n: l10n);
      });
    }
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
            Text(l10n.tripAddExpense, style: text.headlineSmall),
            const SizedBox(height: 12),
            InsetGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _title,
                    autofocus: true,
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
              label: l10n.tripAddExpense,
              icon: Icons.add_rounded,
              loading: _busy,
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
