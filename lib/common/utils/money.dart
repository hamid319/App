import 'package:intl/intl.dart';

/// Formats integer cents as a euro amount in [locale] ("42,50 €" in German).
String formatCents(int cents, String locale, {String currency = 'EUR'}) {
  final format = NumberFormat.simpleCurrency(locale: locale, name: currency);
  return format.format(cents / 100);
}

/// The euro sign as written in [locale].
String euroSymbol(String locale) =>
    NumberFormat.simpleCurrency(locale: locale, name: 'EUR').currencySymbol;

/// Parses a typed amount ("12", "12,5", "1.234,56", "12.50") into cents.
/// Returns null for anything that is not a positive amount with at most two
/// decimals.
int? parseAmountToCents(String input) {
  var text = input.trim().replaceAll(RegExp(r'[\s€]'), '');
  if (text.isEmpty) return null;
  final lastComma = text.lastIndexOf(',');
  final lastDot = text.lastIndexOf('.');
  // The separator that comes last is the decimal one; the other groups
  // thousands.
  var decimal = lastComma > lastDot ? ',' : '.';
  // "1.234" or "1,234" alone: three digits after the only separator are a
  // thousands group, not cents.
  final sep = decimal == ',' ? lastComma : lastDot;
  final onlyOne = lastComma < 0 || lastDot < 0;
  if (sep >= 0 && onlyOne && text.length - sep - 1 == 3) {
    decimal = decimal == ',' ? '.' : ',';
  }
  final grouping = decimal == ',' ? '.' : ',';
  text = text.replaceAll(grouping, '');
  final parts = text.split(decimal);
  if (parts.length > 2) return null;
  final whole = parts[0];
  final fraction = parts.length == 2 ? parts[1] : '';
  if (!RegExp(r'^\d*$').hasMatch(whole) ||
      !RegExp(r'^\d{0,2}$').hasMatch(fraction) ||
      (whole.isEmpty && fraction.isEmpty)) {
    return null;
  }
  final cents = int.parse(whole.isEmpty ? '0' : whole) * 100 +
      int.parse(fraction.padRight(2, '0'));
  return cents > 0 ? cents : null;
}

/// paypal.me link that asks for [cents] euros, or null for an empty handle.
/// The handle may be given with or without the "paypal.me/" prefix.
Uri? paypalMeUri(String? handle, int cents) {
  var name = handle?.trim() ?? '';
  name = name.replaceFirst(RegExp(r'^(https?://)?(www\.)?paypal\.me/'), '');
  name = name.replaceAll('/', '');
  if (name.isEmpty || !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(name)) {
    return null;
  }
  final amount = (cents / 100).toStringAsFixed(2);
  return Uri.https('paypal.me', '/$name/${amount}EUR');
}
