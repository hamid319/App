import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:swipetrip/app/routes.dart';
import 'package:swipetrip/core/services/auth_service.dart';
import 'package:swipetrip/features/auth/logic/password_reset_controller.dart';
import 'package:swipetrip/features/auth/ui/forgot_password_screen.dart';
import 'package:swipetrip/l10n/l10n.dart';
import 'package:swipetrip/main_providers.dart';

class _ResetAuthService extends AuthService {
  _ResetAuthService({this.error});

  final FirebaseAuthException? error;
  final calls = <(String, String?)>[];

  @override
  Future<void> sendPasswordResetEmail(String email,
      {String? languageCode}) async {
    calls.add((email, languageCode));
    if (error != null) throw error!;
  }
}

Widget _app(_ResetAuthService auth, {String? email}) {
  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const Text('login page')),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => ForgotPasswordScreen(initialEmail: email),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authServiceProvider.overrideWithValue(auth)],
    child: MaterialApp.router(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  group('PasswordResetController', () {
    test('sends the link in the app language and remembers the address',
        () async {
      final auth = _ResetAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(passwordResetControllerProvider, (_, __) {});
      addTearDown(sub.close);

      await container
          .read(passwordResetControllerProvider.notifier)
          .send('  ana@example.com ', languageCode: 'de');

      expect(auth.calls, [('ana@example.com', 'de')]);
      expect(container.read(passwordResetControllerProvider).value,
          'ana@example.com');
    });

    test('answers the same for unknown addresses', () async {
      final auth = _ResetAuthService(
        error: FirebaseAuthException(code: 'user-not-found'),
      );
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(passwordResetControllerProvider, (_, __) {});
      addTearDown(sub.close);

      await container
          .read(passwordResetControllerProvider.notifier)
          .send('nobody@example.com');
      expect(container.read(passwordResetControllerProvider).value,
          'nobody@example.com');
    });

    test('reports real failures', () async {
      final auth = _ResetAuthService(
        error: FirebaseAuthException(code: 'too-many-requests'),
      );
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(passwordResetControllerProvider, (_, __) {});
      addTearDown(sub.close);

      await container
          .read(passwordResetControllerProvider.notifier)
          .send('ana@example.com');
      expect(container.read(passwordResetControllerProvider).hasError, isTrue);
    });
  });

  test('forgot password is reachable without an account', () {
    expect(
      resolveAuthRedirect(
        path: '/forgot-password',
        hasSeenOnboarding: true,
        hasSession: false,
        hasAccount: false,
      ),
      isNull,
    );
  });

  group('ForgotPasswordScreen', () {
    testWidgets('prefills the email, sends and shows the confirmation',
        (tester) async {
      final auth = _ResetAuthService();
      await tester.pumpWidget(_app(auth, email: 'ana@example.com'));
      await tester.pumpAndSettle();

      expect(find.text('ana@example.com'), findsOneWidget);
      await tester.tap(find.text('Link senden'));
      await tester.pumpAndSettle();

      expect(auth.calls.single, ('ana@example.com', 'de'));
      expect(find.text('Schau in dein Postfach'), findsOneWidget);
      expect(find.textContaining('ana@example.com'), findsOneWidget);
      // Resend is locked for a moment.
      expect(find.text('Erneut senden in 30 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.text('Erneut senden'));
      await tester.pumpAndSettle();
      expect(auth.calls, hasLength(2));
      expect(find.text('Schau in dein Postfach'), findsOneWidget);

      await tester.tap(find.text('Andere E-Mail-Adresse verwenden'));
      await tester.pumpAndSettle();
      expect(find.text('Link senden'), findsOneWidget);
    });

    testWidgets('validates the address before sending', (tester) async {
      final auth = _ResetAuthService();
      await tester.pumpWidget(_app(auth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link senden'));
      await tester.pump();
      expect(auth.calls, isEmpty);
      expect(find.text('Link senden'), findsOneWidget);
    });

    testWidgets('shows a translated error', (tester) async {
      final auth = _ResetAuthService(
        error: FirebaseAuthException(code: 'network-request-failed'),
      );
      await tester.pumpWidget(_app(auth, email: 'ana@example.com'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Link senden'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Netzwerkfehler'), findsOneWidget);
    });
  });
}
