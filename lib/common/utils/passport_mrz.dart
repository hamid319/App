/// The two machine-readable lines at the foot of a passport's data page
/// (ICAO 9303, TD3: 44 characters each), filled with the traveller's
/// name and a document number derived from their account. Decoration
/// only, but built to the real format so it reads as genuine.
(String, String) passportMrz({
  required String name,
  required String uid,
  required DateTime issued,
}) {
  final parts = _clean(name).split(' ').where((p) => p.isNotEmpty).toList();
  final surname = parts.isEmpty ? 'TRAVELLER' : parts.last;
  final given = parts.length > 1 ? parts.sublist(0, parts.length - 1) : [];
  final line1 = _pad('P<TFM$surname<<${given.join('<')}', 44);

  final number = _pad(
          uid
              .toUpperCase()
              .replaceAll(RegExp('[^A-Z0-9]'), '')
              .padRight(9, '0'),
          9)
      .substring(0, 9);
  // Valid for ten years from the account's creation, like a real passport.
  final expiry = DateTime(issued.year + 10, issued.month, issued.day);
  final expiryText = _yymmdd(expiry);
  const unknownBirth = '<<<<<<';
  final body = '$number${checkDigit(number)}TFM$unknownBirth<<'
      '$expiryText${checkDigit(expiryText)}';
  final last = checkDigit(
      '$number${checkDigit(number)}$expiryText${checkDigit(expiryText)}');
  final line2 = '${_pad(body, 43)}$last';
  return (line1, line2);
}

/// ICAO 9303 check digit: weights 7, 3, 1; letters A=10 … Z=35, '<' = 0.
int checkDigit(String s) {
  const weights = [7, 3, 1];
  var sum = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    final v = c >= 48 && c <= 57
        ? c - 48
        : c >= 65 && c <= 90
            ? c - 55
            : 0;
    sum += v * weights[i % 3];
  }
  return sum % 10;
}

String _yymmdd(DateTime d) => '${(d.year % 100).toString().padLeft(2, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

String _pad(String s, int n) =>
    s.length >= n ? s.substring(0, n) : s.padRight(n, '<');

/// Upper case A–Z with ICAO transliteration of German letters.
String _clean(String name) => name
    .toUpperCase()
    .replaceAll('Ä', 'AE')
    .replaceAll('Ö', 'OE')
    .replaceAll('Ü', 'UE')
    .replaceAll('ß', 'SS')
    .replaceAll(RegExp('[ÀÁÂÃÅ]'), 'A')
    .replaceAll(RegExp('[ÈÉÊË]'), 'E')
    .replaceAll(RegExp('[ÌÍÎÏ]'), 'I')
    .replaceAll(RegExp('[ÒÓÔÕ]'), 'O')
    .replaceAll(RegExp('[ÙÚÛ]'), 'U')
    .replaceAll('Ç', 'C')
    .replaceAll('Ñ', 'N')
    .replaceAll(RegExp('[^A-Z ]'), ' ')
    .trim();
