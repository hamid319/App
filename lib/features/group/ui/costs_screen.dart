import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../common/models/group_model.dart';
import '../../../common/models/trip_expense.dart';
import '../../../common/utils/expense_split.dart';
import '../../../common/utils/money.dart';
import '../../../common/widgets/error_view.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/services/link_launcher.dart';
import '../../../l10n/l10n.dart';
import '../../auth/logic/auth_controller.dart';
import '../logic/trip_controller.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/trip_ui.dart';
import 'trip_detail_screen.dart';

/// Shared costs of a trip: what I get or owe, who pays whom, and the list
/// of expenses.
class CostsScreen extends ConsumerWidget {
  const CostsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trip = ref.watch(tripProvider(groupId));
    final uid = ref.watch(authControllerProvider).value?.uid ?? '';

    return Scaffold(
      body: trip.when(
        loading: () => WithBackButton(
          fallbackRoute: '/trip/$groupId',
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => WithBackButton(
          fallbackRoute: '/trip/$groupId',
          child: ErrorView(
            message: userMessage(e, fallback: l10n.errorGeneric, l10n: l10n),
          ),
        ),
        data: (group) {
          if (group == null) {
            return ErrorView(
              message: l10n.groupNotFound,
              onRetry: () => context.go('/trips'),
            );
          }
          final expenses = ref.watch(tripExpensesProvider(groupId));
          return Stack(
            children: [
              expenses.when(
                loading: () => WithBackButton(
                  fallbackRoute: '/trip/$groupId',
                  child: const Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => WithBackButton(
                  fallbackRoute: '/trip/$groupId',
                  child: ErrorView(
                    message:
                        userMessage(e, fallback: l10n.errorGeneric, l10n: l10n),
                    onRetry: () =>
                        ref.invalidate(tripExpensesProvider(groupId)),
                  ),
                ),
                data: (list) =>
                    _CostsBody(group: group, uid: uid, expenses: list),
              ),
              BottomFloat(
                button: FloatingPrimaryButton(
                  label: l10n.tripAddExpense,
                  icon: Icons.add_rounded,
                  onPressed: () => showExpenseSheet(context, group, uid),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CostsBody extends ConsumerWidget {
  const _CostsBody({
    required this.group,
    required this.uid,
    required this.expenses,
  });

  final GroupModel group;
  final String uid;
  final List<TripExpense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String money(int cents) => formatCents(cents, locale);
    String name(String id) {
      final i = group.members.indexOf(id);
      return memberName(
          ref, id, i < 0 ? l10n.userFallbackName : l10n.memberFallback(i + 1));
    }

    final balances = computeBalances(expenses, members: group.members);
    final transfers = simplifyDebts(balances);
    final mine = balances[uid] ?? 0;
    final total = expenses.fold(0, (sum, e) => sum + e.amountCents);
    final myTransfers =
        transfers.where((t) => t.from == uid || t.to == uid).toList();
    final otherTransfers =
        transfers.where((t) => t.from != uid && t.to != uid).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top + 8, 16, 120),
      children: [
        Row(
          children: [
            GlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: l10n.back,
              opacity: 1,
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go('/trip/${group.groupId}'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                group.groupName ?? l10n.unnamedGroup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.tripTabCosts, style: text.displaySmall),
        const SizedBox(height: 16),
        TripSectionControl(groupId: group.groupId, selected: TripSection.costs),
        const SizedBox(height: 16),
        TripCard(
          radius: 20,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                mine > 0
                    ? l10n.tripYouGet
                    : mine < 0
                        ? l10n.tripYouOwe
                        : l10n.tripAllSettled,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                money(mine.abs()),
                style: text.displaySmall?.copyWith(
                  fontSize: 40,
                  color: mine > 0 ? context.swipeColors.like : scheme.onSurface,
                ),
              ),
              if (transfers.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final t in [...myTransfers, ...otherTransfers])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.to == uid
                                ? l10n.tripOwesYou(name(t.from))
                                : t.from == uid
                                    ? l10n.tripYouOweTo(name(t.to))
                                    : l10n.tripOwes(name(t.from), name(t.to)),
                            style: text.bodyMedium,
                          ),
                        ),
                        Text(money(t.amountCents),
                            style: text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
              if (myTransfers.isNotEmpty) ...[
                const SizedBox(height: 6),
                _PaypalButton(
                  group: group,
                  uid: uid,
                  transfers: myTransfers,
                  name: name,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(l10n.tripExpenses, style: text.titleLarge)),
              Text(
                l10n.tripExpensesTotal(money(total)),
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (expenses.isEmpty)
          TripCard(
            child: Text(
              l10n.tripExpensesEmpty,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          InsetGroup(
            separatorIndent: 14 + 40 + 12,
            children: [
              for (final (i, e) in expenses.indexed)
                _ExpenseRow(
                  group: group,
                  expense: e,
                  uid: uid,
                  tone: i % 3,
                  name: name,
                ),
            ],
          ),
      ],
    );
  }
}

/// Requests money (when I am owed) or pays via the creditor's paypal.me
/// link (when I owe). Without a PayPal name the request is copied as text.
class _PaypalButton extends ConsumerWidget {
  const _PaypalButton({
    required this.group,
    required this.uid,
    required this.transfers,
    required this.name,
  });

  final GroupModel group;
  final String uid;
  final List<DebtTransfer> transfers;
  final String Function(String uid) name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final owing = transfers.where((t) => t.from == uid).toList();
    final trip = group.groupName ?? l10n.unnamedGroup;

    if (owing.isNotEmpty) {
      // Pay the biggest creditor first.
      final t = owing.first;
      final handle = ref.watch(memberProfileProvider(t.to)).value?.paypalHandle;
      final uri = paypalMeUri(handle, t.amountCents);
      if (uri == null) return const SizedBox.shrink();
      return OutlinedButton(
        onPressed: () async {
          try {
            await LinkLauncher.open(uri.toString());
          } catch (_) {
            if (context.mounted) showTripSnack(context, l10n.errorGeneric);
          }
        },
        child: Text(l10n.tripPayWithPaypal(name(t.to))),
      );
    }

    final handle = ref.watch(memberProfileProvider(uid)).value?.paypalHandle;
    final hasPaypal = paypalMeUri(handle, 1) != null;
    return OutlinedButton(
      onPressed: () async {
        final lines = [
          for (final t in transfers)
            if (paypalMeUri(handle, t.amountCents) case final uri?)
              l10n.tripPaypalRequestLine(
                  name(t.from), formatCents(t.amountCents, locale), '$uri')
            else
              l10n.tripRequestLine(
                  name(t.from), formatCents(t.amountCents, locale)),
        ];
        await Clipboard.setData(ClipboardData(
            text: [l10n.tripRequestIntro(trip), ...lines].join('\n')));
        if (!context.mounted) return;
        showTripSnack(
          context,
          hasPaypal ? l10n.tripRequestCopied : l10n.tripRequestCopiedNoPaypal,
        );
      },
      child: Text(l10n.tripRequestPaypal),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({
    required this.group,
    required this.expense,
    required this.uid,
    required this.tone,
    required this.name,
  });

  final GroupModel group;
  final TripExpense expense;
  final String uid;
  final int tone;
  final String Function(String uid) name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.swipeColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final payer =
        expense.paidBy == uid ? l10n.tripYouPaid : name(expense.paidBy);
    final everyone = group.members.every(expense.participants.contains);
    final split = everyone
        ? l10n.tripSplitEqually
        : expense.participants.length == 1
            ? l10n.tripSplitOnlyFor(expense.participants.first == uid
                ? l10n.tripYou
                : name(expense.participants.first))
            : l10n.tripSplitPeople(expense.participants.length);
    final fill = [colors.sky, colors.peach, colors.mint][tone];

    Future<void> delete() async {
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
      if (ok == true) {
        await ref
            .read(tripActionsProvider.notifier)
            .deleteExpense(group.groupId, expense.id);
      }
    }

    return InkWell(
      onLongPress: expense.createdBy == uid ? delete : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt_long_rounded,
                  size: 20, color: scheme.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    [payer, split].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(formatCents(expense.amountCents, locale),
                style: text.titleMedium?.copyWith(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
