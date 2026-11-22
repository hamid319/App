import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'receipt_models.dart';

/// One piece of text the on-device recogniser found, with its box. Units
/// don't matter (pixels on Android, 0..1 on iOS) as long as they are the
/// same for all pieces of one photo; y grows downwards.
@immutable
class RecognizedText {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const RecognizedText(this.text, this.left, this.top, this.right, this.bottom);

  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
}

/// Turns recognised text into a [ScannedReceipt]: groups the pieces into
/// printed rows, reads the price at the end of each row, and sorts rows
/// into items, total, tip and tax. Returns null when no item was found.
///
/// shortcut: rule based, tuned on German and English till receipts with
/// two decimals; amounts without decimals (yen) are not read. The review
/// screen lets the payer fix whatever this gets wrong.
ScannedReceipt? parseReceipt(List<RecognizedText> pieces) {
  final rows = _groupRows(pieces);
  if (rows.isEmpty) return null;

  final lines = <ScannedLine>[];
  var total = 0;
  var tip = 0;
  var tax = 0;
  String? pendingName;
  var afterTotal = false;

  for (final printed in rows) {
    final row = printed.text;
    if (_date.hasMatch(row)) {
      pendingName = null;
      continue;
    }
    // A number counts as the price only in the price column on the right;
    // "Cola 0,33" (the "l" lost) is part of a name.
    final price = printed.reachesPriceColumn ? _trailingPrice(row) : null;
    final label = _label(row, price);
    final lower = label.toLowerCase();

    if (_matches(lower, _totalWords) && !_matches(lower, _subtotalWords)) {
      if (price != null && price.cents > 0 && total == 0) total = price.cents;
      afterTotal = true;
      pendingName = null;
      continue;
    }
    if (_matches(lower, _tipWords)) {
      if (price != null) tip = price.cents.abs();
      continue;
    }
    if (_matches(lower, _addedTaxWords) && !_matches(lower, _includedTaxWords)) {
      if (price != null && !afterTotal) tax = price.cents.abs();
      continue;
    }
    // Payment, change and the VAT summary follow the total.
    if (afterTotal || _matches(lower, _skipWords)) {
      pendingName = null;
      continue;
    }
    if (price == null) {
      // A name whose price is printed on the next row ("2 x 1,50   3,00").
      pendingName = _hasLetters(label) ? label : pendingName;
      continue;
    }
    var name = _hasLetters(label)
        ? label
        : (_quantityOnly.hasMatch(label) ? (pendingName ?? '') : '');
    pendingName = null;
    if (price.cents < 0) {
      // A discount ("Rabatt -0,50") lowers the line above it.
      if (lines.isNotEmpty) {
        final last = lines.last;
        final lowered = last.amount + price.cents;
        // A discount larger than the line belongs elsewhere; keep the line.
        if (lowered > 0) {
          lines[lines.length - 1] =
              ScannedLine(name: last.name, amount: lowered);
        }
      }
      continue;
    }
    if (price.cents == 0 || name.isEmpty) continue;
    name = _cleanName(name);
    if (name.isEmpty) continue;
    lines.add(ScannedLine(name: name, amount: price.cents));
  }

  if (lines.isEmpty) return null;
  return ScannedReceipt(
    merchant: _merchant([for (final r in rows) r.text]),
    currency: _currency(pieces),
    lines: lines,
    tax: tax,
    tip: tip,
    total: total > 0 ? total : lines.fold(0, (sum, l) => sum + l.amount) + tax + tip,
  );
}

/// A printed row: its pieces joined left to right, and whether it reaches
/// the price column (its right edge in the right quarter of the receipt).
class _Row {
  final String text;
  final bool reachesPriceColumn;
  const _Row(this.text, this.reachesPriceColumn);
}

/// Pieces whose vertical centres lie within half a text height of each
/// other form one printed row, read left to right.
List<_Row> _groupRows(List<RecognizedText> pieces) {
  final usable = [
    for (final p in pieces)
      if (p.text.trim().isNotEmpty && p.height > 0)
        RecognizedText(_latin(p.text), p.left, p.top, p.right, p.bottom)
  ]..sort((a, b) => a.centerY.compareTo(b.centerY));
  if (usable.isEmpty) return const [];
  final heights = usable.map((p) => p.height).toList()..sort();
  final tolerance = heights[heights.length ~/ 2] * 0.5;
  final minLeft = usable.map((p) => p.left).reduce(math.min);
  final maxRight = usable.map((p) => p.right).reduce(math.max);
  final priceColumn = minLeft + (maxRight - minLeft) * 0.75;

  final rows = <List<RecognizedText>>[];
  for (final piece in usable) {
    final row = rows.isEmpty ? null : rows.last;
    final rowCenter = row == null
        ? null
        : row.map((p) => p.centerY).reduce((a, b) => a + b) / row.length;
    if (row != null && (piece.centerY - rowCenter!).abs() <= tolerance) {
      row.add(piece);
    } else {
      rows.add([piece]);
    }
  }
  return [
    for (final row in rows)
      _Row(
        (row..sort((a, b) => a.left.compareTo(b.left)))
            .map((p) => p.text.trim())
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' '),
        row.map((p) => p.right).reduce(math.max) >= priceColumn,
      )
  ];
}

