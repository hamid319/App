import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/app/account_gate.dart';
import 'package:swipetrip/common/models/user_model.dart';
import 'package:swipetrip/features/auth/logic/auth_controller.dart';
import 'package:swipetrip/l10n/app_localizations.dart';

class _StaticAuth extends AuthController {
  _StaticAuth(this.user);
  final UserModel? user;

  @override
  Future<UserModel?> build() async => user;
}

Future<void> _pump(
  WidgetTester tester, {
  required bool guest,
  Locale locale = const Locale('en'),
}) async {
  final user = UserModel(uid: 'u', email: '', isAnonymous: guest);
  await tester.pumpWidget(ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => _StaticAuth(user))],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AccountGate(
        reason: GateReason.favorites,
        child: Text('content'),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guests see the sign-up prompt instead of the content',
      (tester) async {
    await _pump(tester, guest: true);
    expect(find.text('Create an account to keep your favorites'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('content'), findsNothing);
  });

  testWidgets('the prompt follows the selected language', (tester) async {
    await _pump(tester, guest: true, locale: const Locale('de'));
    expect(find.text('Erstelle ein Konto, um deine Favoriten zu behalten'),
        findsOneWidget);
    expect(find.text('Konto erstellen'), findsOneWidget);
  });

  testWidgets('real accounts see the content', (tester) async {
    await _pump(tester, guest: false);
    expect(find.text('content'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });
}
