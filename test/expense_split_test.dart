import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/trip_expense.dart';
import 'package:swipetrip/common/utils/expense_split.dart';
import 'package:swipetrip/common/utils/money.dart';

TripExpense _e(int cents, String paidBy, List<String> participants) =>
    TripExpense(
      id: 'x',
      title: 't',
      amountCents: cents,
      paidBy: paidBy,
      participants: participants,
      createdBy: paidBy,
    );

void main() {
  group('splitEqually', () {
    test('divides evenly', () {
      expect(splitEqually(900, ['a', 'b', 'c']), {'a': 300, 'b': 300, 'c': 300});
    });

    test('remainder cents go to the first uids in sorted order', () {
      expect(splitEqually(1001, ['c', 'a', 'b']), {'a': 334, 'b': 334, 'c': 333});
      expect(splitEqually(100, ['b', 'a', 'c']), {'a': 34, 'b': 33, 'c': 33});
    });

    test('shares always sum to the amount, duplicates count once', () {
      final split = splitEqually(1234, ['a', 'b', 'a', 'd']);
      expect(split.keys, unorderedEquals(['a', 'b', 'd']));
      expect(split.values.reduce((x, y) => x + y), 1234);
    });

    test('no participants, no split', () {
      expect(splitEqually(500, []), isEmpty);
    });
  });

  group('computeBalances', () {
    test('payer gets back what others owe', () {
      final balances = computeBalances([
        _e(42000, 'me', ['me', 'ozan', 'lea', 'mira']),
        _e(4500, 'ozan', ['me', 'ozan', 'lea']),
      ], members: ['me', 'ozan', 'lea', 'mira']);
      expect(balances, {'me': 30000, 'ozan': -7500, 'lea': -12000, 'mira': -10500});
      expect(balances.values.reduce((a, b) => a + b), 0);
    });

    test('members without expenses are even', () {
      expect(computeBalances([], members: ['a', 'b']), {'a': 0, 'b': 0});
    });
  });

  group('simplifyDebts', () {
    test('biggest debtor pays biggest creditor', () {
      final transfers = simplifyDebts({'a': 3000, 'b': -2000, 'c': -1000});
      expect(transfers, [
        const DebtTransfer(from: 'b', to: 'a', amountCents: 2000),
        const DebtTransfer(from: 'c', to: 'a', amountCents: 1000),
      ]);
    });

    test('nothing to settle', () {
      expect(simplifyDebts({'a': 0, 'b': 0}), isEmpty);
    });

    test('random balances: totals match and at most n-1 transfers', () {
      final rnd = Random(7);
      for (var round = 0; round < 200; round++) {
        final members = [for (var i = 0; i < 2 + rnd.nextInt(7); i++) 'u$i'];
        final expenses = [
          for (var i = 0; i < rnd.nextInt(10); i++)
            _e(1 + rnd.nextInt(50000), members[rnd.nextInt(members.length)], [
              for (final m in members)
                if (rnd.nextBool()) m,
            ]),
        ].where((e) => e.participants.isNotEmpty).toList();
        final balances = computeBalances(expenses, members: members);
        final transfers = simplifyDebts(balances);
        final owed = balances.values.where((v) => v > 0).fold(0, (a, b) => a + b);
        expect(transfers.fold(0, (a, t) => a + t.amountCents), owed);
        expect(transfers.length, lessThanOrEqualTo(members.length - 1));
        // Applying the transfers settles everyone.
        final after = Map.of(balances);
        for (final t in transfers) {
          expect(t.amountCents, greaterThan(0));
          after[t.from] = after[t.from]! + t.amountCents;
          after[t.to] = after[t.to]! - t.amountCents;
        }
        expect(after.values.every((v) => v == 0), isTrue);
      }
    });
  });

  group('money', () {
    test('parses typed amounts into cents', () {
      expect(parseAmountToCents('12'), 1200);
      expect(parseAmountToCents('12,5'), 1250);
      expect(parseAmountToCents('12,50 €'), 1250);
      expect(parseAmountToCents('12.50'), 1250);
      expect(parseAmountToCents('1.234,56'), 123456);
      expect(parseAmountToCents('1,234.56'), 123456);
      expect(parseAmountToCents('1.234'), 123400);
      expect(parseAmountToCents(',5'), 50);
    });

    test('rejects invalid or non-positive amounts', () {
      expect(parseAmountToCents(''), isNull);
      expect(parseAmountToCents('0'), isNull);
      expect(parseAmountToCents('abc'), isNull);
      expect(parseAmountToCents('1,234,5'), isNull);
      expect(parseAmountToCents('-5'), isNull);
      expect(parseAmountToCents('1,2345'), isNull);
    });

    test('formats cents per locale', () {
      expect(formatCents(4250, 'de').replaceAll('\u00A0', ' '), '42,50 €');
      expect(formatCents(4250, 'en'), '€42.50');
    });

    test('paypal.me link only for a usable handle', () {
      expect(paypalMeUri('lea', 2750).toString(),
          'https://paypal.me/lea/27.50EUR');
      expect(paypalMeUri('https://paypal.me/lea', 100).toString(),
          'https://paypal.me/lea/1.00EUR');
      expect(paypalMeUri(null, 100), isNull);
      expect(paypalMeUri('  ', 100), isNull);
      expect(paypalMeUri('bad name?', 100), isNull);
    });
  });
}
