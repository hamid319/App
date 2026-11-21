import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/features/group/data/receipt_parser.dart';

/// Builds recognised pieces as a recogniser would: one printed row per
/// list, pieces left to right, rows top to bottom.
List<RecognizedText> _photo(List<List<String>> rows) => [
      for (final (y, row) in rows.indexed)
        for (final (x, text) in row.indexed)
          RecognizedText(text, x * 200.0, y * 30.0, x * 200.0 + 150, y * 30.0 + 20),
    ];

void main() {
  test('German supermarket: items, discount, total; payment and VAT ignored',
      () {
    final r = parseReceipt(_photo([
      ['REWE'],
      ['Hauptstr. 5, 20095 Hamburg'],
      ['Milch 1,5%', '1,19 A'],
      ['Brot', '2,49 A'],
      ['Rabatt', '-0,20 A'],
      ['Pfand', '0,25 A'],
      ['SUMME EUR', '3,73'],
      ['Geg. Bar', '5,00'],
      ['Rückgeld', '1,27'],
      ['MwSt 7% 3,49', '0,24'],
      ['21.11.2026 14:31'],
    ]))!;
    expect(r.merchant, 'REWE');
    expect(r.currency, 'EUR');
    expect(r.lines.map((l) => l.name), ['Milch 1,5%', 'Brot', 'Pfand']);
    expect(r.lines.map((l) => l.amount), [119, 229, 25]);
    expect(r.total, 373);
    expect(r.tip, 0);
    expect(r.tax, 0);
  });

  test('restaurant: quantity row takes the name above, tip and total', () {
    final r = parseReceipt(_photo([
      ['Trattoria Roma'],
      ['Tisch 4'],
      ['2 x Pizza Margherita', '19,00'],
      ['Cola'],
      ['2 x 3,50', '7,00'],
      ['Zwischensumme', '26,00'],
      ['Trinkgeld', '3,00'],
      ['Gesamt', '29,00 €'],
    ]))!;
    expect(r.merchant, 'Trattoria Roma');
    expect(r.lines.map((l) => l.name), ['2 x Pizza Margherita', 'Cola']);
    expect(r.lines.map((l) => l.amount), [1900, 700]);
    expect(r.tip, 300);
    expect(r.total, 2900);
  });

  test('US diner: dollar amounts, sales tax on top, tip', () {
    final r = parseReceipt(_photo([
      ["Joe's Diner"],
      ['Burger', r'$12.50'],
      ['Fries', '4.00'],
      ['Subtotal', '16.50'],
      ['Tax', '1.47'],
      ['Tip', '3.00'],
      ['Total', r'$20.97'],
    ]))!;
    expect(r.currency, 'USD');
    expect(r.lines.map((l) => l.name), ['Burger', 'Fries']);
    expect(r.lines.map((l) => l.amount), [1250, 400]);
    expect(r.tax, 147);
    expect(r.tip, 300);
    expect(r.total, 2097);
  });

  test('dates are not prices, thousands separators are read', () {
    final r = parseReceipt(_photo([
      ['Hotel am See'],
      ['21.11.26'],
      ['Zimmer 3 Nächte', '1.234,50'],
      ['Summe', '1.234,50'],
    ]))!;
    expect(r.lines.single.name, 'Zimmer 3 Nächte');
    expect(r.lines.single.amount, 123450);
    expect(r.total, 123450);
  });

  test('pieces of one row are joined even when slightly tilted', () {
    final r = parseReceipt([
      const RecognizedText('Kiosk', 0, 0, 100, 20),
      const RecognizedText('Wasser', 0, 40, 100, 60),
      const RecognizedText('1,50', 300, 44, 360, 64),
    ])!;
    expect(r.lines.single.name, 'Wasser');
    expect(r.lines.single.amount, 150);
    expect(r.total, 150);
  });

  test('without a total the items are summed', () {
    final r = parseReceipt(_photo([
      ['Bäckerei'],
      ['Croissant', '1,80'],
      ['Kaffee', '2,60'],
    ]))!;
    expect(r.total, 440);
  });

  test('text without prices is not a receipt', () {
    expect(parseReceipt(_photo([['Hello world'], ['Some text']])), isNull);
    expect(parseReceipt(const []), isNull);
  });

  // Real output of Apple Vision in the iOS simulator for a restaurant bill
  // (21.11.2026): pieces out of order, a Cyrillic "А" as VAT class, and
  // "Cola 0,33l" read without the "l".
  test('real Vision output: restaurant bill with tip and discount', () {
    final r = parseReceipt(const [
    RecognizedText("TRATTORIA ROMA", 0.2566, 0.0613, 0.7139, 0.0974),
    RecognizedText("Lange Reihe 12, 20099 Hamburg", 0.1242, 0.0958, 0.8431, 0.1417),
    RecognizedText("Tel. 040 123456", 0.3056, 0.1414, 0.6729, 0.1704),
    RecognizedText("Tisch 7", 0.0588, 0.2295, 0.2334, 0.2526),
    RecognizedText("21.11.2026", 0.0643, 0.2689, 0.3084, 0.2967),
    RecognizedText("Kellner: Marco", 0.4255, 0.2202, 0.7673, 0.2494),
    RecognizedText("19:42", 0.4288, 0.2654, 0.5498, 0.2900),
    RecognizedText("2 x Pizza Margherita", 0.0670, 0.3475, 0.5523, 0.3782),
    RecognizedText("Penne Arrabbiata", 0.0670, 0.3901, 0.4584, 0.4157),
    RecognizedText("Cola 0,33", 0.0697, 0.4327, 0.2895, 0.4651),
    RecognizedText("2 x 3,50", 0.1153, 0.4736, 0.3164, 0.5060),
    RecognizedText("Tiramisu", 0.0693, 0.5131, 0.2685, 0.5397),
    RecognizedText("Rabatt Happy Hour", 0.0724, 0.5503, 0.4879, 0.5826),
    RecognizedText("Zwischensumme", 0.0744, 0.6352, 0.3920, 0.6630),
    RecognizedText("Trinkgeld", 0.0750, 0.6760, 0.2977, 0.7056),
    RecognizedText("SUMME EUR", 0.0777, 0.7206, 0.3727, 0.7530),
    RecognizedText("19,00 A", 0.7530, 0.3400, 0.9306, 0.3789),
    RecognizedText("11,50 A", 0.7587, 0.3833, 0.9303, 0.4157),
    RecognizedText("7,00 A", 0.7827, 0.4648, 0.9331, 0.4978),
    RecognizedText("6,50 А", 0.7828, 0.5060, 0.9357, 0.5400),
    RecognizedText("-1,00 A", 0.7614, 0.5451, 0.9357, 0.5792),
    RecognizedText("43,00", 0.8123, 0.6286, 0.9357, 0.6610),
    RecognizedText("4,00", 0.8359, 0.6688, 0.9389, 0.7043),
    RecognizedText("47,00", 0.7747, 0.7119, 0.9385, 0.7566),
    RecognizedText("EC-Karte", 0.0804, 0.8022, 0.2762, 0.8264),
    RecognizedText("MwSt 19% Netto 36,13", 0.0804, 0.8365, 0.5684, 0.8688),
    RecognizedText("Vielen Dank fuer Ihren Besuch!", 0.1467, 0.8698, 0.8747, 0.9078),
    RecognizedText("47,00", 0.8150, 0.7905, 0.9410, 0.8245),
    RecognizedText("6,87", 0.8445, 0.8330, 0.9410, 0.8637),
    ])!;
    expect(r.merchant, 'TRATTORIA ROMA');
    expect(r.currency, 'EUR');
    expect(r.lines.map((l) => l.name), [
      '2 x Pizza Margherita',
      'Penne Arrabbiata',
      'Cola 0,33',
      'Tiramisu',
    ]);
    expect(r.lines.map((l) => l.amount), [1900, 1150, 700, 550]);
    expect(r.tip, 400);
    expect(r.total, 4700);
  });

  test('a discount larger than the line above leaves it alone', () {
    final r = parseReceipt(_photo([
      ['Kiosk'],
      ['Kaugummi', '1,00'],
      ['Gutschein', '-5,00'],
    ]))!;
    expect(r.lines.single.amount, 100);
  });
}
