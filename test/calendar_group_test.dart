import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:swipetrip/common/models/calendar_trip.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/common/utils/trip_dates.dart';
import 'package:swipetrip/core/constants/popular_cities.dart';
import 'package:swipetrip/core/services/calendar_service.dart';
import 'package:swipetrip/core/services/firestore_service.dart';
import 'package:swipetrip/features/group/data/group_repository.dart';
import 'package:swipetrip/features/group/widgets/calendar_trip_sheet.dart';
import 'package:swipetrip/l10n/l10n.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  group('CalendarTrip.fromEvent', () {
    test('an event ending at midnight does not count that day', () {
      final trip = CalendarTrip.fromEvent(
        title: ' Wochenende Lissabon ',
        start: DateTime(2027, 5, 12),
        end: DateTime(2027, 5, 16),
        location: '  ',
      );
      expect(trip.title, 'Wochenende Lissabon');
      expect(trip.start, DateTime(2027, 5, 12));
      expect(trip.end, DateTime(2027, 5, 15));
      expect(trip.days, 4);
      expect(trip.location, isNull);
    });

    test('an iOS all-day event ending at 23:59 keeps its last day', () {
      final trip = CalendarTrip.fromEvent(
        title: 'Lissabon',
        start: DateTime(2027, 5, 12),
        end: DateTime(2027, 5, 15, 23, 59, 59),
      );
      expect(trip.end, DateTime(2027, 5, 15));
      expect(trip.days, 4);
    });

    test('a timed event keeps its days', () {
      final trip = CalendarTrip.fromEvent(
        title: 'Flug',
        start: DateTime(2027, 5, 12, 9, 30),
        end: DateTime(2027, 5, 12, 12),
      );
      expect(trip.start, trip.end);
      expect(trip.days, 1);
    });
  });

  group('PopularCity.findIn', () {
    test('finds English and German names, location before title', () {
      expect(PopularCity.findIn(['Rua Augusta, Lissabon'])?.id, 'pt_lisbon');
      expect(PopularCity.findIn(['Trip to Munich'])?.id, 'de_munich');
      expect(
        PopularCity.findIn(['Hotel in Wien', 'Berlin Kurztrip'])?.id,
        'at_vienna',
      );
    });

    test('matches whole words only and multi-word names', () {
      expect(PopularCity.findIn(['Romantik-Wochenende']), isNull);
      expect(PopularCity.findIn(['Ausflug nach Rom'])?.id, 'it_rome');
      expect(PopularCity.findIn(['NEW YORK, NY'])?.id, 'us_new_york');
      expect(PopularCity.findIn([null, '']), isNull);
    });
  });

  test('group trip dates round-trip through Firestore data', () {
    final group = GroupModel(
      groupId: 'g1',
      tripStart: DateTime(2027, 5, 12),
      tripEnd: DateTime(2027, 5, 15),
    );
    final json = group.toJson();
    expect(json['tripStart'], isA<Timestamp>());
    final back = GroupModel.fromJson(json);
    expect(back.tripStart, DateTime(2027, 5, 12));
    expect(back.tripEnd, DateTime(2027, 5, 15));

    final without = GroupModel(groupId: 'g2').toJson();
    expect(without.containsKey('tripStart'), isFalse);
  });

  test('createGroup stores the trip dates', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = GroupRepository(_MockFirestoreService(), firestore: firestore);
    await repo.createGroup(GroupModel(
      groupId: 'g1',
      members: const ['u1'],
      ownerUid: 'u1',
      tripStart: DateTime(2027, 5, 12),
      tripEnd: DateTime(2027, 5, 15),
    ));
    final stored =
        (await firestore.collection('groups').doc('g1').get()).data()!;
    final group = GroupModel.fromJson(stored);
    expect(group.tripStart, DateTime(2027, 5, 12));
    expect(group.tripEnd, DateTime(2027, 5, 15));
  });

  test('formatTripDates shows a range or a single day', () {
    expect(
      formatTripDates(DateTime(2027, 5, 12), DateTime(2027, 5, 15), 'de'),
      '12. Mai – 15. Mai',
    );
    expect(formatTripDates(DateTime(2027, 5, 12), null, 'de'), '12. Mai');
  });

  group('calendar sheet', () {
    Future<CalendarTrip?> open(
      WidgetTester tester,
      Future<List<CalendarTrip>> Function() load,
    ) async {
      CalendarTrip? picked;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              picked = await showCalendarTripSheet(context, loadTrips: load),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('lists events and returns the picked one', (tester) async {
      final trip = CalendarTrip.fromEvent(
        title: 'Wochenende Lissabon',
        start: DateTime(2027, 5, 12),
        end: DateTime(2027, 5, 16),
        location: 'Lissabon',
      );
      CalendarTrip? picked;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showCalendarTripSheet(
            context,
            loadTrips: () async => [trip],
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Reise aus deinem Kalender wählen'), findsOneWidget);
      expect(find.text('12. Mai – 15. Mai · Lissabon'), findsOneWidget);

      await tester.tap(find.text('Wochenende Lissabon'));
      await tester.pumpAndSettle();
      expect(picked, same(trip));
    });

    testWidgets('explains a denied permission', (tester) async {
      await open(tester, () async => throw const CalendarPermissionDenied());
      expect(find.textContaining('keinen Zugriff auf deinen Kalender'),
          findsOneWidget);
    });

    testWidgets('says when there are no events', (tester) async {
      await open(tester, () async => const []);
      expect(find.text('Keine kommenden Termine in deinem Kalender.'),
          findsOneWidget);
    });
  });
}
