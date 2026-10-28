import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/utils/passport_mrz.dart';

void main() {
  test('ICAO check digit matches the specimen', () {
    // ICAO 9303 specimen document number and dates.
    expect(checkDigit('L898902C3'), 6);
    expect(checkDigit('740812'), 2);
    expect(checkDigit('120415'), 9);
  });

  test('lines are 44 characters, surname first, umlauts transliterated', () {
    final (l1, l2) = passportMrz(
      name: 'Jürgen Max Müller',
      uid: 'aB3x9kQ2zz11',
      issued: DateTime(2025, 3, 4),
    );
    expect(l1, startsWith('P<TFMMUELLER<<JUERGEN<MAX<'));
    expect(l1.length, 44);
    expect(l2.length, 44);
    expect(l2, startsWith('AB3X9KQ2Z'));
    expect(l2, contains('350304')); // valid ten years
  });

  test('a name without letters still gives a full line', () {
    final (l1, _) = passportMrz(name: '😀', uid: 'x', issued: DateTime(2026));
    expect(l1, startsWith('P<TFMTRAVELLER<<'));
    expect(l1.length, 44);
  });
}