/// Text recognition sometimes returns look-alike Cyrillic letters for the
/// VAT class ("6,50 А"); map them to Latin.
String _latin(String text) {
  const map = {
    'А': 'A', 'В': 'B', 'С': 'C', 'Е': 'E', 'Н': 'H', 'К': 'K', 'М': 'M',
    'О': 'O', 'Р': 'P', 'Т': 'T', 'Х': 'X', 'а': 'a', 'е': 'e', 'о': 'o',
    'р': 'p', 'с': 'c', 'х': 'x',
  };
  return text.split('').map((c) => map[c] ?? c).join();
}

class _Price {
  final int cents;
  final int start;
  const _Price(this.cents, this.start);
}

/// "12,50", "1.234,50", "12.50 €", "-0,50", "3,99 A" (VAT class letter)
/// at the end of a row.
final _priceAtEnd = RegExp(
    r'(-\s?)?(\d{1,3}(?:[.,]\d{3})+|\d+)[.,](\d{2})\s*(-)?\s*(?:€|eur|usd|chf|gbp|\$|£)?\s*(?:[a-d]\b|\*)?\s*$',
    caseSensitive: false);

_Price? _trailingPrice(String row) {
  final m = _priceAtEnd.firstMatch(row);
  if (m == null) return null;
  final whole = int.tryParse(m.group(2)!.replaceAll(RegExp(r'[.,]'), ''));
  if (whole == null) return null;
  final cents = whole * 100 + int.parse(m.group(3)!);
  final negative = m.group(1) != null || m.group(4) != null;
  return _Price(negative ? -cents : cents, m.start);
}

String _label(String row, _Price? price) =>
    (price == null ? row : row.substring(0, price.start)).trim();

bool _hasLetters(String s) => RegExp(r'[a-zA-ZäöüÄÖÜß]{2,}').hasMatch(s);

bool _matches(String lower, List<String> words) => words
    .any((w) => RegExp('(^|[^a-zäöüß])$w(\$|[^a-zäöüß])').hasMatch(lower));

/// A date ("21.11.26", "21.11.2026") would otherwise read as a price.
final _date = RegExp(r'\b\d{1,2}\.\d{1,2}\.\d{2,4}\b');

/// A row that only says how many ("2 x 1,50", "3 Stk").
final _quantityOnly =
    RegExp(r'^(\d+([.,]\d+)?\s*(x|\*|stk\.?|st\.?)\s*)*[\d.,\s]*$', caseSensitive: false);

/// Drops a leading article number and a currency left before the price.
String _cleanName(String name) => name
    .replaceFirst(RegExp(r'^\d{4,}\s+'), '')
    .replaceFirst(RegExp(r'\s*(€|eur|usd|chf|gbp|\$|£)$', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _totalWords = [
  'summe', 'gesamt', 'gesamtbetrag', 'endbetrag', 'zu zahlen', 'zahlbetrag',
  'total', 'amount due', 'balance due', 'grand total', 'betrag',
];
const _subtotalWords = ['zwischensumme', 'subtotal', 'sub total', 'netto'];
const _tipWords = ['trinkgeld', 'tip', 'gratuity', 'service charge', 'bedienung'];
const _addedTaxWords = ['sales tax', 'tax'];
const _includedTaxWords = ['mwst', 'ust', 'vat', 'incl', 'inkl'];
const _skipWords = [
  'mwst', 'ust', 'steuer', 'netto', 'brutto', 'vat', 'zwischensumme',
  'subtotal', 'gegeben', 'rückgeld', 'rueckgeld', 'change', 'cash',
  'ec-karte', 'ec karte', 'girocard', 'karte', 'kartenzahlung', 'visa',
  'mastercard', 'maestro', 'amex', 'tse', 'transaktion', 'beleg', 'bon-nr',
  'kasse', 'datum', 'uhrzeit', 'tisch', 'table', 'kellner', 'server',
  'steuernr', 'st.-nr', 'ust-id', 'tel', 'www', 'danke', 'thank',
];

/// The shop's name: the first of the top rows that reads like a name.
String _merchant(List<String> rows) {
  for (final row in rows.take(4)) {
    final lower = row.toLowerCase();
    if (!_hasLetters(row) || _priceAtEnd.hasMatch(row)) continue;
    if (_matches(lower, _skipWords) ||
        _matches(lower, ['rechnung', 'quittung', 'receipt', 'invoice'])) {
      continue;
    }
    return row.length > 40 ? row.substring(0, 40).trim() : row;
  }
  return '';
}

/// The receipt's currency from symbols and codes on it; euros by default.
String _currency(List<RecognizedText> pieces) {
  final all = pieces.map((p) => p.text).join(' ');
  int count(Pattern p) => p.allMatches(all).length;
  final scores = {
    'EUR': count('€') + count(RegExp(r'\bEUR\b', caseSensitive: false)),
    'USD': count(r'$') + count(RegExp(r'\bUSD\b')),
    'GBP': count('£') + count(RegExp(r'\bGBP\b')),
    'CHF': count(RegExp(r'\bCHF\b')),
  };
  final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return best.value == 0 ? 'EUR' : best.key;
}
