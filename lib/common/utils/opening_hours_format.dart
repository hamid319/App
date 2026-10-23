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

final _dayItem =
    RegExp(r'^(Mo|Tu|We|Th|Fr|Sa|Su)(?:-(Mo|Tu|We|Th|Fr|Sa|Su))?$');
final _span = RegExp(r'^(\d{1,2}):(\d{2})(?:-(\d{1,2}):(\d{2})|(\+))$');
final _ruleStart = RegExp(r'^(?:Mo|Tu|We|Th|Fr|Sa|Su|PH|SH)\b');
final _looseDash = RegExp(r'\s*-\s*');
final _looseComma = RegExp(r'\s*,\s*');
final _spaces = RegExp(r'\s+');
final _additionalRule =
    RegExp(r'(\d|off|closed),\s*(?=(?:Mo|Tu|We|Th|Fr|Sa|Su|PH|SH)\b)');

/// Whether a place with the OpenStreetMap `opening_hours` value [raw] is
/// open at some point between [fromMinutes] and [toMinutes] (minutes after
/// midnight) on the weekday of [day], e.g. tonight from 18:00 to 23:00.
///
/// Returns null when the value is missing or uses syntax this simple
/// reader does not understand (months, dates, week numbers, sun times,
/// nth weekdays ...), so callers can treat "unknown" apart from "closed".
/// Understood: "24/7", weekday lists and ranges (wrapping ones like Fr-Mo
/// too), time spans incl. past midnight ("18:00-02:00") and open end
/// ("18:00+"), "off"/"closed", rules separated by ";" or "||" and
/// additional rules after a comma ("Mo-Fr 10:00-20:00, Sa 10:00-14:00").
/// Later rules override earlier ones for the same day, as in OSM; holiday
/// rules (PH, SH) are skipped because holidays are not known here.
bool? isOpenBetween(
  String? raw, {
  required DateTime day,
  required int fromMinutes,
  required int toMinutes,
}) {
  if (raw == null) return null;
  final value = raw
      .replaceAll(_quoted, ' ')
      .replaceAll(_looseDash, '-')
      .replaceAll(_looseComma, ',')
      .replaceAll(_spaces, ' ')
      .trim();
  if (value.isEmpty) return null;
  if (value == '24/7') return true;

  final weekday = day.weekday - 1; // 0 = Monday, as in _osmDays.
  List<(int, int)>? spansToday; // null = no rule for this day yet.

  final rules = value
      .replaceAll('||', ';')
      .replaceAllMapped(_additionalRule, (m) => '${m[1]};')
      .split(';')
      .map((r) => r.trim())
      .where((r) => r.isNotEmpty);

  for (final rule in rules) {
    final parsed = _parseRule(rule);
    if (parsed == null) return null;
    final (days, spans) = parsed;
    if (days == null) continue; // Holiday-only rule.
    if (days.contains(weekday)) spansToday = spans;
  }

  final spans = spansToday;
  if (spans == null) return false; // Days without a rule are closed.
  return spans.any((s) => s.$1 < toMinutes && s.$2 > fromMinutes);
}

/// Days (0 = Monday; null for a holiday-only rule) and open spans of one
/// rule, or null when it cannot be read.
(Set<int>?, List<(int, int)>)? _parseRule(String rule) {
  var rest = rule;
  Set<int>? days = {0, 1, 2, 3, 4, 5, 6};

  if (_ruleStart.hasMatch(rest)) {
    final space = rest.indexOf(' ');
    final selector = space < 0 ? rest : rest.substring(0, space);
    rest = space < 0 ? '' : rest.substring(space + 1).trim();
    final selected = <int>{};
    var holidaysOnly = true;
    for (final item in selector.split(',')) {
      if (item == 'PH' || item == 'SH') continue;
      final match = _dayItem.firstMatch(item);
      if (match == null) return null;
      holidaysOnly = false;
      final start = _osmDays.indexOf(match[1]!);
      final end = match[2] == null ? start : _osmDays.indexOf(match[2]!);
      for (var d = start;; d = (d + 1) % 7) {
        selected.add(d);
        if (d == end) break;
      }
    }
    days = holidaysOnly ? null : selected;
  }

  if (rest == 'off' || rest == 'closed') return (days, const []);
  if (rest.isEmpty) {
    // "Mo-Fr" alone means open all day on those days.
    return (days, const [(0, 24 * 60)]);
  }

  final spans = <(int, int)>[];
  for (final part in rest.split(',')) {
    final match = _span.firstMatch(part.trim());
    if (match == null) return null;
    final start = int.parse(match[1]!) * 60 + int.parse(match[2]!);
    int end;
    if (match[5] != null) {
      end = 24 * 60; // Open end: assume open until midnight.
    } else {
      end = int.parse(match[3]!) * 60 + int.parse(match[4]!);
      if (end <= start) end += 24 * 60; // Past midnight.
    }
    if (start > 24 * 60) return null;
    spans.add((start, end));
  }
  return (days, spans);
}
