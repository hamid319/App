import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/app/theme.dart';
import 'package:swipetrip/features/group/widgets/trip_created_celebration.dart';
import 'package:swipetrip/l10n/app_localizations.dart';

void main() {
  testWidgets('plays the packing animation and closes on the button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showTripCreatedCelebration(context,
              cityName: 'Berlin', stickerSeed: 42),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Die Reise steht!'), findsOneWidget);
    expect(find.textContaining('Berlin'), findsOneWidget);

    await tester.tap(find.text('Zur Reise'));
    await tester.pumpAndSettle();
    expect(find.text('Die Reise steht!'), findsNothing);
  });
}
