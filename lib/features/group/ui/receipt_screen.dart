import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/group_model.dart';
import '../../../common/models/trip_expense.dart';
import '../../../common/utils/expense_split.dart';
import '../../../common/utils/money.dart';
import '../../../common/widgets/error_view.dart';
import '../../../l10n/l10n.dart';
import '../../auth/logic/auth_controller.dart';
import '../logic/trip_controller.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/trip_ui.dart';

/// A scanned receipt: every member ticks what they had; lines for all,
/// lines nobody took and the tip are shared by all participants.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen(
      {super.key, required this.groupId, required this.expenseId});

  final String groupId;
  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final uid = ref.watch(authControllerProvider).value?.uid ?? '';
    final group = ref.watch(tripProvider(groupId)).value;
    final expenses = ref.watch(tripExpensesProvider(groupId));
    final claims = ref.watch(tripClaimsProvider(groupId)).value ?? const {};
    final expense = expenses.value?.where((e) => e.id == expenseId).firstOrNull;

    if (group == null || expense == null) {
      return Scaffold(
        appBar: AppBar(),
        body: expenses.hasValue
            ? ErrorView(message: l10n.errorGeneric)
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final mine = expense.isEditableBy(uid);
    return Scaffold(
      appBar: AppBar(
        title: Text(expense.title),
        actions: [
          if (mine) ...[
            IconButton(
              tooltip: l10n.tripEditExpense,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/trip/$groupId/costs/receipt/$expenseId/edit'),
            ),
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                if (!await confirmDeleteExpense(context, expense) ||
                    !context.mounted) {
                  return;
                }
                final actions = ref.read(tripActionsProvider.notifier);
                runTripWrite(
                    context, () => actions.deleteExpense(groupId, expense));
                context.pop();
              },
            ),
          ],
        ],
      ),
      body: _ReceiptBody(
          group: group, uid: uid, expense: expense, claims: claims),
    );
  }
}

class _ReceiptBody extends ConsumerWidget {
  const _ReceiptBody({
    required this.group,
    required this.uid,
    required this.expense,
    required this.claims,
  });

  final GroupModel group;
  final String uid;
  final TripExpense expense;
  final ReceiptClaims claims;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String money(int cents) => formatCents(cents, locale);
    String name(String id) {
      if (id == uid) return l10n.tripYou;
      final i = group.members.indexOf(id);
      return memberName(
          ref, id, i < 0 ? l10n.userFallbackName : l10n.memberFallback(i + 1));
    }

    final shares = expenseShares(expense, claims);
    final canClaim = expense.participants.contains(uid);
    final toClaim = expense.items.where((i) => !i.forAll).toList();
    final forAll = expense.items.where((i) => i.forAll).toList();
    final open = openItems(expense, claims).length;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        TripCard(
          radius: 20,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(canClaim ? l10n.receiptYourShare : l10n.receiptTotal,
                  style: muted),
              const SizedBox(height: 2),
              Text(
                money(canClaim ? shares[uid] ?? 0 : expense.amountCents),
                style: text.displaySmall?.copyWith(fontSize: 40),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  '${l10n.receiptTotal} ${money(expense.amountCents)}',
                  l10n.receiptPaidByName(name(expense.paidBy)),
                ].join(' · '),
                style: muted,
              ),
              if (!canClaim) ...[
                const SizedBox(height: 6),
                Text(l10n.receiptNotParticipant, style: muted),
              ],
            ],
          ),
        ),
        if (toClaim.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: Text(l10n.receiptToClaim, style: text.titleLarge)),
              Text(l10n.receiptOpenLines(open), style: muted),
            ],
          ),
          const SizedBox(height: 8),
          InsetGroup(
            separatorIndent: 56,
            children: [
              for (final item in toClaim)
                _ClaimRow(
                  item: item,
                  takers: [
                    for (final t in claimersOf(claims, expense.id, item.id))
                      if (expense.participants.contains(t)) t,
                  ],
                  enabled: canClaim,
                  uid: uid,
                  name: name,
                  money: money,
                  onChanged: (claimed) {
                    final actions = ref.read(tripActionsProvider.notifier);
                    runTripWrite(
                      context,
                      () => actions.setClaim(
                          group.groupId, expense.id, item.id, claimed),
                    );
                  },
                ),
            ],
          ),
        ],
        if (forAll.isNotEmpty || expense.tipCents > 0) ...[
          const SizedBox(height: 20),
          Text(l10n.receiptSharedByAll, style: text.titleLarge),
          const SizedBox(height: 8),
          InsetGroup(
            children: [
              for (final item in forAll)
                _PlainRow(
                    title: item.name,
                    subtitle: item.original,
                    amount: money(item.amountCents)),
              if (expense.tipCents > 0)
                _PlainRow(
                    title: l10n.receiptTip, amount: money(expense.tipCents)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.receiptUnclaimedNote, style: muted)),
          ],
        ),
      ],
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({
    required this.item,
    required this.takers,
    required this.enabled,
    required this.uid,
    required this.name,
    required this.money,
    required this.onChanged,
  });

  final ReceiptItem item;
  final List<String> takers;
  final bool enabled;
  final String uid;
  final String Function(String uid) name;
  final String Function(int cents) money;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final mine = takers.contains(uid);
    final small = text.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    return InkWell(
      onTap: enabled ? () => onChanged(!mine) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
        child: Row(
          children: [
            Checkbox(
              value: mine,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.bodyLarge),
                  if (item.original != null) Text(item.original!, style: small),
                  if (takers.isNotEmpty)
                    Text(
                      l10n.receiptTakenBy(takers.map(name).join(', ')),
                      style: small?.copyWith(color: scheme.primary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(money(item.amountCents), style: text.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.title, this.subtitle, required this.amount});

  final String title;
  final String? subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.bodyLarge),
                if (subtitle != null)
                  Text(subtitle!,
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(amount, style: text.bodyLarge),
        ],
      ),
    );
  }
}
