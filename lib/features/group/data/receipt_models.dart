import 'package:meta/meta.dart';

/// One line read from a receipt; amounts are in hundredths of the receipt's
/// currency (cents for euros).
@immutable
class ScannedLine {
  final String name;

  /// The printed name when [name] differs from it (kept for the review
  /// screen; the on-device scan leaves it empty).
  final String? original;
  final int amount;

  const ScannedLine({required this.name, this.original, required this.amount});
}

/// What the scan read from a receipt photo.
@immutable
class ScannedReceipt {
  final String merchant;

  /// ISO 4217 code, upper case ('EUR', 'USD').
  final String currency;
  final List<ScannedLine> lines;

  /// Tax added on top of the line prices (US sales tax); 0 when included.
  final int tax;
  final int tip;
  final int total;

  const ScannedReceipt({
    required this.merchant,
    required this.currency,
    required this.lines,
    required this.tax,
    required this.tip,
    required this.total,
  });
}
