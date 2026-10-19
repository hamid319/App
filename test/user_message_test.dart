import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipetrip/core/errors/user_message.dart';
import 'package:swipetrip/l10n/app_localizations_de.dart';
import 'package:swipetrip/l10n/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();
  final de = AppLocalizationsDe();
  final fallback = en.errorLoadResults;

  test('known app-thrown exceptions are translated', () {
    expect(
      userMessage(Exception('Invalid invite code'),
          fallback: fallback, l10n: en),
      en.errorInvalidInviteCode,
    );
    expect(
      userMessage(Exception('Invalid invite code'),
          fallback: de.errorLoadResults, l10n: de),
      'Ungültiger Einladungscode.',
    );
  });

  test('known state errors are translated', () {
    expect(
      userMessage(StateError('No places found for this destination'),
          fallback: fallback, l10n: en),
      en.errorNoPlacesForDestination,
    );
  });

  test('unknown app exceptions use the fallback instead of raw text', () {
    expect(
      userMessage(Exception('Nearby Search returned malformed JSON'),
          fallback: fallback, l10n: en),
      fallback,
    );
  });

  test('Firebase permission errors never leak paths', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing permissions on /groups/abc/sessions/xyz',
    );
    final message = userMessage(error, fallback: fallback, l10n: en);
    expect(message, en.errorPermissionDenied);
    expect(message, isNot(contains('/groups')));
  });

  test('unknown Firebase codes and other errors use the fallback', () {
    expect(
      userMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'internal'),
        fallback: fallback,
        l10n: en,
      ),
      fallback,
    );
    expect(
        userMessage(const FormatException('bad'), fallback: fallback, l10n: en),
        fallback);
    expect(userMessage(TypeError(), fallback: fallback, l10n: en), fallback);
  });
}
