import '../models/group_model.dart';
import '../models/packing.dart';

/// Countries whose sockets do not take the usual European plug (type C/F).
const _adapterCountries = {
  'GB', 'IE', 'MT', 'CY', 'US', 'CA', 'MX', 'JP', 'AU', 'NZ', 'CN', 'IN', //
  'ZA', 'BR', 'AR', 'TH', 'SG', 'HK', 'AE', 'IL', 'CH',
};

/// The suggested own packing list for a trip: basics, clothes counted by
/// the trip's days, things for the season and a plug adapter if needed.
/// Keys are named in the app (`packingItem_<key>` in the ARB files).
List<PackingItem> suggestedPackingList({
  DateTime? start,
  DateTime? end,
  String? countryCode,
}) {
  final days = start != null && end != null
      ? (end.difference(start).inDays + 1).clamp(1, 30)
      : null;
  int? perDay(int cap) => days == null ? null : (days > cap ? cap : days);
  // shortcut: northern-hemisphere seasons; add the destination's latitude
  // once trips south of the equator are common.
  final month = start?.month;
  final warm = month != null && month >= 5 && month <= 9;
  final cold = month != null && (month <= 3 || month >= 11);

  PackingItem item(PackingCategory c, String key, [int? qty]) =>
      PackingItem(id: key, category: c, key: key, qty: qty);

  return [
    item(PackingCategory.documents, 'idCard'),
    item(PackingCategory.documents, 'healthCard'),
    item(PackingCategory.documents, 'tickets'),
    item(PackingCategory.documents, 'wallet'),
    item(PackingCategory.tech, 'phoneCharger'),
    item(PackingCategory.tech, 'powerBank'),
    item(PackingCategory.tech, 'headphones'),
    if (_adapterCountries.contains(countryCode?.toUpperCase()))
      item(PackingCategory.tech, 'plugAdapter'),
    item(PackingCategory.clothes, 'underwear', perDay(10)),
    item(PackingCategory.clothes, 'socks', perDay(10)),
    item(PackingCategory.clothes, 'tshirts', perDay(7)),
    item(PackingCategory.clothes, 'trousers'),
    item(PackingCategory.clothes, 'pajamas'),
    item(PackingCategory.clothes, 'shoes'),
    item(PackingCategory.toiletries, 'toothbrush'),
    item(PackingCategory.toiletries, 'toothpaste'),
    item(PackingCategory.toiletries, 'deodorant'),
    item(PackingCategory.toiletries, 'medication'),
    if (warm) ...[
      item(PackingCategory.weather, 'sunscreen'),
      item(PackingCategory.weather, 'sunglasses'),
      item(PackingCategory.weather, 'swimwear'),
    ] else if (cold) ...[
      item(PackingCategory.weather, 'warmJacket'),
      item(PackingCategory.weather, 'gloves'),
      item(PackingCategory.weather, 'beanie'),
    ] else
      item(PackingCategory.weather, 'rainJacket'),
    item(PackingCategory.other, 'keys'),
    item(PackingCategory.other, 'waterBottle'),
  ];
}

/// Things a group usually needs only once; offered as one-tap additions
/// to the shared list.
const sharedPackingSuggestions = [
  'speaker',
  'firstAid',
  'powerStrip',
  'cardGame',
  'hairDryer',
  'shampoo',
  'sunscreen',
];

/// When to remind the user to pack: 18:00 the evening before each dated
/// trip they have not fully packed for, if that is still ahead.
List<({GroupModel trip, DateTime at})> packingReminderTimes(
    List<GroupModel> trips, Set<String> packed, DateTime now) {
  final out = <({GroupModel trip, DateTime at})>[];
  for (final t in trips) {
    final start = t.tripStart;
    if (start == null || packed.contains(t.groupId)) continue;
    final at = DateTime(start.year, start.month, start.day - 1, 18);
    if (at.isAfter(now)) out.add((trip: t, at: at));
  }
  return out..sort((a, b) => a.at.compareTo(b.at));
}
