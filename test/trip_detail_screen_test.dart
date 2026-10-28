import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/app/theme.dart';
import 'package:swipetrip/common/models/group_model.dart';
import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/common/models/trip_idea.dart';
import 'package:swipetrip/common/models/trip_poll.dart';
import 'package:swipetrip/common/models/user_model.dart';
import 'package:swipetrip/features/auth/logic/auth_controller.dart';
import 'package:swipetrip/features/group/logic/group_controller.dart';
import 'package:swipetrip/features/group/logic/trip_controller.dart';
import 'package:swipetrip/features/group/ui/trip_detail_screen.dart';
import 'package:swipetrip/l10n/app_localizations.dart';

class _StaticAuth extends AuthController {
  @override
  Future<UserModel?> build() async =>
      const UserModel(uid: 'me', email: 'me@example.com');
}

final _group = GroupModel(
  groupId: 'g1',
  groupName: 'Weekend trip',
  members: const ['me', 'lea'],
  ownerUid: 'me',
  tripStart: DateTime(2026, 10, 29),
  tripEnd: DateTime(2026, 10, 31),
  joinEnabled: true,
  invite: const GroupInvite(code: 'ABC123'),
);

final _ideas = [
  TripIdea(
    id: 'i1',
    placeId: 'p1',
    title: 'Oceanarium',
    addedBy: 'lea',
    likedBy: const ['lea', 'me'],
    createdAt: DateTime(2026, 10, 1),
  ),
  TripIdea(
    id: 'i2',
    title: 'Sunset boat tour',
    addedBy: 'me',
    likedBy: const ['me'],
    createdAt: DateTime(2026, 10, 2),
  ),
];

const _poll = TripPoll(
  id: 'poll',
  question: 'Where do we stay?',
  options: [
    PollOption(id: 'o0', label: 'Apartment'),
    PollOption(id: 'o1', label: 'Hostel'),
  ],
  votes: {'lea': 'o0'},
  createdBy: 'lea',
);

Future<void> _pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_StaticAuth.new),
      userGroupsProvider.overrideWith((ref) => Stream.value([_group])),
      tripIdeasProvider.overrideWith((ref, id) => Stream.value(_ideas)),
      tripPollsProvider.overrideWith((ref, id) => Stream.value([_poll])),
      tripPlacesProvider.overrideWith((ref, key) async => const [
            PlaceModel(id: 'p1', name: 'Oceanarium', lat: 38.76, lng: -9.09),
          ]),
      groupMemberNameProvider.overrideWith(
          (ref, uid) async => uid == 'lea' ? 'lea@example.com' : 'Hamid'),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TripDetailScreen(groupId: 'g1'),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'GOOGLE_PLACES_API_KEY='));

  testWidgets('shows plan, poll, wishlist and the plan button', (tester) async {
    await _pump(tester);

    expect(find.text('Weekend trip'), findsOneWidget);
    // Member names are resolved, never emails.
    expect(find.textContaining('Hamid, lea'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);

    for (final tab in ['Plan', 'Map', 'Journal', 'Costs']) {
      expect(find.text(tab), findsOneWidget);
    }
    // The journal is live now, no "soon" badge.
    expect(find.text('soon'), findsNothing);

    expect(find.text('Where do we stay?'), findsOneWidget);
    expect(find.text('1 of 2 voted'), findsOneWidget);
    expect(find.text('Apartment'), findsOneWidget);

    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('+ Idea'), findsOneWidget);
    expect(find.text('Oceanarium'), findsOneWidget);
    expect(find.text('Sunset boat tour'), findsOneWidget);
    expect(find.text('by lea'), findsOneWidget);

    // Only the idea with a place can go into the plan.
    expect(find.text('Build day plan from 1 idea'), findsOneWidget);
    expect(find.text('Collect ideas by swiping'), findsOneWidget);
  });

  testWidgets('German texts', (tester) async {
    await _pump(tester, locale: const Locale('de'));
    expect(find.text('Wunschliste'), findsOneWidget);
    expect(find.text('Tagebuch'), findsOneWidget);
    expect(find.text('Tagesplan aus 1 Idee erstellen'), findsOneWidget);
    expect(find.text('1 von 2 haben abgestimmt'), findsOneWidget);
  });
}
