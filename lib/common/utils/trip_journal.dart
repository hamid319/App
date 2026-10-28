import '../models/group_model.dart';
import '../models/journal_entry.dart';
import '../models/trip_expense.dart';
import 'trip_days.dart';

/// Journal entries of one day. [tripDay] is the 1-based trip day, null
/// when the day lies outside the trip dates (or the trip has none).
typedef JournalDay = ({
  DateTime date,
  int? tripDay,
  List<JournalEntry> entries,
});

/// [entries] (already sorted by day) grouped per calendar day, numbered
/// against the trip's [days].
List<JournalDay> groupJournalByDay(
    List<JournalEntry> entries, List<DateTime> days) {
  final index = {for (final (i, d) in days.indexed) journalDayKey(d): i + 1};
  final result = <JournalDay>[];
  for (final e in entries) {
    if (result.isEmpty || journalDayKey(result.last.date) != e.day) {
      result.add((
        date: DateTime.tryParse(e.day) ?? DateTime(1970),
        tripDay: index[e.day],
        entries: [],
      ));
    }
    result.last.entries.add(e);
  }
  return result;
}

/// The day a new entry defaults to: [today] during the trip, otherwise its
/// first day; [today] for trips without dates.
DateTime defaultJournalDay(List<DateTime> days, DateTime today) {
  final key = journalDayKey(today);
  if (days.isEmpty || days.any((d) => journalDayKey(d) == key)) {
    return DateTime(today.year, today.month, today.day);
  }
  return days.first;
}

/// Numbers of the trip recap.
typedef TripRecapStats = ({
  int days,
  int members,
  int places,
  int photos,
  int totalCents,
  int perPersonCents,
});

/// [places] are the day-plan stops, or the wishlist ideas without a plan.
TripRecapStats tripRecapStats(
  GroupModel group, {
  required List<JournalEntry> entries,
  required List<TripExpense> expenses,
  required int ideaCount,
}) {
  final plan = group.tripPlan;
  final total = expenses.fold(0, (sum, e) => sum + e.amountCents);
  final members = group.members.length;
  final days = tripDays(group.tripStart, group.tripEnd).length;
  return (
    // Without dates: the days that have entries.
    days: days > 0 ? days : {for (final e in entries) e.day}.length,
    members: members,
    places: plan != null && !plan.isEmpty ? plan.stopCount : ideaCount,
    photos: entries.fold(0, (sum, e) => sum + e.photos.length),
    totalCents: total,
    perPersonCents: members == 0 ? 0 : (total / members).round(),
  );
}

/// Up to [max] photos for the recap collage: the newest of every day
/// first (so each day shows up), then the newest of the rest.
List<JournalPhoto> recapPhotos(List<JournalEntry> entries, {int max = 6}) {
  // Entries come oldest first; walk them newest first.
  final newest = entries.reversed.toList();
  final picked = <JournalPhoto>[];
  final days = <String>{};
  for (final e in newest) {
    if (e.photos.isNotEmpty && days.add(e.day)) picked.add(e.photos.last);
  }
  for (final e in newest) {
    for (final p in e.photos.reversed) {
      if (!picked.contains(p)) picked.add(p);
    }
  }
  return picked.take(max).toList();
}
