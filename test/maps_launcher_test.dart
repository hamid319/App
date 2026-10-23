import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/app/theme.dart';
import 'package:swipetrip/core/services/maps_launcher.dart';
import 'package:swipetrip/features/places/widgets/maps_app_sheet.dart';
import 'package:swipetrip/l10n/l10n.dart';

void main() {
  group('MapsLauncher URLs', () {
    test('Apple Maps routes to the coordinates and labels the place', () {
      final uri = MapsLauncher.appleMapsUri(48.8584, 2.2945, 'Eiffel Tower');
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['daddr'], '48.8584,2.2945');
      expect(uri.queryParameters['q'], 'Eiffel Tower');
    });

    test('Google Maps app and web both route to the coordinates', () {
      final app = MapsLauncher.googleMapsAppUri(48.8584, 2.2945);
      expect(app.scheme, 'comgooglemaps');
      expect(app.queryParameters['daddr'], '48.8584,2.2945');

      final web = MapsLauncher.googleMapsWebUri(48.8584, 2.2945);
      expect(web.host, 'www.google.com');
      expect(web.path, '/maps/dir/');
      expect(web.queryParameters['api'], '1');
      expect(web.queryParameters['destination'], '48.8584,2.2945');
    });
  });

  testWidgets('maps sheet offers Apple Maps and Google Maps', (tester) async {
    MapsApp? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => picked = await showMapsAppSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Route öffnen mit'), findsOneWidget);
    expect(find.text('Apple Karten'), findsOneWidget);

    await tester.tap(find.text('Google Maps'));
    await tester.pumpAndSettle();
    expect(picked, MapsApp.google);
  });
}
