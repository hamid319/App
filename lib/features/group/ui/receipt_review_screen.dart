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
import '../data/receipt_scan_repository.dart';
import '../logic/trip_controller.dart';
import '../widgets/trip_ui.dart';

/// The payer checks a scanned receipt before saving it: names, amounts,
/// which lines everyone shares, the tip, who paid and who was there. With
/// [expenseId] it edits a saved receipt instead (its creator only).
class ReceiptReviewScreen extends ConsumerWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.groupId,
    this.scanned,
    this.expenseId,
  });

  final String groupId;
  final ScannedReceipt? scanned;
  final String? expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final uid = ref.watch(authControllerProvider).value?.uid ?? '';
    final group = ref.watch(tripProvider(groupId)).value;
    final expenses = ref.watch(tripExpensesProvider(groupId)).value;
    final expense = expenseId == null
        ? null
        : expenses?.where((e) => e.id == expenseId).firstOrNull;
    final ready = group != null &&
        (expenseId == null ? scanned != null : expense != null);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.receiptCheckTitle)),
      body: ready
          ? _ReviewForm(
              group: group, uid: uid, scanned: scanned, expense: expense)
          : expenses != null && expenseId != null && expense == null
              ? ErrorView(message: l10n.errorGeneric)
              : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _Line {
  _Line(this.id, this.name, this.original, this.amount, this.forAll);

  final String id;
  String name;
  final String? original;

  /// Hundredths of the receipt's currency.
  int amount;
  bool forAll;
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({
    required this.group,
    required this.uid,
    this.scanned,
    this.expense,
  });

  final GroupModel group;
  final String uid;
  final ScannedReceipt? scanned;
  final TripExpense? expense;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  late final String _currency;
  late final List<_Line> _lines;
  late final TextEditingController _title;
  late final TextEditingController _tip;
  final _euros = TextEditingController();
  late String _paidBy;
  late final Set<String> _participants;
  var _nextId = 0;
  String? _error;

  bool get _foreign => _currency != 'EUR';
  String get _locale => Localizations.localeOf(context).toLanguageTag();

  @override
  void initState() {
    super.initState();
    final members = widget.group.members;
    final expense = widget.expense;
    final scanned = widget.scanned;
    _currency = scanned?.currency ?? 'EUR';
    _lines = expense != null
        ? [
            for (final i in expense.items)
              _Line(i.id, i.name, i.original, i.amountCents, i.forAll),
          ]
        : [
            for (final l in scanned!.lines)
              _Line(_newId(), l.name, l.original, l.amount, false),
          ];
    _title = TextEditingController(text: expense?.title ?? scanned?.merchant);
    final paidBy = expense?.paidBy;
    _paidBy = paidBy != null && members.contains(paidBy)
        ? paidBy
        : members.contains(widget.uid)
            ? widget.uid
            : members.first;
    _participants = expense == null
        ? {...members}
        : {...expense.participants.where(members.contains)};
    _tip = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // Needs the locale for the decimal separator and the tax line's name.
    final tip = widget.expense?.tipCents ?? widget.scanned?.tip ?? 0;
    if (tip > 0) _tip.text = centsToAmountInput(tip, _locale);
    final tax = widget.scanned?.tax ?? 0;
    if (tax > 0) {
      _lines.add(_Line(_newId(), context.l10n.receiptTax, null, tax, true));
    }
  }

  var _initialized = false;

  String _newId() {
    // Saved ids are kept; new ones continue after the highest.
    final used = widget.expense?.items.map((i) => i.id).toSet() ?? const {};
    String id;
    do {
      id = 'i${_nextId++}';
    } while (used.contains(id));
    return id;
  }

  @override
  void dispose() {
    _title.dispose();
    _tip.dispose();
    _euros.dispose();
    super.dispose();
  }

  String _money(int amount) =>
      formatCents(amount, _locale, currency: _currency);
  int get _tipAmount => parseAmountToCents(_tip.text) ?? 0;
  int get _linesSum => _lines.fold(0, (s, l) => s + l.amount);

  Future<void> _editLine([_Line? line]) async {
    final l10n = context.l10n;
    final name = TextEditingController(text: line?.name);
    final amount = TextEditingController(
        text: line == null ? null : centsToAmountInput(line.amount, _locale));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(line == null ? l10n.receiptAddLine : line.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: line == null,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.receiptLineNameHint),
            ),
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  hintText: l10n.tripExpenseAmountHint, suffixText: _currency),
            ),
          ],
        ),
        actions: [
          if (line != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error),
              child: Text(l10n.delete),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    final cents = parseAmountToCents(amount.text);
    final text = name.text.trim();
    name.dispose();
    amount.dispose();
    if (!mounted) return;
    setState(() {
      if (result == 'delete') {
        _lines.remove(line);
      } else if (result == 'save' && cents != null && text.isNotEmpty) {
        if (line == null) {
          _lines.add(_Line(_newId(), text, null, cents, false));
        } else {
          line
            ..name = text
            ..amount = cents;
        }
      }
    });
  }

  void _save() {
    final l10n = context.l10n;
    final euros = _foreign ? parseAmountToCents(_euros.text) : null;
    final error = _title.text.trim().isEmpty
        ? l10n.tripExpenseTitleMissing
        : _lines.isEmpty
            ? l10n.receiptNoLines
            : _foreign && euros == null
                ? l10n.receiptEuroMissing
                : _participants.isEmpty
                    ? l10n.tripExpenseNoParticipants
                    : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    // Another currency: lines and tip scaled to what was paid in euros.
    final amounts = [for (final l in _lines) l.amount, _tipAmount];
    final cents = euros == null ? amounts : scaleToTotal(amounts, euros);
    final items = [
      for (final (i, l) in _lines.indexed)
        ReceiptItem(
          id: l.id,
          name: l.name,
          original: l.original,
          amountCents: cents[i],
          forAll: l.forAll,
        ),
    ];
    final tip = cents.last;
    final total = cents.fold(0, (a, b) => a + b);
    final participants = [
      for (final m in widget.group.members)
        if (_participants.contains(m)) m,
    ];
    final actions = ref.read(tripActionsProvider.notifier);
    final groupId = widget.group.groupId;
    final existing = widget.expense;
    runTripWrite(
      context,
      () => existing == null
          ? actions.addExpense(
              groupId,
              title: _title.text,
              amountCents: total,
              paidBy: _paidBy,
              participants: participants,
              items: items,
              tipCents: tip,
            )
          : actions.updateExpense(
              groupId,
              existing.copyWith(
                title: _title.text.trim(),
                amountCents: total,
                paidBy: _paidBy,
                participants: participants,
                items: items,
                tipCents: tip,
              ),
            ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final members = widget.group.members;
    String name(int i) => members[i] == widget.uid
        ? l10n.tripYou
        : memberName(ref, members[i], l10n.memberFallback(i + 1));
    final sum = _linesSum + _tipAmount;
    final printed = widget.scanned?.total ?? 0;
    final mismatch = printed > 0 && (sum - printed).abs() > 1;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        InsetGroup(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _title,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.tripExpenseTitleHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.receiptForAllHint, style: muted),
        const SizedBox(height: 8),
        InsetGroup(
          children: [
            for (final line in _lines)
              InkWell(
                onTap: () => _editLine(line),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.name, style: text.bodyLarge),
                            if (line.original != null)
                              Text(line.original!,
                                  style: text.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_money(line.amount), style: text.bodyLarge),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(l10n.receiptForAll),
                        selected: line.forAll,
                        onSelected: (on) => setState(() => line.forAll = on),
                      ),
                    ],
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(l10n.receiptAddLine),
              onTap: () => _editLine(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InsetGroup(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.receiptTip, style: text.bodyLarge)),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _tip,
                      textAlign: TextAlign.end,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: ' $_currency',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.receiptTotal, style: text.titleMedium),
                  ),
                  Text(_money(sum), style: text.titleMedium),
                ],
              ),
            ),
          ],
        ),
        if (mismatch) ...[
          const SizedBox(height: 8),
          Text(
            l10n.receiptMismatch(_money(sum), _money(printed)),
            style: text.bodyMedium?.copyWith(color: scheme.error),
          ),
        ],
        if (_foreign) ...[
          const SizedBox(height: 16),
          Text(l10n.receiptForeignTitle(_currency, _money(sum)), style: muted),
          const SizedBox(height: 8),
          InsetGroup(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _euros,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: l10n.receiptEuroHint,
                    suffixText: euroSymbol(_locale),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.tripExpensePaidBy, style: muted),
        const SizedBox(height: 8),
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
        Text(l10n.tripExpenseSplitWith, style: muted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, m) in members.indexed)
              FilterChip(
                label: Text(name(i)),
                selected: _participants.contains(m),
                onSelected: (on) => setState(
                    () => on ? _participants.add(m) : _participants.remove(m)),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: text.bodyMedium?.copyWith(color: scheme.error)),
        ],
        const SizedBox(height: 20),
        FloatingPrimaryButton(
          label: widget.expense == null ? l10n.tripAddExpense : l10n.save,
          icon: Icons.check_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}
