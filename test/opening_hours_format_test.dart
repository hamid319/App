import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/common/utils/opening_hours_format.dart';
import 'package:swipetrip/l10n/app_localizations_de.dart';
import 'package:swipetrip/l10n/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();
  final de = AppLocalizationsDe();

  test('every day becomes "daily" and ranges get en dashes', () {
    expect(formatOpeningHours('Mo-Su 08:00-24:00', de), 'Täglich 08:00–24:00');
    expect(formatOpeningHours('Mo-Su 08:00-24:00', en), 'Daily 08:00–24:00');
    expect(formatOpeningHours('24/7', de), 'Rund um die Uhr geöffnet');
  });

  test('one line per rule with translated days, months and closed days', () {
    expect(
      formatOpeningHours(
          'Tu-Su 10:00-18:00; Mo off; Jan 01,May 01,Dec 25 off', de),
      'Di–So 10:00–18:00\nMo geschlossen\nJan 01, Mai 01, Dez 25 geschlossen',
    );
    expect(
      formatOpeningHours('Tu-We, Fr-Su 10:00-18:00; Th 10:00-20:00', en),
      'Tue–Wed, Fri–Sun 10:00–18:00\nThu 10:00–20:00',
    );
  });

  test('holidays, sun times and nth weekdays stay readable', () {
    expect(formatOpeningHours('Mo-Su,PH sunrise-22:00', de),
        'Täglich, Feiertage Sonnenaufgang–22:00');
    expect(formatOpeningHours('Nov Th[4] off', en), 'Nov 4. Thu closed');
    expect(formatOpeningHours('08:00 - 18:30', de), '08:00–18:30');
  });

  test('comments in quotes are kept as they are', () {
    expect(
      formatOpeningHours('Tu-Su 10:00-18:00 "Final admission 17:15"', de),
      'Di–So 10:00–18:00 Final admission 17:15',
    );
  });
}
