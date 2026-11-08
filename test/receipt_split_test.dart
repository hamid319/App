import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/models/trip_expense.dart';
import 'package:swipetrip/common/utils/expense_split.dart';
import 'package:swipetrip/features/group/data/receipt_scan_repository.dart';

const _items = [
  ReceiptItem(id: 'pizza', name: 'Pizza', amountCents: 1200),
  ReceiptItem(id: 'pasta', name: 'Pasta', amountCents: 1000),
  ReceiptItem(id: 'wine', name: 'Wine', amountCents: 2000),
  ReceiptItem(id: 'bread', name: 'Bread', amountCents: 300, forAll: true),
];

TripExpense _receipt(
        {int tip = 0, List<String> people = const ['a', 'b', 'c']}) =>
    TripExpense(
      id: 'r1',
      title: 'Dinner',
      amountCents: 4500 + tip,
      paidBy: 'a',
      participants: people,
      createdBy: 'a',
      items: _items,
      tipCents: tip,
    );

void main() {
  group('expenseShares on a receipt', () {
    test('claimed lines go to their takers, the rest is split by all', () {
      final claims = <String, Map<String, Set<String>>>{
        'a': {
          'r1': {'pizza', 'wine'}
        },
        'b': {
          'r1': {'pasta', 'wine'}
        },
      };
      // Bread 300 + tip 300 split by 3: 200 each. Wine 2000 by a and b.
      final shares = expenseShares(_receipt(tip: 300), claims);
      expect(
          shares, {'a': 1200 + 1000 + 200, 'b': 1000 + 1000 + 200, 'c': 200});
      expect(shares.values.reduce((x, y) => x + y), 4800);
    });

    test('lines nobody took are split by all', () {
      final shares = expenseShares(_receipt(), const {});
      expect(shares, {'a': 1500, 'b': 1500, 'c': 1500});
    });

    test('claims of non-participants and other receipts are ignored', () {
      final claims = <String, Map<String, Set<String>>>{
        'z': {
          'r1': {'pizza'}
        },
        'b': {
          'other': {'pizza'}
        },
      };
      expect(openItems(_receipt(), claims).map((i) => i.id),
          ['pizza', 'pasta', 'wine']);
      expect(
          expenseShares(_receipt(), claims), {'a': 1500, 'b': 1500, 'c': 1500});
    });

    test('balances use the claims', () {
      final claims = <String, Map<String, Set<String>>>{
        'b': {
          'r1': {'pizza', 'pasta', 'wine'}
        },
      };
      // b: 4200 + 100 bread; a paid 4500 and owes 100.
      expect(computeBalances([_receipt()], claims: claims),
          {'a': 4400, 'b': -4300, 'c': -100});
    });
  });

  group('scaleToTotal', () {
    test('keeps proportions and sums exactly', () {
      final scaled = scaleToTotal([120000, 80000, 100000], 1999);
      expect(scaled.reduce((a, b) => a + b), 1999);
      expect(scaled, [800, 533, 666]);
    });

    test('empty or zero amounts', () {
      expect(scaleToTotal([], 500), isEmpty);
      expect(scaleToTotal([0, 0], 500), [0, 0]);
    });
  });

  test('items round-trip through JSON', () {
    final e = _receipt(tip: 250);
    final back = TripExpense.fromJson('r1', {
      ...e.toJson(),
      'createdAt': null,
    });
    expect(back.items.map((i) => i.toJson()), e.items.map((i) => i.toJson()));
    expect(back.tipCents, 250);
    expect(back.isReceipt, isTrue);
  });

  test('scanned receipts parse amounts into hundredths', () {
    final r = ScannedReceipt.fromJson({
      'merchant': ' Ichiran ',
      'currency': 'jpy',
      'items': [
        {'name': 'Ramen', 'original': 'ラーメン', 'amount': 980},
        {'name': 'Egg', 'original': '', 'amount': 120.5},
        {'name': 'Free water', 'amount': 0},
      ],
      'tax': 0,
      'tip': null,
      'total': 1100.5,
    });
    expect(r.merchant, 'Ichiran');
    expect(r.currency, 'JPY');
    expect(r.lines.map((l) => l.amount), [98000, 12050]);
    expect(r.lines.first.original, 'ラーメン');
    expect(r.lines.last.original, isNull);
    expect(r.tip, 0);
    expect(r.total, 110050);
    expect(ScannedReceipt.fromJson({'currency': '€'}).currency, 'EUR');
  });
}
