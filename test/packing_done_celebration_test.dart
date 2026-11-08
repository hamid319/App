import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/app/theme.dart';
import 'package:swipetrip/features/group/widgets/packing_done_celebration.dart';
import 'package:swipetrip/l10n/app_localizations.dart';

void main() {
  testWidgets('packing done: plays, shows the miles and closes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showPackingDoneCelebration(context, cityName: 'Hamburg'),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    for (var i = 0; i < 22; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Fertig gepackt!'), findsOneWidget);
    expect(find.textContaining('Hamburg'), findsOneWidget);
    expect(find.textContaining('Meilen'), findsOneWidget);

    await tester.tap(find.text('Super'));
    await tester.pumpAndSettle();
    expect(find.text('Fertig gepackt!'), findsNothing);
  });
}
