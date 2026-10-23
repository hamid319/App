import '../../l10n/app_localizations.dart';

const _osmDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
const _osmMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

final _token = RegExp(r'\bMo-Su\b|\b[A-Za-z]+\b');
final _quoted = RegExp(r'"[^"]*"');
final _nthWeekday = RegExp(r'([^\s,\[]+)\[(\d)\]');
final _rangeDash = RegExp(r'(?<=\S)\s*-\s*(?=\S)');
final _tightComma = RegExp(r',(?=\S)');

/// Makes an OpenStreetMap `opening_hours` value readable in the app
/// language: one rule per line, translated day and month names, "Mo-Su" as
/// daily, "off" as closed and en dashes in ranges, e.g.
/// "Mo-Su 08:00-24:00; Dec 25 off" -> "Täglich 08:00–24:00\nDez 25 geschlossen"
/// in German. The syntax is not parsed, so unusual values stay readable
/// rather than being dropped; comments in quotes are kept as they are.
String formatOpeningHours(String raw, AppLocalizations l10n) {
  final value = raw.trim();
  if (value == '24/7') return l10n.openingHoursAlwaysOpen;

  final days = _localizedList(l10n.openingHoursWeekdays, _osmDays);
  final months = _localizedList(l10n.openingHoursMonths, _osmMonths);
  final words = <String, String>{
    for (var i = 0; i < _osmDays.length; i++) _osmDays[i]: days[i],
    for (var i = 0; i < _osmMonths.length; i++) _osmMonths[i]: months[i],
    'Mo-Su': l10n.openingHoursDaily,
    'PH': l10n.openingHoursPublicHolidays,
    'SH': l10n.openingHoursSchoolHolidays,
    'off': l10n.openingHoursClosed,
    'closed': l10n.openingHoursClosed,
    'sunrise': l10n.openingHoursSunrise,
    'dawn': l10n.openingHoursSunrise,
    'sunset': l10n.openingHoursSunset,
    'dusk': l10n.openingHoursSunset,
    'easter': l10n.openingHoursEaster,
  };

  String translate(String text) => text
      .replaceAllMapped(_token, (m) => words[m[0]] ?? m[0]!)
      .replaceAllMapped(_nthWeekday, (m) => '${m[2]}. ${m[1]}')
      .replaceAll(_rangeDash, '–')
      .replaceAll(_tightComma, ', ');

  return value
      .split(';')
      .map((rule) => rule.trim())
      .where((rule) => rule.isNotEmpty)
      .map((rule) => rule.splitMapJoin(
            _quoted,
            onMatch: (m) => m[0]!.replaceAll('"', ''),
            onNonMatch: translate,
          ))
      .join('\n');
}

/// A comma-separated translation, or the OSM names if it does not fit.
List<String> _localizedList(String joined, List<String> osm) {
  final parts = joined.split(',').map((part) => part.trim()).toList();
  return parts.length == osm.length ? parts : osm;
}
