import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/app/theme.dart';
import 'package:swipetrip/common/models/photo_credit.dart';
import 'package:swipetrip/common/models/place_model.dart';
import 'package:swipetrip/common/models/place_prompt.dart';
import 'package:swipetrip/features/places/widgets/photo_credits.dart';
import 'package:swipetrip/features/places/widgets/prompt_tile.dart';
import 'package:swipetrip/l10n/l10n.dart';

Map<String, dynamic> _place(Map<String, dynamic> extra) => {
      'id': 'p1',
      'name': 'Seealpsee',
      'lat': 47.27,
      'lng': 9.39,
      ...extra,
    };

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('PlacePrompt', () {
    test('reads localized answers and falls back to English', () {
      final place = PlaceModel.fromJson(_place({
        'prompts': [
          {
            'kind': 'bestTime',
            'text': {'en': 'Early morning', 'de': 'Früh morgens'},
          },
          {'kind': 'insiderTip', 'text': 'Try the rösti'},
        ],
      }));
      expect(place.prompts, hasLength(2));
      expect(place.prompts[0].kind, PlacePromptKind.bestTime);
      expect(place.prompts[0].textFor('de'), 'Früh morgens');
      expect(place.prompts[0].textFor('fr'), 'Early morning');
      expect(place.prompts[1].textFor('de'), 'Try the rösti');
    });

    test('skips unknown kinds and empty answers', () {
      final place = PlaceModel.fromJson(_place({
        'prompts': [
          {'kind': 'somethingNew', 'text': 'x'},
          {'kind': 'funFact', 'text': {'en': '  '}},
          'not a map',
        ],
      }));
      expect(place.prompts, isEmpty);
    });

    test('places without prompts parse as before', () {
      expect(PlaceModel.fromJson(_place({})).prompts, isEmpty);
    });
  });

  group('PhotoCredit', () {
    test('reads Wikidata pipeline photos and uses their URLs', () {
      final place = PlaceModel.fromJson(_place({
        'photos': [
          {
            'publicUrl': 'https://img.example/p1/0.webp',
            'creator': 'Jane Doe',
            'licenseName': 'CC BY-SA 4.0',
            'licenseUrl': 'https://creativecommons.org/licenses/by-sa/4.0',
            'commonsFilePageUrl': 'https://commons.wikimedia.org/wiki/File:X.jpg',
          },
        ],
      }));
      expect(place.imageUrls, ['https://img.example/p1/0.webp']);
      final credit = place.photoCredits.single;
      expect(credit.source, PhotoSource.wikimedia);
      expect(credit.author, 'Jane Doe');
      expect(credit.licenseName, 'CC BY-SA 4.0');
      expect(credit.sourceUrl, contains('commons.wikimedia.org'));
    });

    test('reads Google photo attributions and keeps imageUrls', () {
      final place = PlaceModel.fromJson(_place({
        'imageUrls': ['https://storage.example/p1.jpg'],
        'photoAttributions': [
          {'displayName': 'Max M.', 'uri': 'https://maps.google.com/u/1'},
        ],
      }));
      expect(place.imageUrls, ['https://storage.example/p1.jpg']);
      final credit = place.photoCredits.single;
      expect(credit.source, PhotoSource.google);
      expect(credit.author, 'Max M.');
      expect(credit.authorUrl, 'https://maps.google.com/u/1');
    });
  });

  group('widgets', () {
    testWidgets('prompt tile shows the translated label and answer',
        (tester) async {
      const prompt = PlacePrompt(
        kind: PlacePromptKind.bestTime,
        text: {'en': 'Just before sunset', 'de': 'Kurz vor Sonnenuntergang'},
      );
      await tester.pumpWidget(
        _app(const PromptTile(prompt: prompt), locale: const Locale('de')),
      );
      expect(find.text('AM BESTEN'), findsOneWidget);
      expect(find.text('Kurz vor Sonnenuntergang'), findsOneWidget);
    });

    testWidgets('credit chip names the author and opens all credits',
        (tester) async {
      const credits = [
        PhotoCredit(
          source: PhotoSource.wikimedia,
          author: 'Jane Doe',
          licenseName: 'CC BY-SA 4.0',
          licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0',
        ),
        PhotoCredit(source: PhotoSource.google),
      ];
      await tester.pumpWidget(_app(const PhotoCreditChip(credits: credits)));
      expect(find.text('Photo: Jane Doe · CC BY-SA 4.0'), findsOneWidget);

      await tester.tap(find.byType(PhotoCreditChip));
      await tester.pumpAndSettle();
      expect(find.text('Photo credits'), findsOneWidget);
      expect(find.text('Unknown author'), findsOneWidget);
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Wikimedia Commons'), findsOneWidget);
    });
  });
}
