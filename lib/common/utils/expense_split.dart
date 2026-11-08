import 'package:meta/meta.dart';

import '../models/trip_expense.dart';

/// Splits [amountCents] equally between [participants]. Cents that do not
/// divide evenly go one each to the first participants in uid order, so
/// every device computes the same split.
Map<String, int> splitEqually(int amountCents, Iterable<String> participants) {
  final people = participants.toSet().toList()..sort();
  if (people.isEmpty) return {};
  final base = amountCents ~/ people.length;
  final remainder = amountCents % people.length;
  return {
    for (final (i, uid) in people.indexed) uid: base + (i < remainder ? 1 : 0),
  };
}

/// Receipt lines each member took: uid -> expense id -> item ids. Read
/// from `groups/{g}/claims/{uid}`, one document per member.
typedef ReceiptClaims = Map<String, Map<String, Set<String>>>;

/// Who took [itemId] of [expenseId], in uid order.
List<String> claimersOf(
        ReceiptClaims claims, String expenseId, String itemId) =>
    [
      for (final MapEntry(key: uid, value: byExpense) in claims.entries)
        if (byExpense[expenseId]?.contains(itemId) ?? false) uid,
    ]..sort();

/// Claimable lines nobody (of the participants) has taken yet.
List<ReceiptItem> openItems(TripExpense expense, ReceiptClaims claims) => [
      for (final item in expense.items)
        if (!item.forAll &&
            !claimersOf(claims, expense.id, item.id)
                .any(expense.participants.contains))
          item,
    ];

/// What each participant pays of [expense], summing to its amount. A plain
/// expense is split equally. On a receipt each claimed line is split
/// between whoever took it; lines for all, lines nobody took and the tip
/// are split equally between all participants.
Map<String, int> expenseShares(
  TripExpense expense, [
  ReceiptClaims claims = const {},
]) {
  if (!expense.isReceipt) {
    return splitEqually(expense.amountCents, expense.participants);
  }
  final shares = <String, int>{};
  void add(Map<String, int> part) =>
      part.forEach((uid, cents) => shares[uid] = (shares[uid] ?? 0) + cents);
  var shared = expense.amountCents;
  for (final item in expense.items) {
    if (item.forAll || item.amountCents <= 0) continue;
    final takers = claimersOf(claims, expense.id, item.id)
        .where(expense.participants.contains);
    if (takers.isEmpty) continue;
    add(splitEqually(item.amountCents, takers));
    shared -= item.amountCents;
  }
  // The rest (lines for all, open lines, tip) can only be negative when
  // the stored amount is inconsistent; then nothing more is split.
  if (shared > 0) add(splitEqually(shared, expense.participants));
  return shares;
}

/// Net balance per member in cents: positive means the member gets money
/// back, negative means they owe. Balances always sum to zero. Every uid in
/// [members] gets an entry, even without expenses.
Map<String, int> computeBalances(
  Iterable<TripExpense> expenses, {
  Iterable<String> members = const [],
  ReceiptClaims claims = const {},
}) {
  final balances = <String, int>{for (final uid in members) uid: 0};
  for (final expense in expenses) {
    if (expense.amountCents <= 0 || expense.participants.isEmpty) continue;
    balances[expense.paidBy] =
        (balances[expense.paidBy] ?? 0) + expense.amountCents;
    expenseShares(expense, claims)
        .forEach((uid, share) => balances[uid] = (balances[uid] ?? 0) - share);
  }
  return balances;
}

/// One payment that settles (part of) a debt.
@immutable
class DebtTransfer {
  final String from;
  final String to;
  final int amountCents;

  const DebtTransfer({
    required this.from,
    required this.to,
    required this.amountCents,
  });

  @override
  bool operator ==(Object other) =>
      other is DebtTransfer &&
      other.from == from &&
      other.to == to &&
      other.amountCents == amountCents;

  @override
  int get hashCode => Object.hash(from, to, amountCents);

  @override
  String toString() => '$from -> $to: $amountCents';
}

/// Settles [balances] with few payments: the biggest debtor pays the biggest
/// creditor until one of them is even, repeated. Each step settles at least
/// one member, so n members need at most n - 1 transfers, and the transfers
/// add up to the total that is owed. Ties are broken by uid.
List<DebtTransfer> simplifyDebts(Map<String, int> balances) {
  final credit = <String, int>{};
  final debt = <String, int>{};
  balances.forEach((uid, cents) {
    if (cents > 0) credit[uid] = cents;
    if (cents < 0) debt[uid] = -cents;
  });

  String biggest(Map<String, int> map) => map.entries.reduce((a, b) {
        if (a.value != b.value) return a.value > b.value ? a : b;
        return a.key.compareTo(b.key) <= 0 ? a : b;
      }).key;

  final transfers = <DebtTransfer>[];
  while (credit.isNotEmpty && debt.isNotEmpty) {
    final to = biggest(credit);
    final from = biggest(debt);
    final amount = credit[to]! < debt[from]! ? credit[to]! : debt[from]!;
    transfers.add(DebtTransfer(from: from, to: to, amountCents: amount));
    credit[to] = credit[to]! - amount;
    debt[from] = debt[from]! - amount;
    if (credit[to] == 0) credit.remove(to);
    if (debt[from] == 0) debt.remove(from);
  }
  return transfers;
}

/// Scales [amounts] (a receipt in another currency) so they add up to
/// [total] euro cents, keeping their proportions. Leftover cents go to the
/// largest remainders, so the sum is exact.
List<int> scaleToTotal(List<int> amounts, int total) {
  final sum = amounts.fold(0, (a, b) => a + b);
  if (sum <= 0) return [for (final _ in amounts) 0];
  final exact = [for (final a in amounts) a * total / sum];
  final scaled = [for (final x in exact) x.floor()];
  final order = [for (var i = 0; i < amounts.length; i++) i]
    ..sort((a, b) => (exact[b] - scaled[b]).compareTo(exact[a] - scaled[a]));
  var left = total - scaled.fold(0, (a, b) => a + b);
  for (final i in order) {
    if (left <= 0) break;
    scaled[i]++;
    left--;
  }
  return scaled;
}
