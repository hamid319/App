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

/// Net balance per member in cents: positive means the member gets money
/// back, negative means they owe. Balances always sum to zero. Every uid in
/// [members] gets an entry, even without expenses.
Map<String, int> computeBalances(
  Iterable<TripExpense> expenses, {
  Iterable<String> members = const [],
}) {
  final balances = <String, int>{for (final uid in members) uid: 0};
  for (final expense in expenses) {
    if (expense.amountCents <= 0 || expense.participants.isEmpty) continue;
    balances[expense.paidBy] =
        (balances[expense.paidBy] ?? 0) + expense.amountCents;
    splitEqually(expense.amountCents, expense.participants)
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
