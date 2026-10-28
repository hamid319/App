import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/app/theme.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/common/models/journal_entry.dart';
import 'package:swipetrip/common/models/user_model.dart';
import 'package:swipetrip/features/auth/logic/auth_controller.dart';
import 'package:swipetrip/features/group/logic/group_controller.dart';
import 'package:swipetrip/features/group/logic/trip_controller.dart';
import 'package:swipetrip/features/group/ui/journal_screen.dart';
import 'package:swipetrip/l10n/app_localizations.dart';

class _StaticAuth extends AuthController {
  @override
  Future<UserModel?> build() async =>
      const UserModel(uid: 'me', email: 'me@example.com');
}

final _group = GroupModel(
  groupId: 'g1',
  groupName: 'Lisbon',
  members: const ['me', 'lea'],
  ownerUid: 'me',
  // Ended, so the recap button shows even without entries.
  tripStart: DateTime(2025, 10, 29),
  tripEnd: DateTime(2025, 10, 31),
);

Future<void> _pump(WidgetTester tester, List<JournalEntry> entries) async {
  await tester.binding.setSurfaceSize(const Size(390, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_StaticAuth.new),
      userGroupsProvider.overrideWith((ref) => Stream.value([_group])),
      tripJournalProvider.overrideWith((ref, id) => Stream.value(entries)),
      groupMemberNameProvider.overrideWith((ref, uid) async => 'Lea'),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const JournalScreen(groupId: 'g1'),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty journal invites the first memory', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No memories yet'), findsOneWidget);
    expect(find.text('Add entry'), findsOneWidget);
    expect(find.text('View recap'), findsOneWidget);
  });

  testWidgets('entries are grouped under their trip day', (tester) async {
    await _pump(tester, const [
      JournalEntry(
          id: 'a', authorUid: 'lea', day: '2025-10-30', text: 'Tram 28'),
      JournalEntry(
          id: 'b', authorUid: 'me', day: '2025-10-30', text: 'Pastéis'),
    ]);
    expect(find.text('DAY 2 · THURSDAY, OCTOBER 30'), findsOneWidget);
    expect(find.text('Tram 28'), findsOneWidget);
    expect(find.text('Lea'), findsOneWidget);
    // Only my own entry has the edit/delete menu.
    expect(find.byTooltip('Entry options'), findsOneWidget);
  });
}
