import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

/// Turns any error into translated text that is safe to show to users.
///
/// Raw `toString()` output leaked Firestore paths and permission internals.
/// Firebase errors map to a short explanation; messages the app throws on
/// purpose (`Exception('Invalid invite code')`) map to their translation;
/// everything else falls back to [fallback]. The original error is still
/// logged in debug.
String userMessage(
  Object error, {
  required String fallback,
  required AppLocalizations l10n,
}) {
  debugPrint('$fallback: $error');

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return l10n.errorPermissionDenied;
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return l10n.errorNoConnection;
      case 'not-found':
        return l10n.errorNotFound;
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return l10n.errorEmailInUse;
      case 'invalid-email':
        return l10n.emailInvalid;
      case 'weak-password':
        return l10n.errorWeakPassword;
      case 'too-many-requests':
        return l10n.authTooManyRequests;
      default:
        return fallback;
    }
  }

  final String message;
  if (error is StateError) {
    message = error.message;
  } else {
    const prefix = 'Exception: ';
    final text = error.toString();
    if (error is! Exception || !text.startsWith(prefix)) return fallback;
    message = text.substring(prefix.length);
  }
  return _knownAppMessage(message, l10n) ?? fallback;
}

/// Messages thrown by repositories and controllers, which have no
/// BuildContext and so stay English in code. Anything not listed here is
/// treated as technical and replaced by the caller's fallback.
String? _knownAppMessage(String message, AppLocalizations l10n) {
  if (message.startsWith('No places found')) {
    return l10n.errorNoPlacesForDestination;
  }
  switch (message) {
    case 'Group not found':
      return l10n.errorGroupNotFound;
    case 'Invalid invite code':
      return l10n.errorInvalidInviteCode;
    case 'Joining is currently disabled for this group':
      return l10n.errorJoiningDisabled;
    case 'Only the admin can start the session':
      return l10n.errorAdminOnlyStart;
    case 'Only the admin can end the session':
      return l10n.errorAdminOnlyEnd;
    case 'Only the admin can reorder the session list':
      return l10n.errorAdminOnlyReorder;
    case 'Group location is required to start a session':
      return l10n.errorGroupLocationRequired;
    case 'Session not found':
      return l10n.errorSessionNotFound;
    case 'Not authenticated':
    case 'User not authenticated':
      return l10n.errorNotLoggedIn;
    default:
      return null;
  }
}
