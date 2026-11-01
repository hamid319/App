import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Push notifications from the server (Cloud Functions in functions/push.js)
/// about trip events. This device's token is stored in pushTokens/{token}
/// with the signed-in uid and the app language.
class PushService {
  PushService({FirebaseFirestore? firestore, FirebaseMessaging? messaging})
      : _firestore = firestore,
        _messaging = messaging;

  final FirebaseFirestore? _firestore;
  final FirebaseMessaging? _messaging;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  FirebaseMessaging get _fcm => _messaging ?? FirebaseMessaging.instance;

  StreamSubscription<String>? _refresh;
  String? _token;
  bool _started = false;

  /// Starts listening for taps ([onOpen] gets the route) and for pushes
  /// while the app is open ([onForeground]).
  Future<void> start({
    required void Function(String route) onOpen,
    required void Function(String title, String body, String? route)
        onForeground,
  }) async {
    if (_started) return;
    _started = true;
    String? route(RemoteMessage m) => m.data['route'] as String?;
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (route(m) case final r?) onOpen(r);
    });
    final initial = await _fcm.getInitialMessage();
    if (initial != null && route(initial) != null) onOpen(route(initial)!);
    // iOS shows them itself (below); Android needs a local notification.
    await _fcm.setForegroundNotificationPresentationOptions(
        alert: true, sound: true);
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null || defaultTargetPlatform != TargetPlatform.android) return;
      onForeground(n.title ?? '', n.body ?? '', route(m));
    });
  }

  /// Asks for permission and saves this device's token for [uid].
  Future<void> register(String uid, String lang) async {
    final settings = await _fcm.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    // shortcut: iOS has no APNs token until the Push capability and key are
    // set up (Apple Developer account); until then iOS gets no pushes.
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await _fcm.getAPNSToken() == null) {
      return;
    }
    final token = await _fcm.getToken();
    if (token == null) return;
    _token = token;
    await _save(token, uid, lang);
    await _refresh?.cancel();
    _refresh = _fcm.onTokenRefresh.listen((t) {
      _token = t;
      _save(t, uid, lang);
    });
  }

  Future<void> _save(String token, String uid, String lang) =>
      _db.collection('pushTokens').doc(token).set({
        'uid': uid,
        'lang': lang,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Before sign-out or when turned off: this device gets no more pushes.
  /// Never throws, so sign-out always goes on.
  Future<void> unregister() async {
    await _refresh?.cancel();
    _refresh = null;
    final known = _token;
    _token = null;
    try {
      final token = known ?? await _fcm.getToken();
      if (token == null) return;
      await _db.collection('pushTokens').doc(token).delete();
      await _fcm.deleteToken();
    } catch (e) {
      // No Firebase (tests), no token, offline, or not ours any more.
      debugPrint('Removing push token failed: $e');
    }
  }
}
